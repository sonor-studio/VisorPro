import SwiftUI

struct IsolatedOverlayWrapper<Content: View>: View, Equatable {
    let overlay: ContentView.ActiveOverlay
    let content: Content
    
    static func == (lhs: IsolatedOverlayWrapper, rhs: IsolatedOverlayWrapper) -> Bool {
        lhs.overlay == rhs.overlay
    }
    
    var body: some View {
        content
    }
}
