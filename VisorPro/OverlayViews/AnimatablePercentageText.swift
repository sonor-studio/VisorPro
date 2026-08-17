import SwiftUI

struct AnimatablePercentageText: View, Animatable {
    var progress: CGFloat
    var isTopTitle: Bool = false
    var color: Color = .white
    var isPluggedIn: Bool = true
    var customText: String? = nil
    
    // Zmiana typu na AnimatablePair naprawia znany błąd SwiftUI, w którym animacja
    // przejścia (np. move) nadpisuje zmienną animatableData i powoduje wartości typu -100.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, 0) }
        set { progress = newValue.first }
    }
    
    private var displayText: String {
        let percentage = max(0, min(100, Int(progress * 100)))
        let statusText = isPluggedIn ? "charged" : "remaining"
        if let customText = customText {
            return customText.replacingOccurrences(of: "%d", with: "\(percentage)")
        } else {
            return "\(percentage)% \(statusText)"
        }
    }
    
    var body: some View {
        Group {
            if customText == "%d%" {
                ZStack(alignment: .trailing) {
                    Text("100%")
                        .font(.system(size: isTopTitle ? 16 : 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .hidden()
                    
                    Text(displayText)
                        .font(.system(size: isTopTitle ? 16 : 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(color)
                        .animation(nil, value: displayText)
                }
            } else {
                Text(displayText)
                    .font(.system(size: isTopTitle ? 16 : 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(color)
                    .animation(nil, value: displayText)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
