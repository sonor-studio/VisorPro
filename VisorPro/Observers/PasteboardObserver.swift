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
            
            var action = "copy" 
            
            if let pendingAction = manager.pendingClipboardAction,
               let timestamp = manager.pendingClipboardActionTimestamp,
               Date().timeIntervalSince(timestamp) < 1.5 {
                action = pendingAction
                
                manager.pendingClipboardAction = nil
                manager.pendingClipboardActionTimestamp = nil
            } else if let hwAction = manager.detectedHardwareAction,
               let hwTimestamp = manager.detectedHardwareActionTimestamp,
               Date().timeIntervalSince(hwTimestamp) < 1.5 {
                action = hwAction
            }
            
            let data = manager.processClipboardData(for: action)
            DispatchQueue.main.async {
                manager.triggerClipboardIndicator(text: data.text, action: action, app: data.app, folder: data.folder, size: data.size)
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
