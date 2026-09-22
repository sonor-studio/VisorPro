import AppKit

struct Shortcut {
    let character: String
    let modifiers: NSEvent.ModifierFlags
}
import SwiftUI

extension String {
    var keyEquivalent: KeyEquivalent? {
        // extract the character part
        let charStr = self.replacingOccurrences(of: "@", with: "")
                          .replacingOccurrences(of: "^", with: "")
                          .replacingOccurrences(of: "~", with: "")
                          .replacingOccurrences(of: "$", with: "")
        guard let first = charStr.first else { return nil }
        return KeyEquivalent(first)
    }
    
    var eventModifiers: EventModifiers {
        var mods = EventModifiers()
        if self.contains("@") { mods.insert(.command) }
        if self.contains("^") { mods.insert(.control) }
        if self.contains("~") { mods.insert(.option) }
        if self.contains("$") { mods.insert(.shift) }
        return mods
    }
    
    var displayString: String {
        if self.isEmpty { return "Click to record" }
        var result = ""
        if self.contains("^") { result += "⌃" }
        if self.contains("~") { result += "⌥" }
        if self.contains("$") { result += "⇧" }
        if self.contains("@") { result += "⌘" }
        let charStr = self.replacingOccurrences(of: "@", with: "")
                          .replacingOccurrences(of: "^", with: "")
                          .replacingOccurrences(of: "~", with: "")
                          .replacingOccurrences(of: "$", with: "")
        result += charStr.uppercased()
        return result
    }
}
