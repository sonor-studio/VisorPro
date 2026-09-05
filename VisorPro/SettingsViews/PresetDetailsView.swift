import SwiftUI

struct PresetDetailsView: View {
    let presetId: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("View Preset Details")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.001))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if let preset = OverlayColorManager.shared.presets.first(where: { $0.id == presetId }) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(OverlayColorManager.shared.overlayLabels.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(OverlayColorManager.shared.overlayLabels[key] ?? key)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                let colorName = preset.colors[key] ?? "Default"
                                Text(colorName == "Default" ? "Default" : colorName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(colorName == "Default" ? .secondary : OverlayColorManager.shared.parseColor(colorName))
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 8)
                }
            }
        }
    }
}
