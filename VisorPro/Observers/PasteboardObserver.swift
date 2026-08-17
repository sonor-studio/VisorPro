import SwiftUI

class PasteboardObserver {
    private weak var manager: MediaKeyManager?
    private var timer: Timer?
    private var lastChangeCount: Int
    
    init(manager: MediaKeyManager) {
        self.manager = manager
        self.lastChangeCount = NSPasteboard.general.changeCount
        startObserving()
    }
    
    func startObserving() {
        // Obserwujemy pasteboard co 0.1 sekundy dla natychmiastowej reakcji
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    private func checkPasteboard() {
        guard let manager = manager, manager.enableKeyboard else { return }
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // Jeśli właśnie nacisnęliśmy skrót klawiszowy (Cmd+C/X/V), OSD zostało już wyświetlone bezpośrednio.
            // Ignorujemy tę zmianę schowka, żeby nie nadpisać OSD domyślnym "Skopiowano".
            if let timestamp = manager.pendingClipboardActionTimestamp,
               Date().timeIntervalSince(timestamp) < 1.5 {
                return
            }
            
            // W przeciwnym razie (np. kopiowanie myszką) domyślnie zakładamy kopiowanie
            var action = "copy" 
            
            if let hwAction = manager.detectedHardwareAction,
               let hwTimestamp = manager.detectedHardwareActionTimestamp,
               Date().timeIntervalSince(hwTimestamp) < 1.5 {
                action = hwAction
            }
            
            // Sprawdzamy czy w schowku jest tekst
            if let copiedText = NSPasteboard.general.string(forType: .string) {
                DispatchQueue.main.async {
                    manager.triggerClipboardIndicator(text: copiedText, action: action)
                }
            } else {
                // Skopiowano coś innego, np. plik lub obrazek
                DispatchQueue.main.async {
                    manager.triggerClipboardIndicator(text: "Plik / Obraz", action: action)
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
