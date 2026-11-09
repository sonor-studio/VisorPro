import Foundation

enum OverlayStyle: String, CaseIterable, Identifiable {
    case defaultStyle = "default"
    case capsule = "capsule"
    case system = "system"
    case classic = "classic"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .defaultStyle: return "Default"
        case .capsule: return "Liquid Glass"
        case .system: return "System"
        case .classic: return "Classic"
        }
    }
    
    var iconName: String {
        switch self {
        case .defaultStyle: return "rectangle.roundedtop"
        case .capsule: return "drop.fill"
        case .system: return "apple.logo"
        case .classic: return "square.fill"
        }
    }
    
    /// Returns the effective runtime style accounting for macOS version capabilities.
    /// On macOS < 26.0:
    /// - "system" resolves to "classic" since modern system HUDs require macOS 26+.
    /// - "capsule" (Liquid Glass) resolves to "default" since .glassEffect() requires macOS 26+.
    static func effectiveStyle(for raw: String) -> String {
        if #available(macOS 26.0, *) {
            return raw
        } else {
            if raw == "system" {
                return "classic"
            }
            if raw == "capsule" {
                return "default"
            }
            return raw
        }
    }
}
