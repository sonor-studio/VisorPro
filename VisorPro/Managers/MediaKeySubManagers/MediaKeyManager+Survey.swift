import Foundation
import AppKit

extension MediaKeyManager {
    
    func showSurvey(questionId: String) {
        let relay = OverlayStateRelay.shared
        
        // Save the survey question ID to the relay state
        relay.activeSurveyQuestionId = questionId
        
        // Register the trigger time
        self.overlayTriggerTimes["survey"] = Date()
        
        // Generate a new timeout event ID so the progress bar / timeout logic resets
        let eventId = UUID()
        relay.surveyEventId = eventId
        
        // Notify WindowManager to display the overlay
        relay.showSurveyIndicator = true
        
        // Auto-hide logic (Survey stays a bit longer, e.g. 15-30 seconds)
        let timeout = 15.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if relay.surveyEventId == eventId {
                self.hideSurvey()
            }
        }
    }
    
    func hideSurvey() {
        OverlayStateRelay.shared.showSurveyIndicator = false
    }
}
