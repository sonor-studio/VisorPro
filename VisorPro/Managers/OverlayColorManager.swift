import SwiftUI
import Combine

class OverlayColorManager: ObservableObject {
    static let shared = OverlayColorManager()
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var dummyTrigger: Bool = false
    
    let availableColors = ["Blue", "Red", "Green", "Yellow", "Orange", "Purple", "Pink", "Teal", "Indigo"]
    
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
            "colorOnDisplayModeChange": "Teal"
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
                        "colorOnHighRam": "Red",
            "colorOnWiFiConnect": "Blue",
            "colorOnBluetoothConnect": "Blue",
            "colorOnPeripheralConnect": "Teal",
            "colorOnMicOn": "Green",
            "colorOnCameraOn": "Green",
            "colorOnLocationOn": "Blue",
            "colorOnDisplayConnect": "Teal",
            "colorOnDisplayModeChange": "Indigo"
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
                        "colorOnHighRam": "Red",
            "colorOnWiFiConnect": "Orange",
            "colorOnBluetoothConnect": "Yellow",
            "colorOnPeripheralConnect": "Orange",
            "colorOnMicOn": "Red",
            "colorOnCameraOn": "Red",
            "colorOnLocationOn": "Yellow",
            "colorOnDisplayConnect": "Orange",
            "colorOnDisplayModeChange": "Yellow"
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
        case "Default": fallthrough
        default: return defaultColor
        }
    }
    
    func getOverlayColor(for key: String, defaultColor: Color = .blue) -> Color {
        let mode = UserDefaults.standard.string(forKey: "overlayColorMode") ?? "custom"
        
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
    ]
}
