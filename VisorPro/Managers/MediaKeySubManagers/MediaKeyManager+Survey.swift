import Foundation
import AppKit

extension MediaKeyManager {
    
    struct SurveyEngine {
        static var timer: Timer?
        static var sessionStartDate: Date = Date()
    }
    
    func startSurveyTriggerEngine() {
        let firstLaunchKey = "visorProFirstLaunchDate"
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: firstLaunchKey)
        }
        
        // Fetch latest surveys from Supabase on start
        Task { @MainActor in
            await SurveyLibrary.shared.fetchSurveys()
        }
        
        SurveyEngine.timer?.invalidate()
        // Check every 5 minutes in the background indefinitely (never stop —
        // a new survey may be added to Supabase at any time and should surface)
        SurveyEngine.timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkAndTriggerSurvey()
        }
        
        // First check: random jitter between 3 and 10 minutes after launch
        // so surveys don't appear precisely when the app starts
        let jitter = Double.random(in: 180...600)
        DispatchQueue.main.asyncAfter(deadline: .now() + jitter) {
            self.checkAndTriggerSurvey()
        }
    }
    
    private func checkAndTriggerSurvey() {
        // 1. Session duration check (must be running > 3 minutes — no spam on boot)
        if Date().timeIntervalSince(SurveyEngine.sessionStartDate) < 180 { return }
        
        // 2. At least 7 days must have passed since the very first launch
        let firstLaunchTime = UserDefaults.standard.double(forKey: "visorProFirstLaunchDate")
        guard firstLaunchTime > 0 else { return }
        let daysSinceFirstLaunch = Date().timeIntervalSince(Date(timeIntervalSince1970: firstLaunchTime)) / (24 * 3600)
        if daysSinceFirstLaunch < 7.0 { return }
        
        // 3. At least 3 days must have passed since the last survey was shown
        let lastSurveyTime = UserDefaults.standard.double(forKey: "visorProLastSurveyDate")
        if lastSurveyTime > 0 {
            let daysSinceLastSurvey = Date().timeIntervalSince(Date(timeIntervalSince1970: lastSurveyTime)) / (24 * 3600)
            if daysSinceLastSurvey < 3.0 { return }
        }
        
        // 4. Ensure there is room for the survey based on its configured position and the overlay slot limit
        let limit = max(1, MediaKeyManager.shared.maxSimultaneousNotifications)
        let activeOverlays = VisorProWindowManager.shared.allActiveOverlays
        let surveyPos = self.getOverlayPosition(for: "surveyOverlayPosition")
        
        let activeInSameSlot = activeOverlays.filter { overlay in
            if surveyPos.hasPrefix("top") { return overlay.position.hasPrefix("top") }
            else if surveyPos.hasPrefix("bottom") { return overlay.position.hasPrefix("bottom") }
            else { return !overlay.position.hasPrefix("top") && !overlay.position.hasPrefix("bottom") }
        }
        
        if activeInSameSlot.count >= limit { return }
        if OverlayStateRelay.shared.showSurveyIndicator { return }
        
        // 5. Find a question that this user hasn't answered yet
        //    — We read completed list here, BEFORE dispatching to main thread,
        //      so even if Supabase added a new question after all old ones were done,
        //      it will still be found (timer was never stopped).
        let completed = UserDefaults.standard.stringArray(forKey: "visorProCompletedSurveys") ?? []
        
        DispatchQueue.main.async {
            let availableQuestions = SurveyLibrary.shared.questions.filter { !completed.contains($0.id) }
            
            // No unanswered questions right now — but DON'T stop the timer!
            // A new survey may be added to Supabase and will be fetched next time.
            guard let nextQuestion = availableQuestions.first else { return }
            
            // Record the time we showed this survey (enforces the 3-day cooldown)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "visorProLastSurveyDate")
            self.showSurvey(questionId: nextQuestion.id)
        }
    }
    
    func showSurvey(questionId: String) {
        let relay = OverlayStateRelay.shared
        relay.activeSurveyQuestionId = questionId
        relay.surveyShowThankYou = false
        self.overlayTriggerTimes["survey"] = Date()
        let eventId = UUID()
        relay.surveyEventId = eventId
        relay.showSurveyIndicator = true
        
        DispatchQueue.main.async {
            VisorProWindowManager.shared.updateWindows()
        }
        
        self.scheduleOverlayHide(for: "survey", delay: 15.0)
    }
    
    func hideSurvey() {
        let relay = OverlayStateRelay.shared
        
        // Switch to thank you mode and fire a new event ID so the progress bar
        // starts a fresh 3-second countdown from full
        relay.surveyShowThankYou = true
        relay.surveyThankYouEventId = UUID()
        
        // Resize window to compact thank you size
        DispatchQueue.main.async {
            VisorProWindowManager.shared.updateWindows()
        }
        
        // Use scheduleOverlayHide so the keepAlive/hover mechanism can pause
        // and reset the 3-second countdown when the user hovers over the overlay
        self.scheduleOverlayHide(for: "survey", delay: 3.0)
    }
}
