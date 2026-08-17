import SwiftUI

struct PlaceholderSettingsView: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("\(title) Settings")
                .font(.title)
                .foregroundColor(.secondary)
            Text("Settings for \(title.lowercased()) will appear here.")
                .foregroundColor(.secondary)
        }
        .navigationTitle(title)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
