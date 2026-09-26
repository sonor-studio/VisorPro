import SwiftUI
import TelemetryClient

struct SurveyOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @State private var isExpanded = false
    
    var body: some View {
        let questionId = overlayState.activeSurveyQuestionId
        let question = SurveyLibrary.shared.questions.first(where: { $0.id == questionId }) ?? SurveyLibrary.shared.questions.first
        
        guard let question = question else { return AnyView(EmptyView()) }
        
        let actionColor = OverlayColorManager.shared.getOverlayColor(for: "colorOnSurvey", defaultColor: .blue)
        
        return AnyView(UniversalOverlayView(
            isPreview: false,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutDuration: 15.0,
            timeoutEventId: overlayState.surveyEventId,
            barColor: actionColor,
            fillCenter: false,
            customWidth: 260,
            customHeight: question.height,
            customCornerRadius: 24,
            allowBaseHitTesting: true,
            onSimpleTap: { },
            isExpandable: false,
            expandUpwards: false,
            keepAliveId: "survey",
            baseContent: {
                VStack(spacing: 12) {
                    Text(question.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, optionText in
                            Button(action: {
                                TelemetryDeck.signal("SurveyAnswer", parameters: [
                                    "survey_id": question.id,
                                    "answer": optionText
                                ])
                                
                                var completed = UserDefaults.standard.stringArray(forKey: "visorProCompletedSurveys") ?? []
                                if !completed.contains(question.id) {
                                    completed.append(question.id)
                                    UserDefaults.standard.set(completed, forKey: "visorProCompletedSurveys")
                                }
                                
                                mediaKeyManager.hideSurvey()
                            }) {
                                Text(optionText)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.primary.opacity(0.06))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandCursor()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            },
            expandedContent: {
                EmptyView()
            }
        ))
    }
}
