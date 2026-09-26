import SwiftUI
import TelemetryClient

struct SurveyOverlayView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @EnvironmentObject var overlayState: OverlayStateRelay
    @State private var isExpanded = false
    @State private var currentHeight: CGFloat = 180
    @State private var thankYouMessage: ThankYouMessage = ThankYouMessage.all[0]
    
    struct ThankYouMessage {
        let text: String
        let icon: String    // SF Symbol name
        let color: Color
        
        static let all: [ThankYouMessage] = [
            ThankYouMessage(text: "Thank you!",         icon: "heart.fill",        color: .pink),
            ThankYouMessage(text: "You're the best!",   icon: "heart.fill",        color: .pink),
            ThankYouMessage(text: "Much appreciated!",  icon: "heart.fill",        color: .pink),
            ThankYouMessage(text: "You rock!",          icon: "star.fill",         color: .yellow),
            ThankYouMessage(text: "Means a lot!",       icon: "heart.fill",        color: .pink),
            ThankYouMessage(text: "Love the feedback!", icon: "heart.fill",        color: .pink),
            ThankYouMessage(text: "You're amazing!",    icon: "sparkles",          color: .yellow),
            ThankYouMessage(text: "High five!",         icon: "hand.raised.fill",  color: .orange),
        ]
    }
    
    var body: some View {
        let questionId = overlayState.activeSurveyQuestionId
        let question = SurveyLibrary.shared.questions.first(where: { $0.id == questionId }) ?? SurveyLibrary.shared.questions.first
        let showThankYou = overlayState.surveyShowThankYou
        
        guard let question = question else { return AnyView(EmptyView()) }
        
        let actionColor = OverlayColorManager.shared.getOverlayColor(for: "colorOnSurvey", defaultColor: .blue)
        let targetHeight: CGFloat = showThankYou ? 56 : question.height
        
        // Corner radius:
        // - Thank you (56px pill): auto (nil) → UniversalOverlayView computes baseHeight/2 = 28
        // - Survey question (tall): fixed 20px so corners aren't enormous
        let cornerRadius: CGFloat? = showThankYou ? nil : 28
        
        return AnyView(
            UniversalOverlayView(
                isPreview: false,
                isExpanded: $isExpanded,
                showProgressBar: true,
                progress: showThankYou ? 1.0 : 0,
                hasTimeoutProgress: true,
                timeoutDuration: showThankYou ? 3.0 : 15.0,
                timeoutEventId: showThankYou ? overlayState.surveyThankYouEventId : overlayState.surveyEventId,
                barColor: actionColor,
                fillCenter: false,
                customWidth: 260,
                customHeight: currentHeight,
                customCornerRadius: cornerRadius,
                allowBaseHitTesting: true,
                onSimpleTap: { },
                isExpandable: false,
                expandUpwards: false,
                keepAliveId: "survey",
                baseContent: {
                    ZStack {
                        // Thank you compact view
                        if showThankYou {
                            HStack(spacing: 6) {
                                Text(thankYouMessage.text)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Image(systemName: thankYouMessage.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(thankYouMessage.color)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                        
                        // Survey question view
                        if !showThankYou {
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
                                            
                                            // Pick a random message before switching to thank-you mode
                                            thankYouMessage = ThankYouMessage.all.randomElement() ?? ThankYouMessage.all[0]
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
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: showThankYou)
                },
                expandedContent: {
                    EmptyView()
                }
            )
            .onChange(of: targetHeight) { _, newHeight in
                // Skip height animation if the overlay is being dismissed —
                // prevents a bounce-up glitch when X is clicked during thank-you state
                guard overlayState.showSurveyIndicator else {
                    currentHeight = newHeight
                    return
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    currentHeight = newHeight
                }
            }
            .onAppear {
                currentHeight = targetHeight
            }
        )
    }
}
