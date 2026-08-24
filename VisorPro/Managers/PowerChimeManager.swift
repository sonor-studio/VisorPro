import Foundation

class PowerChimeManager {
    
    static func disableChargingSound() {
        // Krok 1: Ustawienie flagi systemowej w defaults na false
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnAllHardware -bool false")
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnNoHardware -bool true")
        
        executeShellCommand("killall PowerChime")
    }
    
    static func enableChargingSound() {
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnAllHardware -bool true")
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnNoHardware -bool false")
        
        executeShellCommand("open /System/Library/CoreServices/PowerChime.app")
    }
    
    private static func executeShellCommand(_ command: String) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
        }
    }
}
