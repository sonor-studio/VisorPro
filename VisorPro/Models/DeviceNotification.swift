import Foundation

struct DeviceNotification: Identifiable, Equatable {
    let id: String
    let deviceName: String
    let type: String
    let icon: String
    let isConnected: Bool
    let timestamp: Date
    var details: [String: String]? = nil
}
