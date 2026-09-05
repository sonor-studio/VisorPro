import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var app: String
    var folder: String?
    var size: String
    var timestamp: Date
}
