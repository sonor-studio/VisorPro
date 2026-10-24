import Foundation

enum OverlayStyle: String, CaseIterable, Identifiable {
    case defaultStyle = "default"
    case capsule = "capsule"
    case system = "system"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .defaultStyle: return "Default"
        case .capsule: return "Liquid Glass"
        case .system: return "System"
        }
    }
    
    var iconName: String {
        switch self {
        case .defaultStyle: return "rectangle.roundedtop"
        case .capsule: return "drop.fill"
        case .system: return "apple.logo"
        }
    }
}
