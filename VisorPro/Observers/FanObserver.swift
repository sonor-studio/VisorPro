import Foundation
import AppKit
import Combine
import notify

class FanObserver: ObservableObject {
    static let shared = FanObserver()
    
    @Published var isFanRunning: Bool = false
    private var token: Int32 = 0
    private let notificationName = "com.apple.system.thermalpressurelevel"
    
    private init() {
        startObserving()
    }
    
    private func startObserving() {
        let status = notify_register_dispatch(
            notificationName,
            &token,
            DispatchQueue.global(qos: .utility)
        ) { [weak self] _ in
            self?.checkThermalLevel()
        }
        
        if status == NOTIFY_STATUS_OK {
            checkThermalLevel()
        } else {
            print("Failed to register for thermal notifications")
        }
    }
    
    private func checkThermalLevel() {
        var state: UInt64 = 0
        notify_get_state(token, &state)
        
        // Stan 0 to Nominal (Totalny Spoczynek)
        // Stan 1 (Moderate) lub 2 (Heavy) z reguły wywołuje fizyczny start wentylatorów na Apple Silicon zanim ProcessInfo podbije swój status z .nominal
        let currentlyRunning = state >= 1
        
        if currentlyRunning != self.isFanRunning {
            DispatchQueue.main.async {
                self.isFanRunning = currentlyRunning
                // Zgłoszenie zdarzenia wiatraka do UI VisorPro:
                MediaKeyManager.shared.triggerFanOverlay(isRunning: currentlyRunning)
            }
        }
    }
    
    deinit {
        if token != 0 {
            notify_cancel(token)
        }
    }
}

