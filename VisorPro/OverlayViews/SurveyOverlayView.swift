import SwiftUI
import TelemetryClient

struct SurveyOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @State private var isExpanded = false
    
    var body: some View {
        let questionId = overlayState.activeSurveyQuestionId
        let question = SurveyLibrary.questions.first(where: { $0.id == questionId }) ?? SurveyLibrary.questions[0]
        
        let actionColor = OverlayColorManager.shared.getOverlayColor(for: "colorOnSurvey", defaultColor: .blue)
        
        return UniversalOverlayView(
            isPreview: false,
            isExpanded: $isExpanded,
            showProgressBar: true,
            hasTimeoutProgress: true,
            timeoutEventId: overlayState.surveyEventId,
            barColor: actionColor,
            fillCenter: false,
            customWidth: 320,
            customHeight: 180,
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
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, optionText in
                            Button(action: {
                                let answerValue = question.optionValues[index]
                                TelemetryDeck.signal("SurveyAnswer", parameters: [
                                    "survey_id": question.id,
                                    "answer": answerValue
                                ])
                                mediaKeyManager.hideSurvey()
                            }) {
                                Text(optionText)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
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
        )
    }
}
