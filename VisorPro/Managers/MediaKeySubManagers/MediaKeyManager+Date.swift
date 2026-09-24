import SwiftUI

extension MediaKeyManager {
    
    func setupDateTimer() {
        // Observation of native day change (works reliably after midnight)
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            self?.handleDayChange(isStartup: false)
        }
        
        // Checking on app launch if midnight passed while the app was closed
        handleDayChange(isStartup: true)
    }
    
    private func handleDayChange(isStartup: Bool) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        let lastTriggeredStr = UserDefaults.standard.string(forKey: "lastTriggeredDateOverlay") ?? ""
        
        if todayStr != lastTriggeredStr {
            UserDefaults.standard.set(todayStr, forKey: "lastTriggeredDateOverlay")
            
            // If the app is launched and detects a new day - we show it.
            // If the day changed while running (e.g. from 23:59 to 00:00) - we show it.
            // NOTE: We ignore time backwards (e.g. testing date change backwards) to avoid false alarms before midnight.
            if todayStr > lastTriggeredStr || lastTriggeredStr.isEmpty {
                // If the app just started, we can slightly delay showing the overlay
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
        
        // Always refresh events when overlay is triggered (in case the view is already in memory)
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
                self.notificationTimers["date"] = Timer.scheduledTimerInCommonModes(withTimeInterval: MediaKeyManager.notificationDuration, repeats: false) { [weak self] _ in
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
