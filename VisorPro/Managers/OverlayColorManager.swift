import SwiftUI
import Combine

class OverlayColorManager: ObservableObject {
    static let shared = OverlayColorManager()
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var dummyTrigger: Bool = false
    
    let availableColors = ["Blue", "Red", "Green", "Emerald", "Yellow", "Orange", "Purple", "Pink", "Teal", "Indigo", "White/Black"]
    
    struct ColorPreset: Identifiable {
        let id: String
        let name: String
        let colors: [String: String] // key is property name, value is color string
    }
    
    let presets: [ColorPreset] = [
        ColorPreset(id: "preset_default", name: "Default", colors: [
            "colorOnVolume": "Blue",
            "colorOnBrightness": "Yellow",
            "colorOnKeyboardBrightness": "Orange",
            "colorOnCopy": "Blue",
            "colorOnCut": "Red",
            "colorOnPaste": "Green",
            "colorOnCapsLock": "Teal",
            "colorOnLanguageChange": "Purple",
            "colorOnThemeDark": "Indigo",
            "colorOnThemeLight": "Yellow",
            "colorMediaStart": "Blue",
            "colorMediaPause": "Red",
            "colorMediaResume": "Green",
            "colorOnHighRam": "Red",
            "colorOnWiFiConnect": "Teal",
            "colorOnBluetoothConnect": "Indigo",
            "colorOnPeripheralConnect": "Pink",
            "colorOnMicOn": "Orange",
            "colorOnCameraOn": "Green",
            "colorOnLocationOn": "Blue",
            "colorOnDisplayConnect": "Teal",
            "colorOnDisplayModeChange": "Teal",
            "colorOnDateChange": "Emerald"
        ]),
        ColorPreset(id: "preset_vibrant", name: "Vibrant", colors: [
            "colorOnVolume": "Blue",
            "colorOnBrightness": "Yellow",
            "colorOnKeyboardBrightness": "Orange",
            "colorOnCopy": "Green",
            "colorOnCut": "Red",
            "colorOnPaste": "Teal",
            "colorOnCapsLock": "Purple",
            "colorOnLanguageChange": "Indigo",
            "colorOnThemeDark": "Purple",
            "colorOnThemeLight": "Yellow",
            "colorMediaStart": "Blue",
            "colorMediaPause": "Orange",
            "colorMediaResume": "Blue",
            "colorOnHighRam": "Purple",
            "colorOnWiFiConnect": "Blue",
            "colorOnBluetoothConnect": "Blue",
            "colorOnPeripheralConnect": "Teal",
            "colorOnMicOn": "Green",
            "colorOnCameraOn": "Green",
            "colorOnLocationOn": "Blue",
            "colorOnDisplayConnect": "Teal",
            "colorOnDisplayModeChange": "Indigo",
            "colorOnDateChange": "Purple"
        ]),
        ColorPreset(id: "preset_warm", name: "Warm", colors: [
            "colorOnVolume": "Orange",
            "colorOnBrightness": "Yellow",
            "colorOnKeyboardBrightness": "Red",
            "colorOnCopy": "Orange",
            "colorOnCut": "Red",
            "colorOnPaste": "Yellow",
            "colorOnCapsLock": "Red",
            "colorOnLanguageChange": "Orange",
            "colorOnThemeDark": "Orange",
            "colorOnThemeLight": "Yellow",
            "colorMediaStart": "Red",
            "colorMediaPause": "Orange",
            "colorMediaResume": "Red",
            "colorOnHighRam": "Orange",
            "colorOnWiFiConnect": "Orange",
            "colorOnBluetoothConnect": "Yellow",
            "colorOnPeripheralConnect": "Orange",
            "colorOnMicOn": "Red",
            "colorOnCameraOn": "Red",
            "colorOnLocationOn": "Yellow",
            "colorOnDisplayConnect": "Orange",
            "colorOnDisplayModeChange": "Yellow",
            "colorOnDateChange": "Orange"
        ]),
        ColorPreset(id: "preset_ocean", name: "Ocean", colors: [
            "colorOnVolume": "Teal",
            "colorOnBrightness": "Blue",
            "colorOnKeyboardBrightness": "Indigo",
            "colorOnCopy": "Teal",
            "colorOnCut": "Indigo",
            "colorOnPaste": "Emerald",
            "colorOnCapsLock": "Blue",
            "colorOnLanguageChange": "Teal",
            "colorOnThemeDark": "Indigo",
            "colorOnThemeLight": "Blue",
            "colorMediaStart": "Teal",
            "colorMediaPause": "Indigo",
            "colorMediaResume": "Teal",
            "colorOnHighRam": "Teal",
            "colorOnWiFiConnect": "Teal",
            "colorOnBluetoothConnect": "Blue",
            "colorOnPeripheralConnect": "Teal",
            "colorOnMicOn": "Indigo",
            "colorOnCameraOn": "Teal",
            "colorOnLocationOn": "Blue",
            "colorOnDisplayConnect": "Teal",
            "colorOnDisplayModeChange": "Blue",
            "colorOnDateChange": "Teal"
        ]),
        ColorPreset(id: "preset_neon", name: "Neon", colors: [
            "colorOnVolume": "Pink",
            "colorOnBrightness": "Purple",
            "colorOnKeyboardBrightness": "Pink",
            "colorOnCopy": "Pink",
            "colorOnCut": "Red",
            "colorOnPaste": "Purple",
            "colorOnCapsLock": "Pink",
            "colorOnLanguageChange": "Purple",
            "colorOnThemeDark": "Purple",
            "colorOnThemeLight": "Pink",
            "colorMediaStart": "Purple",
            "colorMediaPause": "Pink",
            "colorMediaResume": "Purple",
            "colorOnHighRam": "Pink",
            "colorOnWiFiConnect": "Pink",
            "colorOnBluetoothConnect": "Purple",
            "colorOnPeripheralConnect": "Pink",
            "colorOnMicOn": "Red",
            "colorOnCameraOn": "Purple",
            "colorOnLocationOn": "Pink",
            "colorOnDisplayConnect": "Pink",
            "colorOnDisplayModeChange": "Purple",
            "colorOnDateChange": "Pink"
        ]),
        ColorPreset(id: "preset_nature", name: "Nature", colors: [
            "colorOnVolume": "Green",
            "colorOnBrightness": "Yellow",
            "colorOnKeyboardBrightness": "Green",
            "colorOnCopy": "Green",
            "colorOnCut": "Orange",
            "colorOnPaste": "Yellow",
            "colorOnCapsLock": "Green",
            "colorOnLanguageChange": "Yellow",
            "colorOnThemeDark": "Green",
            "colorOnThemeLight": "Yellow",
            "colorMediaStart": "Green",
            "colorMediaPause": "Orange",
            "colorMediaResume": "Green",
            "colorOnHighRam": "Green",
            "colorOnWiFiConnect": "Emerald",
            "colorOnBluetoothConnect": "Yellow",
            "colorOnPeripheralConnect": "Emerald",
            "colorOnMicOn": "Orange",
            "colorOnCameraOn": "Green",
            "colorOnLocationOn": "Yellow",
            "colorOnDisplayConnect": "Green",
            "colorOnDisplayModeChange": "Yellow",
            "colorOnDateChange": "Emerald"
        ]),
        ColorPreset(id: "preset_monochrome", name: "Monochrome", colors: [
            "colorOnVolume": "White/Black",
            "colorOnBrightness": "White/Black",
            "colorOnKeyboardBrightness": "White/Black",
            "colorOnCopy": "White/Black",
            "colorOnCut": "White/Black",
            "colorOnPaste": "White/Black",
            "colorOnCapsLock": "White/Black",
            "colorOnLanguageChange": "White/Black",
            "colorOnThemeDark": "White/Black",
            "colorOnThemeLight": "White/Black",
            "colorMediaStart": "White/Black",
            "colorMediaPause": "White/Black",
            "colorMediaResume": "White/Black",
            "colorOnHighRam": "White/Black",
            "colorOnWiFiConnect": "White/Black",
            "colorOnBluetoothConnect": "White/Black",
            "colorOnPeripheralConnect": "White/Black",
            "colorOnMicOn": "White/Black",
            "colorOnCameraOn": "White/Black",
            "colorOnLocationOn": "White/Black",
            "colorOnDisplayConnect": "White/Black",
            "colorOnDisplayModeChange": "White/Black", "colorOnDateChange": "White/Black"
        ])
    ]
    
    func parseColor(_ name: String, defaultColor: Color = .blue) -> Color {
        switch name {
        case "Blue": return .blue
        case "Red": return .red
        case "Green": return .green
        case "Yellow": return .yellow
        case "Orange": return .orange
        case "Purple": return .purple
        case "Pink": return Color(red: 0.85, green: 0.15, blue: 0.55) // a more vibrant pink
        case "Teal": return .teal
        case "Indigo": return .indigo
        case "Emerald": return Color(red: 0.0, green: 0.62, blue: 0.45)
        case "White/Black":
            let theme = UserDefaults.standard.string(forKey: "overlayTheme") ?? "system"
            if theme == "dark" { return .white }
            if theme == "light" { return .black }
            return .primary
                case "Default": fallthrough
        default: return defaultColor
        }
    }
    
    func getOverlayColor(for key: String, defaultColor: Color = .blue) -> Color {
        let mode = UserDefaults.standard.string(forKey: "overlayColorMode") ?? "preset_default"
        
        if mode == "oneColor" {
            let hex = UserDefaults.standard.string(forKey: "globalOverlayColor") ?? "Default"
            return parseColor(hex, defaultColor: defaultColor)
        } else if mode.starts(with: "preset_") {
            if let preset = presets.first(where: { $0.id == mode }) {
                let colorName = preset.colors[key] ?? "Default"
                return parseColor(colorName, defaultColor: defaultColor)
            }
        }
        
        // custom mode
        let colorName = UserDefaults.standard.string(forKey: key) ?? "Default"
        return parseColor(colorName, defaultColor: defaultColor)
    }
    
    let overlayLabels: [String: String] = [
        "colorOnVolume": "Volume",
        "colorOnBrightness": "Brightness",
        "colorOnKeyboardBrightness": "Keyboard Brightness",
        "colorOnCopy": "Copy",
        "colorOnCut": "Cut",
        "colorOnPaste": "Paste",
        "colorOnCapsLock": "Caps Lock",
        "colorOnLanguageChange": "Language Change",
        "colorOnThemeDark": "Dark Theme",
        "colorOnThemeLight": "Light Theme",
        "colorMediaStart": "Media Play",
        "colorMediaPause": "Media Pause",
        "colorMediaResume": "Media Resume",
                "colorOnHighRam": "High RAM",
        "colorOnWiFiConnect": "Wi-Fi Connected",
        "colorOnBluetoothConnect": "Bluetooth Connected",
        "colorOnPeripheralConnect": "Peripheral Connected",
        "colorOnMicOn": "Mic On",
        "colorOnCameraOn": "Camera On",
        "colorOnLocationOn": "Location On",
        "colorOnDisplayConnect": "Display Connected",
        "colorOnDisplayModeChange": "Display Mode Changed"
        , "colorOnDateChange": "Date Change"
    ]
}

extension Color {
    static var offStateGray: Color {
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.6, alpha: 1.0)
            } else {
                return NSColor(white: 0.4, alpha: 1.0)
            }
        }))
    }
}
