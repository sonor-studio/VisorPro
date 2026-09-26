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
        
        // Fetch latest surveys from Supabase
        Task { @MainActor in
            await SurveyLibrary.shared.fetchSurveys()
        }
        
        SurveyEngine.timer?.invalidate()
        SurveyEngine.timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkAndTriggerSurvey()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 180) {
            self.checkAndTriggerSurvey()
        }
    }
    
    private func checkAndTriggerSurvey() {
        // 1. Session duration check (must be running for > 3 minutes so it doesn't spam on boot)
        if Date().timeIntervalSince(SurveyEngine.sessionStartDate) < 180 { return }
        
        // 2. Check if 7 days have passed since the app was first launched
        let firstLaunchTime = UserDefaults.standard.double(forKey: "visorProFirstLaunchDate")
        let firstLaunchDate = Date(timeIntervalSince1970: firstLaunchTime)
        let daysSinceFirstLaunch = Date().timeIntervalSince(firstLaunchDate) / (24 * 3600)
        
        if daysSinceFirstLaunch < 7.0 { return }
        
        // 3. Throttle surveys (only show 1 survey every 3 days)
        let lastSurveyTime = UserDefaults.standard.double(forKey: "visorProLastSurveyDate")
        if lastSurveyTime > 0 {
            let lastSurveyDate = Date(timeIntervalSince1970: lastSurveyTime)
            let daysSinceLastSurvey = Date().timeIntervalSince(lastSurveyDate) / (24 * 3600)
            if daysSinceLastSurvey < 3.0 { return }
        }
        
        // 4. Must have an empty screen (no other overlays active)
        if !VisorProWindowManager.shared.allActiveOverlays.isEmpty { return }
        if OverlayStateRelay.shared.showSurveyIndicator { return }
        
        // 5. Select a question that hasn't been answered yet
        let completed = UserDefaults.standard.stringArray(forKey: "visorProCompletedSurveys") ?? []
        
        // MUST run on main actor since SurveyLibrary is @MainActor
        DispatchQueue.main.async {
            let availableQuestions = SurveyLibrary.shared.questions.filter { !completed.contains($0.id) }
            
            guard let nextQuestion = availableQuestions.first else {
                SurveyEngine.timer?.invalidate()
                return 
            }
            
            // Record that we showed a survey today
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "visorProLastSurveyDate")
            self.showSurvey(questionId: nextQuestion.id)
        }
    }
    
    func showSurvey(questionId: String) {
        let relay = OverlayStateRelay.shared
        relay.activeSurveyQuestionId = questionId
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
        OverlayStateRelay.shared.showSurveyIndicator = false
        DispatchQueue.main.async {
            VisorProWindowManager.shared.updateWindows()
        }
    }
}
