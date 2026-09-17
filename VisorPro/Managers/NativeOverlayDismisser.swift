import Cocoa
import ApplicationServices

/// Continually monitors and instantly hides native macOS system overlays (Focus pills, Bluetooth connection toasts)
final class NativeOverlayDismisser {
    
    static let shared = NativeOverlayDismisser()
    
    var enabled: Bool {
        UserDefaults.standard.object(forKey: "dismissNativeOverlays") as? Bool ?? false
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
    
    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }
    
    /// Starts the event-driven observer (zero CPU usage while idle)
    func start() {
        print("🚀 [NativeOverlayDismisser] Starting instant AXObserver (Zero-battery mode)")
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
            print("👁️ [NativeOverlayDismisser] Active AXObserver attached to PID \(pid)")
        }
    }
    
    func handleWindowCreated(_ element: AXUIElement) {
        let identifier = getStringAttribute(element, kAXIdentifierAttribute as String)?.lowercased() ?? ""
        let isBannerID = identifier.contains("banner") || identifier.contains("toast") || identifier.contains("notification")
        
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
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier?.lowercased() ?? ""
        let isControlCenter = bundleID.contains("controlcenter")
        // ---------------------
        
        guard enabled else { return }
        
        var shouldIntercept = false
        
        let isFocus = identifier == "focus-system-banner" || identifier == "focus" || identifier == "donotdisturb"
        
        let isVolume = identifier == "volume-system-banner" || identifier == "volume" || (isShapeMatch && identifier == "" && !isControlCenter)
        
        let isBluetooth = identifier == "smart-routing-system-banner" || identifier.contains("accessory-system-banner") || (isShapeMatch && identifier == "" && isControlCenter)

        if isFocus && MediaKeyManager.shared.enableFocus {
            shouldIntercept = true
        }

        if isBluetooth && MediaKeyManager.shared.enableBluetooth {
            shouldIntercept = true
        }

        if isVolume && MediaKeyManager.shared.enableVolume {
            shouldIntercept = true
        }
        
        if shouldIntercept {
            // Move off-screen instantly before the rendering engine even paints it!
            var newPoint = CGPoint(x: -5000, y: -5000)
            if let pointValue = AXValueCreate(.cgPoint, &newPoint) {
                AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, pointValue)
            }
        }
    }
    
    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
