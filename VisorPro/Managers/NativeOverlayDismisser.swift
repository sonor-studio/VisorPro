import Cocoa
import ApplicationServices
import IOBluetooth
import SwiftUI

/// Continually monitors and instantly hides native macOS system overlays (Focus pills, Bluetooth connection toasts)
final class NativeOverlayDismisser {
    
    static let shared = NativeOverlayDismisser()
    
    var enabled: Bool {
        return true
    }
    
    var dismissFocusPill: Bool {
        UserDefaults.standard.object(forKey: "dismissNativeFocusOverlay") as? Bool ?? true
    }
    
    var dismissBluetoothPill: Bool {
        UserDefaults.standard.object(forKey: "dismissNativeBluetoothOverlay") as? Bool ?? true
    }
    
    private let targetProcessNames: Set<String> = [
        "Control Center",     // BT connection & Focus
        "ControlCenter",
        "OSDUIHelper"         // Modern macOS Volume/Brightness HUDs
    ]
    
    private var axObservers: [pid_t: AXObserver] = [:]
    private var lastSmartRoutingBanner: AXUIElement?
    
    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }
    
    /// Starts the event-driven observer (zero CPU usage while idle)
    func start() {
        setupInstantObservers()
    }
    
    private var lastFocusEventTime: Date = Date.distantPast
    
    func onSystemEvent(type: EventType) {
        if type == .focus {
            lastFocusEventTime = Date()
        }
    }
    enum EventType { case bluetooth, focus }
    
    // MARK: - Instant AXObserver Logic
    
    private func setupInstantObservers() {
        let workspace = NSWorkspace.shared
        for app in workspace.runningApplications {
            if let name = app.localizedName, targetProcessNames.contains(name) {
                addObserver(for: app.processIdentifier)
            }
        }
    }
    
    @objc private func appLaunched(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let name = app.localizedName, targetProcessNames.contains(name) {
            addObserver(for: app.processIdentifier)
        }
    }
    
    private let axObserverCallback: AXObserverCallback = { (observer, element, notification, refcon) in
        guard let refcon = refcon else { return }
        let dismisser = Unmanaged<NativeOverlayDismisser>.fromOpaque(refcon).takeUnretainedValue()
        dismisser.handleWindowCreated(element)
    }
    
    private func addObserver(for pid: pid_t) {
        guard checkAXIsProcessTrustedReliably() else { return }
        guard axObservers[pid] == nil else { return }
        
        var observer: AXObserver?
        let result = AXObserverCreate(pid, axObserverCallback, &observer)
        if result == .success, let obs = observer {
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            let appElement = AXUIElementCreateApplication(pid)
            
            // Listen for window creation
            AXObserverAddNotification(obs, appElement, kAXWindowCreatedNotification as CFString, refcon)
            CFRunLoopAddSource(RunLoop.main.getCFRunLoop(), AXObserverGetRunLoopSource(obs), .defaultMode)
            axObservers[pid] = obs
        }
    }
    
    func handleWindowCreated(_ element: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        let bundleID = app?.bundleIdentifier?.lowercased() ?? ""
        let appName = app?.localizedName?.lowercased() ?? ""
        
        // Never touch MenuBarAgent or any Menu Bar windows
        if bundleID.contains("menubar") || appName.contains("menubar") {
            return
        }
        
        let identifier = getStringAttribute(element, kAXIdentifierAttribute as String)?.lowercased() ?? ""
        if identifier.contains("menubar") || identifier == "menubarrevealshield" {
            return
        }
        
        var isShapeMatch = false
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success {
            var size = CGSize.zero
            if AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
                if size.width >= 150 && size.height <= 250 {
                    isShapeMatch = true
                }
            }
        }
        
        // --- DATA EXTRACTION ---
        var allText = ""
        var textNodes: [String] = []
        var nestedIdentifiers: [String] = []
        var hasBatteryIndicator = false
        
        func traverseElementTree(_ el: AXUIElement) {
            var val: CFTypeRef?
            
            let collectText = { (val: CFTypeRef?) in
                guard let s = val as? String, !s.isEmpty else { return }
                allText += s + " | "
                textNodes.append(s.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            if AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &val) == .success { collectText(val) }
            if AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &val) == .success { collectText(val) }
            if AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &val) == .success { collectText(val) }
            
            if AXUIElementCopyAttributeValue(el, kAXIdentifierAttribute as CFString, &val) == .success, let s = val as? String { 
                let lowerId = s.lowercased()
                if !lowerId.isEmpty && !nestedIdentifiers.contains(lowerId) { nestedIdentifiers.append(lowerId) }
            }
            
            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &val) == .success, let role = val as? String {
                if role == kAXValueIndicatorRole || role == kAXLevelIndicatorRole {
                    hasBatteryIndicator = true
                }
            }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef) == .success, let children = childrenRef as? [AXUIElement] {
                for child in children { traverseElementTree(child) }
            }
        }
        traverseElementTree(element)
        
        // As the user pointed out, AirPods banners structurally separate the battery percentage
        // from the name. We look for a standalone number (or number with %) among the distinct UI elements.
        var detectedBatteryLevel: Int? = nil
        for node in textNodes {
            let cleanNode = node.replacingOccurrences(of: "%", with: "")
            if let num = Int(cleanNode), num >= 0 && num <= 100 {
                hasBatteryIndicator = true
                detectedBatteryLevel = num
                break
            }
        }
        
        let logLine = "[\(Date())] Banner: id='\(identifier)', text='\(allText)', nestedIds=\(nestedIdentifiers), battery=\(hasBatteryIndicator)\n"
        let logURL = URL(fileURLWithPath: "/Users/macbook/Desktop/Dev/VisorPro/ax_banners.log")
        DispatchQueue.global(qos: .utility).async {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                if let data = logLine.data(using: .utf8) { handle.write(data) }
                try? handle.close()
            } else {
                try? logLine.write(to: logURL, atomically: true, encoding: .utf8)
            }
        }
        let isControlCenter = bundleID.contains("controlcenter") || appName.contains("control center")
        let isOSDUIHelper = bundleID.contains("osduihelper") || appName.contains("osduihelper")
        // ---------------------
        
        var shouldIntercept = false
        
        let timeSinceFocusEvent = Date().timeIntervalSince(lastFocusEventTime)
        let isRecentFocusEvent = timeSinceFocusEvent < 2.0
        
        let lowerAllText = allText.lowercased()
        
        let hasBannerPID = allText.contains("Banner PID")
        let isStructurallyBluetooth = hasBatteryIndicator || hasBannerPID || nestedIdentifiers.contains("smart-routing-system-banner") || nestedIdentifiers.contains(where: { $0.contains("accessory") })
        let isStructurallyFocus = nestedIdentifiers.contains("focus-system-banner") || identifier == "focus-system-banner" || identifier == "focus" || identifier == "donotdisturb" || nestedIdentifiers.contains(where: { $0.contains("focusmode") })
        
        // If it comes from Control Center and lacks structural Bluetooth identifiers, it's very likely a Focus banner
        let isAmbiguousControlCenterBanner = isShapeMatch && identifier == "" && isControlCenter
        let isShapeMatchEmptyFocus = isAmbiguousControlCenterBanner && !isStructurallyBluetooth
        let isShapeMatchEmptyBluetooth = isAmbiguousControlCenterBanner && isStructurallyBluetooth
        
        let isFocus = isStructurallyFocus || isShapeMatchEmptyFocus
        
        let isVolume = identifier == "volume-system-banner" || identifier == "volume" || (isShapeMatch && identifier == "" && isOSDUIHelper)
        
        var preventIntercept = false
        
        func hasUndoButton(element: AXUIElement) -> Bool {
            var foundUndo = false
            func traverse(el: AXUIElement) {
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef) == .success, let role = roleRef as? String {
                    if role == kAXButtonRole {
                        var subroleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(el, kAXSubroleAttribute as CFString, &subroleRef)
                        let subrole = (subroleRef as? String) ?? ""
                        if subrole != kAXCloseButtonSubrole as String {
                            foundUndo = true
                            return
                        }
                    }
                }
                var childrenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef) == .success, let children = childrenRef as? [AXUIElement] {
                    for child in children {
                        traverse(el: child)
                        if foundUndo { return }
                    }
                }
            }
            traverse(el: element)
            return foundUndo
        }
        
        var seen = Set<String>()
        let texts = allText.components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.lowercased().contains("banner pid") && !$0.lowercased().contains("window") && seen.insert($0).inserted }
        
        let isListeningMode = identifier == "listening-mode-system-banner" ||
            identifier.contains("listening-mode") ||
            nestedIdentifiers.contains("listening-mode-system-banner") ||
            nestedIdentifiers.contains(where: { $0.contains("listening-mode") })
        
        let isSmartRouting = nestedIdentifiers.contains("smart-routing-system-banner") || identifier == "smart-routing-system-banner"
        let isBluetooth = !isListeningMode && (isSmartRouting || nestedIdentifiers.contains(where: { $0.contains("accessory") }) || identifier.contains("accessory-system-banner") || isShapeMatchEmptyBluetooth)
        
        if isSmartRouting || isBluetooth {
            let isStructurallySmartRouting = hasUndoButton(element: element)
            
            if isStructurallySmartRouting {
                let deviceName = texts.first ?? "AirPods"
                var settings = MediaKeyManager.shared.accessorySettings[deviceName]
                if settings == nil {
                    settings = MediaKeyManager.shared.accessorySettings.first(where: { $0.key.lowercased().contains("airpods") })?.value
                }
                
                let notifySmartRouting = settings?.notifyOnSmartRouting ?? true
                let enableOverlay = settings?.enableOverlay ?? true
                
                if notifySmartRouting && enableOverlay {
                    // It's a transfer banner! Show it instantly!
                    self.lastSmartRoutingBanner = element
                    OverlayStateRelay.shared.isSmartRoutingUndoAvailable = true
                    self.startSmartRoutingBannerTracker(for: element)
                    MediaKeyManager.shared.triggerSmartRouting(texts: texts)
                } else {
                    preventIntercept = true
                }
            } else if !isListeningMode {
                // Connection or accessory status banner
                MediaKeyManager.shared.lastSmartRoutingActionTime = Date() // Suppress volume overlay since audio is coming back to Mac
                let deviceName = texts.first(where: { !$0.isEmpty && Int($0.replacingOccurrences(of: "%", with: "")) == nil && !$0.lowercased().contains("connected") }) ?? "AirPods"
                
                let isAppleHeadphone = deviceName.lowercased().contains("airpods") || deviceName.lowercased().contains("beats") || deviceName.lowercased().contains("pro") || deviceName.lowercased().contains("max")
                let timeSinceConnectionLog = Date().timeIntervalSince(AirPodsBatteryManager.shared.lastConnectionLogTime)
                let isCriticallyLowBattery = (detectedBatteryLevel ?? 100) <= 20
                
                // Only trigger Bluetooth Connection overlay if there was an ACTUAL recent connection event!
                // Apple logs `SmartRouting posting device` or `Setting inEarStateUnified -> InEar` when connecting.
                // If timeSinceConnectionLog > 4.0, it is NOT a connection event (it could be a mode change or status alert).
                if isAppleHeadphone {
                    if isCriticallyLowBattery && timeSinceConnectionLog > 20.0 {
                        // Low battery alert: swallow without showing connection overlay
                    } else if timeSinceConnectionLog <= 4.0 {
                        MediaKeyManager.shared.triggerBluetoothIndicator(deviceName: deviceName, deviceAddress: "AIRPODS_CONNECTION", isConnected: true)
                    }
                } else if !isAmbiguousControlCenterBanner {
                    MediaKeyManager.shared.triggerBluetoothIndicator(deviceName: deviceName, deviceAddress: "BLUETOOTH_CONNECTION", isConnected: true)
                }
            }
        }
        
        if isListeningMode {
            // macOS natively popped up a Listening Mode banner. We intercept and dismiss it.
            // Fetch the exact mode from CoreAudio lstm (language-independent integer: 1=Off, 2=ANC, 3=Transparency, 4=Adaptive).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let mode = MediaKeyManager.shared.airPodsModeObserver?.getCurrentMode() ?? OverlayStateRelay.shared.airPodsModeValue
                if mode > 0 {
                    MediaKeyManager.shared.triggerAirPodsModeOverlay(mode: mode, showOverlay: true)
                }
            }
            shouldIntercept = true
        }
        
        guard enabled else { return }
        
        if isFocus && MediaKeyManager.shared.enableFocus {
            shouldIntercept = true
            MediaKeyManager.shared.handleNativeFocusBanner(allText: allText, nestedIds: nestedIdentifiers)
        }

        if isBluetooth && MediaKeyManager.shared.enableBluetooth {
            shouldIntercept = true
        }

        if isVolume && MediaKeyManager.shared.enableVolume {
            shouldIntercept = true
            let timeSinceRoute = Date().timeIntervalSince(VolumeManager.shared.lastRouteChangeTime)
            
            let timeSinceDisplayConnection = MediaKeyManager.shared.lastDisplayConnectionTime != nil ? Date().timeIntervalSince(MediaKeyManager.shared.lastDisplayConnectionTime!) : 999.0
            
            if !OverlayStateRelay.shared.isDisplayTransitioning && timeSinceRoute > 3.0 && timeSinceDisplayConnection > 4.0 {
                DispatchQueue.main.async {
                    MediaKeyManager.shared.triggerVolumeIndicator(playSound: false)
                }
            }
        }
        
        if preventIntercept {
            shouldIntercept = false
        }
        
        if shouldIntercept {
            print("NativeOverlayDismisser: ⚠️ INTERCEPTING BANNER. Trying hover-and-click method...")
            
            // Do NOT move off-screen immediately! If we move it to -5000,-5000, the frame.midX becomes -5000,
            // which causes the mouse click to hit the top-left of the screen (Safari URL bar).
            
            var frameRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &frameRef) == .success {
                var frame = CGRect.zero
                if AXValueGetValue(frameRef as! AXValue, .cgRect, &frame) {
                    let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
                    print("NativeOverlayDismisser: Banner frame is \(frame). Center is \(centerPoint).")
                    
                    if frame.width < 50 || frame.height < 50 {
                        print("NativeOverlayDismisser: Ignoring small dummy window.")
                    } else {
                        // macOS Sequoia Architecture Limitation:
                        // 1. AXPosition cannot move it (SwiftUI forces it back at 60Hz).
                        // 2. AXCloseButton does not exist in the Accessibility Tree (it's purely a visual CoreAnimation layer).
                        // 3. postToPid(ESC) and app.hide() are ignored by ControlCenter LSUIElements.
                        // 4. Gestures (ScrollWheel/Swipe) are not supported by this specific banner type.
                        // 5. Physical cursor warp to hover & click causes unacceptable visual glitches.
                        // 
                        // Conclusion: There is no programmatic way to silently dismiss this banner.
                        // The user MUST disable "Allow Notifications" for Focus mode in macOS System Settings.
                        print("NativeOverlayDismisser: Cannot programmatically dismiss Sequoia Focus banner. Please disable in System Settings.")
                    }
                }
            } else {
                print("NativeOverlayDismisser: Failed to get AXFrame for banner!")
            }
            
            // Move off-screen in the background ONLY after a small delay so we don't break the hover click
            DispatchQueue.global(qos: .userInteractive).async {
                Thread.sleep(forTimeInterval: 0.3)
                print("NativeOverlayDismisser: Starting off-screen loop fallback...")
                let endTime = Date().addingTimeInterval(2.5)
                while Date() < endTime {
                    var roleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) != .success {
                        print("NativeOverlayDismisser: Banner died.")
                        break
                    }
                    var pt = CGPoint(x: -5000, y: -5000)
                    if let pv = AXValueCreate(.cgPoint, &pt) {
                        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, pv)
                    }
                    Thread.sleep(forTimeInterval: 0.02)
                }
            }
        } else {
        }
    }
    
    func clickUndoSmartRouting(targetName: String = "") {
        MediaKeyManager.shared.lastSmartRoutingActionTime = Date()
        
        var found = false
        if let banner = lastSmartRoutingBanner {
            var logOutput = ""
            func findAndClickButton(element: AXUIElement, depth: Int = 0) -> Bool {
                let indent = String(repeating: "  ", count: depth)
                
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success, let role = roleRef as? String {
                    logOutput += "\(indent)Found role: \(role)\n"
                    if role == kAXButtonRole {
                        var subroleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
                        let subrole = (subroleRef as? String) ?? "nil"
                        logOutput += "\(indent)Button subrole: '\(subrole)'\n"
                        
                        // The close button usually has subrole "AXCloseButton".
                        if subrole != kAXCloseButtonSubrole as String {
                            logOutput += "\(indent)Clicking Undo Button (not a close button)!\n"
                            
                            // Let's also briefly move it to an invisible but ON-SCREEN pixel to bypass WindowServer hit-testing restrictions.
                            // X: screenWidth - 1, Y: screenHeight - 1 (1 pixel drawn on the bottom right corner of the screen)
                            if let screen = NSScreen.screens.first {
                                let w = screen.frame.width
                                let h = screen.frame.height
                                var newPoint = CGPoint(x: w - 1, y: h - 1)
                                if let pointValue = AXValueCreate(.cgPoint, &newPoint) {
                                    AXUIElementSetAttributeValue(banner, kAXPositionAttribute as CFString, pointValue)
                                }
                                // Brief delay for hit-testing to register it on-screen
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    AXUIElementPerformAction(element, kAXPressAction as CFString)
                                    
                                    // Move it back to -5000, -5000 immediately
                                    var hiddenPoint = CGPoint(x: -5000, y: -5000)
                                    if let hiddenValue = AXValueCreate(.cgPoint, &hiddenPoint) {
                                        AXUIElementSetAttributeValue(banner, kAXPositionAttribute as CFString, hiddenValue)
                                    }
                                }
                            } else {
                                // Fallback
                                AXUIElementPerformAction(element, kAXPressAction as CFString)
                            }
                            
                            return true
                        } else {
                            logOutput += "\(indent)Skipped Close button.\n"
                        }
                    }
                }
                
                var childrenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success, let children = childrenRef as? [AXUIElement] {
                    for child in children {
                        if findAndClickButton(element: child, depth: depth + 1) {
                            return true
                        }
                    }
                }
                return false
            }
            
            found = findAndClickButton(element: banner)
            logOutput += "Found button? \(found)\n"
            
            let logURL = URL(fileURLWithPath: "/Users/macbook/Desktop/Dev/VisorPro/ax_click.log")
            DispatchQueue.global(qos: .utility).async {
                try? logOutput.write(to: logURL, atomically: true, encoding: .utf8)
            }
            
        } else {
        }
        
        lastSmartRoutingBanner = nil
        
        if !found {
        }
    }
    
    private var smartRoutingTrackerTimer: Timer?
    
    private func startSmartRoutingBannerTracker(for element: AXUIElement) {
        smartRoutingTrackerTimer?.invalidate()
        smartRoutingTrackerTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            var roleRef: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
            
            // If the element returns an error (like kAXErrorInvalidUIElement) or doesn't have a role, it's dead
            if error != .success {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        OverlayStateRelay.shared.isSmartRoutingUndoAvailable = false
                    }
                }
                timer.invalidate()
                if self?.lastSmartRoutingBanner != nil {
                    self?.lastSmartRoutingBanner = nil
                }
            }
        }
    }
    
    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
