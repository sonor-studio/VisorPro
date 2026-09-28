import SwiftUI

struct SidebarIcon: View {
    let systemName: String
    let color: Color
    
    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
            .foregroundColor(.white)
            .padding(4)
            .background(color)
            .cornerRadius(6)
    }
}
