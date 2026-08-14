import Cocoa
import ApplicationServices

let apps = NSWorkspace.shared.runningApplications
let targets = ["com.apple.controlcenter", "com.apple.systemuiserver"]

for bundle in targets {
    if let app = apps.first(where: { $0.bundleIdentifier == bundle }) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        print("Checking \(bundle)")
        
        var value: CFTypeRef?
        var res = AXUIElementCopyAttributeValue(axApp, kAXExtrasMenuBarAttribute as CFString, &value)
        print("  kAXExtrasMenuBarAttribute: \(res.rawValue)")
        
        if res != .success {
            res = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &value)
            print("  kAXMenuBarAttribute: \(res.rawValue)")
        }
        
        if let menuBar = value {
            var childrenVal: CFTypeRef?
            AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenVal)
            if let children = childrenVal as? [AXUIElement] {
                print("  Found \(children.count) items in menu bar")
                for child in children {
                    var title: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                    var desc: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &desc)
                    print("    Item: \(title ?? "nil" as CFTypeRef) - \(desc ?? "nil" as CFTypeRef)")
                    
                    var subVal: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subVal) == .success, let subChildren = subVal as? [AXUIElement] {
                        for subChild in subChildren {
                            var sTitle: CFTypeRef?
                            AXUIElementCopyAttributeValue(subChild, kAXTitleAttribute as CFString, &sTitle)
                            var sDesc: CFTypeRef?
                            AXUIElementCopyAttributeValue(subChild, kAXDescriptionAttribute as CFString, &sDesc)
                            print("      SubItem: \(sTitle ?? "nil" as CFTypeRef) - \(sDesc ?? "nil" as CFTypeRef)")
                        }
                    }
                }
            }
        }
    }
}
