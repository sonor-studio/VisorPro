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
        "MenuBarAgent",       // Older macOS HUDs
        "Control Center",     // BT connection
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
    
    func onSystemEvent(type: EventType) {}
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
        let identifier = getStringAttribute(element, kAXIdentifierAttribute as String)?.lowercased() ?? ""
        
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
        
        // --- DEBUG LOGGING ---
        var allText = ""
        func extractText(_ el: AXUIElement) {
            var val: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &val) == .success, let s = val as? String { allText += s + " | " }
            if AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &val) == .success, let s = val as? String { allText += s + " | " }
            if AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &val) == .success, let s = val as? String { allText += s + " | " }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef) == .success, let children = childrenRef as? [AXUIElement] {
                for child in children { extractText(child) }
            }
        }
        extractText(element)
        
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        
        let logLine = "[\(Date())] Banner: id='\(identifier)', text='\(allText)'\n"
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
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier?.lowercased() ?? ""
        let isControlCenter = bundleID.contains("controlcenter")
        // ---------------------
        
        var shouldIntercept = false
        
        let isFocus = identifier == "focus-system-banner" || identifier == "focus" || identifier == "donotdisturb"
        
        let isVolume = identifier == "volume-system-banner" || identifier == "volume" || (isShapeMatch && identifier == "" && !isControlCenter)
        
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
        
        let isListeningMode = identifier == "listening-mode-system-banner"
        let isSmartRouting = identifier == "smart-routing-system-banner" || (identifier == "" && allText.contains("Banner PID") && !allText.contains("%") && !isListeningMode)
        let isBluetooth = identifier == "smart-routing-system-banner" || identifier.contains("accessory-system-banner") || (isShapeMatch && identifier == "" && isControlCenter) || (identifier == "" && allText.contains("Banner PID") && !isListeningMode)
        
        if isSmartRouting || isBluetooth {
            var seen = Set<String>()
            let texts = allText.components(separatedBy: " | ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.lowercased().contains("banner pid") && !$0.lowercased().contains("window") && seen.insert($0).inserted }
            
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
                // It's a connection banner! Show the generic connection overlay!
                MediaKeyManager.shared.lastSmartRoutingActionTime = Date() // Suppress volume overlay since audio is coming back to Mac
                let deviceName = texts.first(where: { !$0.isEmpty && Int($0.replacingOccurrences(of: "%", with: "")) == nil && !$0.lowercased().contains("connected") }) ?? "AirPods"
                MediaKeyManager.shared.triggerBluetoothIndicator(deviceName: deviceName, deviceAddress: "AIRPODS_CONNECTION", isConnected: true)
            }
        }
        
        if isListeningMode {
            // macOS natively popped up a Listening Mode banner. We intercept it!
            // First, trigger our own overlay to read from the low-level API.
            // The value read there will automatically be exactly what caused this banner.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // We just manually pull the current lstm and show it
                MediaKeyManager.shared.triggerAirPodsModeOverlayFromNativeTrigger()
            }
            self.startListeningModeBannerTracker(for: element, initialText: allText)
            shouldIntercept = true
        }
        
        guard enabled else { return }
        
        if isFocus && MediaKeyManager.shared.enableFocus {
            shouldIntercept = true
        }

        if isBluetooth && MediaKeyManager.shared.enableBluetooth {
            shouldIntercept = true
        }

        if isVolume && MediaKeyManager.shared.enableVolume {
            shouldIntercept = true
            DispatchQueue.main.async {
                MediaKeyManager.shared.triggerVolumeIndicator(playSound: false)
            }
        }
        
        if preventIntercept {
            shouldIntercept = false
        }
        
        if shouldIntercept {
            // Move off-screen instantly before the rendering engine even paints it!
            // We use Y: 99999 to throw it far below any realistic multi-monitor setup (which rarely extends downwards 100k pixels)
            var newPoint = CGPoint(x: 0, y: 99999)
            if let pointValue = AXValueCreate(.cgPoint, &newPoint) {
                AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, pointValue)
            }
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
                                    
                                    // Move it back to 0, 99999 immediately
                                    var hiddenPoint = CGPoint(x: 0, y: 99999)
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
    private var listeningModeBannerTrackerTimer: Timer?
    
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
    
    private func startListeningModeBannerTracker(for element: AXUIElement, initialText: String) {
        listeningModeBannerTrackerTimer?.invalidate()
        var lastText = initialText
        
        listeningModeBannerTrackerTimer = Timer.scheduledTimerInCommonModes(withTimeInterval: 0.2, repeats: true) { timer in
            var roleRef: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
            
            if error != .success {
                timer.invalidate()
                return
            }
            
            var currentText = ""
            func extractText(_ el: AXUIElement) {
                var val: CFTypeRef?
                if AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &val) == .success, let s = val as? String { currentText += s + " | " }
                if AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &val) == .success, let s = val as? String { currentText += s + " | " }
                if AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &val) == .success, let s = val as? String { currentText += s + " | " }
                
                var childrenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef) == .success, let children = childrenRef as? [AXUIElement] {
                    for child in children { extractText(child) }
                }
            }
            extractText(element)
            
            if !lastText.isEmpty && !currentText.isEmpty && currentText != lastText {
                lastText = currentText
                DispatchQueue.main.async {
                    MediaKeyManager.shared.triggerAirPodsModeOverlayFromNativeTrigger()
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
