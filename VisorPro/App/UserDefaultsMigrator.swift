import Foundation

struct UserDefaultsMigrator {
    static func migrate(defaults: UserDefaults = .standard) {
        let doubleKeys = ["brightnessStep", "keyboardBrightnessStep", "volumeStep", "overlayMargin"]
        for key in doubleKeys {
            if let val = defaults.object(forKey: key) {
                // Safely convert any numeric value to Double
                if let num = val as? NSNumber {
                    if String(cString: num.objCType) != "d" && String(cString: num.objCType) != "f" {
                        defaults.set(num.doubleValue, forKey: key)
                    }
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        
        let intKeys = ["maxSimultaneousNotifications"]
        for key in intKeys {
            if let val = defaults.object(forKey: key) {
                if let num = val as? NSNumber {
                    let type = String(cString: num.objCType)
                    if type == "d" || type == "f" {
                        defaults.set(num.intValue, forKey: key)
                    }
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        
        let boolKeys = [
            "hasCompletedWelcome", "_forceDashboard", "showMenuBarIcon", "batteryAllowInteractivity", 
            "bluetoothAllowInteractivity", "brightnessAllowInteractivity", "displayAllowInteractivity",
            "keyboardBrightnessAllowInteractivity", "mediaAllowInteractivity", "themeAllowInteractivity",
            "volumeAllowInteractivity", "capsLockAllowInteractivity"
        ]
        
        for key in boolKeys {
            if let val = defaults.object(forKey: key) {
                if !(val is Bool) && !(val is NSNumber) {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }
}
