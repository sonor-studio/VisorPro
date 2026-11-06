import Foundation

class PowerChimeManager {
    
    static func disableChargingSound() {
        DispatchQueue.global(qos: .utility).async {
            setDefaults(key: "ChimeOnAllHardware", boolValue: false)
            setDefaults(key: "ChimeOnNoHardware", boolValue: true)
            runExecutable(path: "/usr/bin/killall", arguments: ["PowerChime"])
        }
    }
    
    static func enableChargingSound() {
        DispatchQueue.global(qos: .utility).async {
            setDefaults(key: "ChimeOnAllHardware", boolValue: true)
            setDefaults(key: "ChimeOnNoHardware", boolValue: false)
            runExecutable(path: "/usr/bin/open", arguments: ["/System/Library/CoreServices/PowerChime.app"])
        }
    }
    
    private static func setDefaults(key: String, boolValue: Bool) {
        runExecutable(
            path: "/usr/bin/defaults",
            arguments: ["write", "com.apple.PowerChime", key, "-bool", boolValue ? "true" : "false"]
        )
    }
    
    private static func runExecutable(path: String, arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
        }
    }
}
