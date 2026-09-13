import SwiftUI

struct AnimatablePercentageText: View, Animatable {
    var progress: CGFloat
    var isTopTitle: Bool = false
    var color: Color = .white
    var isPluggedIn: Bool = true
    var customText: String? = nil
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, 0) }
        set { progress = newValue.first }
    }
    
    private var displayText: String {
        let p = progress * 100
        let percentage = (p.isFinite && p >= Double(Int.min) && p <= Double(Int.max)) ? max(0, min(100, Int(p))) : 0
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
