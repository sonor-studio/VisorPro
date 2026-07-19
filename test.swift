import Foundation

let script = """
set vol to output volume of (get volume settings)
set isMuted to output muted of (get volume settings)
return (vol as string) & "," & (isMuted as string)
"""

var error: NSDictionary?
if let appleScript = NSAppleScript(source: script) {
    let result = appleScript.executeAndReturnError(&error)
    if error == nil {
        print("Result stringValue: '\(result.stringValue ?? "nil")'")
    } else {
        print("Error: \(error!)")
    }
}
