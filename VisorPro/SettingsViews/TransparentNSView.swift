import SwiftUI

class TransparentNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
