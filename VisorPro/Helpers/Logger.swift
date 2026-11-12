import Foundation

enum Logger {
    @inlinable
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        // In debug mode, optionally forward to system console:
        // NSLog("%@", message())
        #endif
    }
}
