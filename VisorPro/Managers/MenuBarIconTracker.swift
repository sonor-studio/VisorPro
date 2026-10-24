import Cocoa
import ApplicationServices

/// Tracks the screen positions (X coordinates) of macOS Menu Bar Extra icons (Focus, Sound/Volume, Battery, Wi-Fi, etc.).
/// Enables VisorPro's System style HUDs to appear directly underneath the corresponding menu bar icon instead of the center or left of the screen.
@MainActor
final class MenuBarIconTracker {
    static let shared = MenuBarIconTracker()
    
    private var iconCenters: [String: CGFloat] = [:]
    
    private init() {
        // Load previously persisted coordinates, strictly ensuring they are on the right side of the screen (> 400)
        let trackedKeys = ["focus", "volume", "brightness", "keyboardBrightness", "battery", "wifi", "bluetooth", "controlCenter", "default"]
        for key in trackedKeys {
            if let saved = UserDefaults.standard.object(forKey: "cachedMenuBarIconX_\(key)") as? Double, saved > 400 {
                iconCenters[key] = CGFloat(saved)
            } else {
                UserDefaults.standard.removeObject(forKey: "cachedMenuBarIconX_\(key)")
            }
        }
    }
    
    /// Records the center X coordinate for a specific module or icon identifier.
    func recordIconCenter(for type: String, x: CGFloat) {
        guard x > 400 else { return } // Must be on the right side of the screen
        iconCenters[type] = x
        UserDefaults.standard.set(Double(x), forKey: "cachedMenuBarIconX_\(type)")
    }
    
    /// Computes the horizontal center on `screen` for the given overlay type, ensuring the pill fits on-screen.
    func getIconCenter(for type: String, in screen: NSScreen, pillWidth: CGFloat) -> CGFloat {
        let halfWidth = pillWidth / 2.0
        let minAllowedX = max(400.0, screen.frame.midX - 100.0) // Must never be on the left half of the screen
        
        // 1. Direct match for this type (e.g. "focus", "volume", "battery")
        if let direct = iconCenters[type], direct >= minAllowedX {
            return clampX(direct, pillWidth: pillWidth, in: screen)
        }
        
        // 2. Alias mapping for related overlay types
        let alias: String? = {
            switch type {
            case "focus": return "focus"
            case "volume", "brightness", "keyboardBrightness": return "volume"
            case "battery", "accessoryBattery": return "battery"
            case "wifi": return "wifi"
            case "bluetooth", "airpodsMode": return "bluetooth"
            case "mic", "camera", "location": return "controlCenter"
            default: return nil
            }
        }()
        
        if let alias = alias, let aliasX = iconCenters[alias], aliasX >= minAllowedX {
            return clampX(aliasX, pillWidth: pillWidth, in: screen)
        }
        
        // 3. Check VisorPro's own status item in the menu bar
        if let button = MenuBarManager.shared.statusItemButton,
           let window = button.window,
           window.frame.origin.x >= minAllowedX {
            let rectInWindow = button.convert(button.bounds, to: nil)
            let screenRect = window.convertToScreen(rectInWindow)
            if screenRect.midX >= minAllowedX {
                return clampX(screenRect.midX, pillWidth: pillWidth, in: screen)
            }
        }
        
        // 4. Any other known valid menu bar item (e.g. Focus or Control Center position)
        if let anyRecordedX = iconCenters.values.first(where: { $0 >= minAllowedX }) {
            return clampX(anyRecordedX, pillWidth: pillWidth, in: screen)
        }
        
        // 5. Fallback: Right-aligned under the menu bar extras section
        // Typically status icons occupy the section 100pt to 250pt from the right edge
        let fallbackX = screen.frame.maxX - halfWidth - 150.0
        return clampX(fallbackX, pillWidth: pillWidth, in: screen)
    }
    
    /// Scans running Control Center elements asynchronously to discover icon positions
    func scanMenuBarItemsAsync() {
        guard checkAXIsProcessTrustedReliably() else { return }
        
        DispatchQueue.global(qos: .utility).async {
            let ccApps = NSWorkspace.shared.runningApplications.filter {
                $0.bundleIdentifier == "com.apple.controlcenter"
            }
            guard let cc = ccApps.first else { return }
            
            let appElement = AXUIElementCreateApplication(cc.processIdentifier)
            var foundPositions: [String: CGFloat] = [:]
            
            func inspect(_ el: AXUIElement) {
                var posRef: CFTypeRef?
                var sizeRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
                      AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success else { return }
                
                var pt = CGPoint.zero
                var sz = CGSize.zero
                guard let p = posRef, AXValueGetValue(p as! AXValue, .cgPoint, &pt),
                      let s = sizeRef, AXValueGetValue(s as! AXValue, .cgSize, &sz),
                      sz.width > 0, pt.y <= 50, pt.x > 400 else { return }
                
                let midX = pt.x + (sz.width / 2.0)
                
                var idRef: CFTypeRef?
                var titleRef: CFTypeRef?
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(el, kAXIdentifierAttribute as CFString, &idRef)
                AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &titleRef)
                AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &descRef)
                
                let combined = "\(idRef as? String ?? "") \(titleRef as? String ?? "") \(descRef as? String ?? "")".lowercased()
                
                if combined.contains("focus") || combined.contains("disturb") || combined.contains("moon") {
                    foundPositions["focus"] = midX
                } else if combined.contains("audio") || combined.contains("sound") || combined.contains("volume") || combined.contains("audiovideo") {
                    foundPositions["volume"] = midX
                    foundPositions["brightness"] = midX
                    foundPositions["keyboardBrightness"] = midX
                } else if combined.contains("battery") {
                    foundPositions["battery"] = midX
                } else if combined.contains("wifi") || combined.contains("airport") {
                    foundPositions["wifi"] = midX
                } else if combined.contains("bluetooth") {
                    foundPositions["bluetooth"] = midX
                } else if combined.contains("controlcenter") || combined.contains("control center") {
                    foundPositions["controlCenter"] = midX
                }
            }
            
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for win in windows { inspect(win) }
            }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for child in children { inspect(child) }
            }
            
            if !foundPositions.isEmpty {
                DispatchQueue.main.async {
                    for (k, v) in foundPositions {
                        MenuBarIconTracker.shared.recordIconCenter(for: k, x: v)
                    }
                }
            }
        }
    }
    
    private func clampX(_ x: CGFloat, pillWidth: CGFloat, in screen: NSScreen) -> CGFloat {
        let minX = screen.frame.minX + (pillWidth / 2.0) + 12.0
        let maxX = screen.frame.maxX - (pillWidth / 2.0) - 12.0
        return max(minX, min(maxX, x))
    }
}
