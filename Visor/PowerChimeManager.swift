import Foundation

class PowerChimeManager {
    
    /// Wyłącza dźwięk podłączania ładowarki
    static func disableChargingSound() {
        // Krok 1: Ustawienie flagi systemowej w defaults na false
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnAllHardware -bool false")
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnNoHardware -bool true")
        
        // Krok 2: Zamknięcie usługi, aby załadowała nowe ustawienia
        executeShellCommand("killall PowerChime")
        print("Dźwięk ładowarki został wyłączony.")
    }
    
    /// Przywraca domyślny dźwięk podłączania ładowarki
    static func enableChargingSound() {
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnAllHardware -bool true")
        executeShellCommand("defaults write com.apple.PowerChime ChimeOnNoHardware -bool false")
        
        // Ponowne uruchomienie usługi systemowej
        executeShellCommand("open /System/Library/CoreServices/PowerChime.app")
        print("Dźwięk ładowarki został włączony.")
    }
    
    /// Funkcja pomocnicza do wykonywania komend systemowych powłoki (Shell)
    private static func executeShellCommand(_ command: String) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh" // Używamy powłoki systemowej zsh
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Błąd podczas wykonywania komendy: \(error)")
        }
    }
}
