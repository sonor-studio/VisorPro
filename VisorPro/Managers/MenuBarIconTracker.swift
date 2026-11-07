import Cocoa
import ApplicationServices

/// Tracks the screen positions (X coordinates) of macOS Menu Bar Extra icons (Focus, Sound/Volume, Battery, Wi-Fi, etc.).
/// Enables VisorPro's System style HUDs to appear directly underneath the corresponding menu bar icon instead of the center or left of the screen.
@MainActor
final class MenuBarIconTracker {
    static let shared = MenuBarIconTracker()
    
    private var iconCenters: [String: CGFloat] = [:]
    
    private init() {
        // Load previously persisted coordinates, validating that they fall into a sensible menu bar extras range
        let trackedKeys = ["focus", "volume", "brightness", "keyboardBrightness", "battery", "wifi", "bluetooth", "controlCenter"]
        let mainWidth = NSScreen.main?.frame.width ?? 1512.0
        let minSensibleX = max(400.0, mainWidth - 600.0)
        let maxSensibleX = mainWidth - 75.0 // Nothing to the right of mainWidth - 75 can be a menu extra icon (clock sits at maxX - ~65)
        
        for key in trackedKeys {
            if let saved = UserDefaults.standard.object(forKey: "cachedMenuBarIconX_\(key)") as? Double {
                let val = CGFloat(saved)
                // Filter out any previously poisoned or out-of-range coordinates (e.g. from OSD windows or sliders)
                // Specifically purge any legacy poisoned volume value (< 1250 on >= 1400 screens) or anything in clock area (> mainWidth - 75)
                let isPoisonedVolume = (key == "volume" && mainWidth >= 1400 && val < 1250)
                let isPoisonedClockArea = (val > maxSensibleX)
                if val >= minSensibleX && !isPoisonedClockArea && !isPoisonedVolume {
                    iconCenters[key] = val
                } else {
                    UserDefaults.standard.removeObject(forKey: "cachedMenuBarIconX_\(key)")
                }
            }
        }
        
        // Scan for fresh, authentic menu bar coordinates on launch
        scanMenuBarItemsAsync()
    }
    
    /// Records the center X coordinate for a specific module or icon identifier.
    func recordIconCenter(for type: String, x: CGFloat) {
        let mainWidth = NSScreen.main?.frame.width ?? 1512.0
        let minAllowedX = max(350.0, mainWidth - 650.0)
        let maxAllowedX = mainWidth - 75.0 // No menu extra icon can sit inside the clock (maxX - ~65)
        guard x >= minAllowedX && x <= maxAllowedX else { return }
        iconCenters[type] = x
        UserDefaults.standard.set(Double(x), forKey: "cachedMenuBarIconX_\(type)")
    }
    
    /// Computes the horizontal center on `screen` for the given overlay type, ensuring the pill fits on-screen.
    func getIconCenter(for type: String, in screen: NSScreen, pillWidth: CGFloat) -> CGFloat {
        let screenMinX = screen.visibleFrame.minX
        let screenMaxX = screen.visibleFrame.maxX
        let minAllowedX = screenMinX + (screen.visibleFrame.width * 0.4) // Must be on the right 60% of the screen
        
        let primaryScreen = NSScreen.screens.first ?? screen
        let isPrimary = (screen == primaryScreen)
        
        // Helper to project a coordinate from primary screen to the target screen if displaying on an external monitor
        func mapToScreen(_ x: CGFloat) -> CGFloat {
            if isPrimary { return x }
            if x >= screen.frame.minX && x <= screen.frame.maxX {
                return x
            }
            let offsetFromRight = primaryScreen.frame.maxX - x
            return screen.frame.maxX - offsetFromRight
        }
        
        // 1. VisorPro's own status item in the menu bar:
        // When VisorPro's menu bar icon is active and visible, ALL VisorPro System overlays anchor directly under our icon.
        let showMenuBarIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        if showMenuBarIcon,
           let button = MenuBarManager.shared.statusItemButton,
           let window = button.window {
            let rectInWindow = button.convert(button.bounds, to: nil)
            let screenRect = window.convertToScreen(rectInWindow)
            let mapped = mapToScreen(screenRect.midX)
            if mapped >= minAllowedX && mapped <= screenMaxX {
                return clampX(mapped, pillWidth: pillWidth, in: screen)
            }
        }
        
        // 2. Direct match for this type (e.g. "focus", "volume", "battery")
        if let direct = iconCenters[type] {
            let mapped = mapToScreen(direct)
            if mapped >= minAllowedX && mapped <= screenMaxX {
                return clampX(mapped, pillWidth: pillWidth, in: screen)
            }
        }
        
        // 3. Alias mapping for related overlay types
        let alias: String? = {
            switch type {
            case "focus": return "focus"
            case "volume", "brightness", "keyboardBrightness": return "volume"
            case "battery": return "battery"
            case "wifi": return "wifi"
            case "bluetooth", "airpodsMode", "airpodsGroupBattery", "accessoryBattery", "smartRouting": return "bluetooth"
            case "mic", "camera", "location": return "controlCenter"
            default: return nil
            }
        }()
        
        if let alias = alias, let aliasX = iconCenters[alias] {
            let mapped = mapToScreen(aliasX)
            if mapped >= minAllowedX && mapped <= screenMaxX {
                return clampX(mapped, pillWidth: pillWidth, in: screen)
            }
        }
        
        // 4. Fallback to Control Center icon if available (standard anchor for unpinned modules)
        if let ccX = iconCenters["controlCenter"] {
            let mapped = mapToScreen(ccX)
            if mapped >= minAllowedX && mapped <= screenMaxX {
                return clampX(mapped, pillWidth: pillWidth, in: screen)
            }
        }
        
        // 5. Deterministic fallback across known menu bar items in stable priority order
        let fallbackPriority = ["volume", "battery", "wifi", "bluetooth", "focus"]
        for key in fallbackPriority {
            if let recordedX = iconCenters[key] {
                let mapped = mapToScreen(recordedX)
                if mapped >= minAllowedX && mapped <= screenMaxX {
                    return clampX(mapped, pillWidth: pillWidth, in: screen)
                }
            }
        }
        
        // 6. Final Fallback: Right-aligned under the standard menu bar extras section
        // Centers the pill in the typical status icons region (~130pt from the right edge)
        let fallbackAnchor = screen.visibleFrame.maxX - 130.0
        return clampX(fallbackAnchor, pillWidth: pillWidth, in: screen)
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
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef) == .success,
                   let role = roleRef as? String {
                    // Genuine menu bar items have role AXMenuBarItem, AXMenuExtra, or AXButton in the menu bar
                    guard role == "AXMenuBarItem" || role == "AXMenuExtra" || role == "AXButton" else { return }
                }
                
                var posRef: CFTypeRef?
                var sizeRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
                      AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success else { return }
                
                var pt = CGPoint.zero
                var sz = CGSize.zero
                guard let p = posRef, AXValueGetValue(p as! AXValue, .cgPoint, &pt),
                      let s = sizeRef, AXValueGetValue(s as! AXValue, .cgSize, &sz) else { return }
                
                let mainWidth = NSScreen.main?.frame.width ?? 1512.0
                // Strict geometry check: must be a genuine menu bar item!
                // Menu bar is at the top of the display (y <= 30), item height is 12-35pt, item width is 10-160pt, must not be in clock area (<= mainWidth - 75)
                guard pt.y <= 30,
                      sz.height >= 12 && sz.height <= 35,
                      sz.width >= 10 && sz.width <= 160 else { return }
                
                let midX = pt.x + (sz.width / 2.0)
                guard midX <= (mainWidth - 75.0) else { return }
                
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
                } else if combined.contains("wifi") || combined.contains("wi-fi") || combined.contains("wi‑fi") || combined.contains("airport") {
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
        let halfWidth = pillWidth / 2.0
        let minX = screen.visibleFrame.minX + halfWidth + 12.0
        let maxX = screen.visibleFrame.maxX - halfWidth - 12.0
        guard maxX >= minX else { return screen.visibleFrame.midX }
        return max(minX, min(maxX, x))
    }
}
