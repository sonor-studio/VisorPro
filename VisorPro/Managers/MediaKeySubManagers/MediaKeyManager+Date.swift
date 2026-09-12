import SwiftUI

extension MediaKeyManager {
    
    func setupDateTimer() {
        // Obserwacja natywnej zmiany dnia (działa niezawodnie po północy)
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            self?.handleDayChange(isStartup: false)
        }
        
        // Sprawdzenie przy uruchomieniu aplikacji, czy minęła północ, gdy aplikacja była wyłączona
        handleDayChange(isStartup: true)
    }
    
    private func handleDayChange(isStartup: Bool) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        let lastTriggeredStr = UserDefaults.standard.string(forKey: "lastTriggeredDateOverlay") ?? ""
        
        if todayStr != lastTriggeredStr {
            UserDefaults.standard.set(todayStr, forKey: "lastTriggeredDateOverlay")
            
            // Jeżeli aplikacja jest uruchamiana i wykryje nowy dzień - pokazujemy.
            // Jeżeli dzień się zmienił w trakcie działania (np. z 23:59 na 00:00) - pokazujemy.
            // UWAGA: Ignorujemy cofnięcie czasu (np. przy testowaniu zmiany daty do tyłu), aby nie wyświetlać fałszywych alarmów przed północą.
            if todayStr > lastTriggeredStr || lastTriggeredStr.isEmpty {
                // Jeśli aplikacja właśnie się włączyła, możemy lekko opóźnić pokazanie nakładki
                if isStartup {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.triggerDateIndicator()
                    }
                } else {
                    triggerDateIndicator()
                }
            }
        }
    }
    
    func triggerDateIndicator() {
        if !enableDate { return }
        
        // Zawsze odświeżajmy eventy przy wywołaniu nakładki (na wypadek, gdyby widok był już w pamięci)
        CalendarEventManager.shared.fetchTodaysEvents()
        
        playNotificationSound(named: soundOnDateChange)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let pos = self.getOverlayPosition(for: "dateOverlayPosition")
            self.dismissCollidingIndicators(newPosition: pos, source: "date")
            
            let executeShow = { [weak self] in
                guard let self = self else { return }
                self.dateEventId = UUID()
                
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.showDateIndicator = true
                    self.overlayTriggerTimes["date"] = Date()
                    self.notifyOverlayStateChanged()
                }
                
                self.notificationTimers["date"]?.invalidate()
                self.notificationTimers["date"] = Timer.scheduledTimer(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self?.showDateIndicator = false
                    }
                }
            }
            
            if self.showDateIndicator {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showDateIndicator = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    executeShow()
                }
            } else {
                executeShow()
            }
        }
    }
}
