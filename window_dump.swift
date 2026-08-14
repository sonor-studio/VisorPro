import Cocoa

let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
if let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
    for info in windowInfoList {
        let owner = info[kCGWindowOwnerName as String] as? String ?? ""
        let name = info[kCGWindowName as String] as? String ?? ""
        let bounds = info[kCGWindowBounds as String] as? [String: Any]
        let layer = info[kCGWindowLayer as String] as? Int ?? 0
        if owner == "Control Center" || owner == "SystemUIServer" || owner == "WindowServer" || owner == "System" || layer >= 20 {
            print("Window: Owner=\(owner), Name=\(name), Layer=\(layer), Bounds=\(bounds ?? [:])")
        }
    }
}
