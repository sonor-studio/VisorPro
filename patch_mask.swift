import SwiftUI

struct MaskTest: View {
    var progress: Double = 1.0
    var trackWidth: CGFloat = 100
    var trackPadding: CGFloat = 10
    
    var body: some View {
        ZStack(alignment: .leading) {
            Color.clear
            Rectangle()
                .frame(width: trackWidth)
                .offset(x: -((trackWidth + 15) * (1.0 - min(1.0, max(0, progress)))))
                .padding(.leading, trackPadding)
        }
    }
}
