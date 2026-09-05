import SwiftUI

struct OverlayColorModePicker: View {
    @ObservedObject var mediaKeyManager: MediaKeyManager
    @State private var showPresetDetails: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        // 1. Custom (Original)
                        ColorModeTile(
                            title: "Custom",
                            isSelected: mediaKeyManager.overlayColorMode == "custom",
                            colors: [.blue, .red, .green, .yellow]
                        ) {
                            mediaKeyManager.overlayColorMode = "custom"
                        }
                        
                        // 2. Presets
                        ForEach(OverlayColorManager.shared.presets) { preset in
                            let previewColors = preset.colors.values.prefix(4).map { OverlayColorManager.shared.parseColor($0) }
                            
                            ColorModeTile(
                                title: preset.name,
                                isSelected: mediaKeyManager.overlayColorMode == preset.id,
                                colors: Array(previewColors)
                            ) {
                                mediaKeyManager.overlayColorMode = preset.id
                            }
                        }
                        
                        // 3. One Color
                        ColorModeTile(
                            title: "One Color",
                            isSelected: mediaKeyManager.overlayColorMode == "oneColor",
                            colors: [OverlayColorManager.shared.parseColor(mediaKeyManager.globalOverlayColor)]
                        ) {
                            mediaKeyManager.overlayColorMode = "oneColor"
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(minWidth: geometry.size.width)
                }
            }
            .frame(height: 90)
            
            if mediaKeyManager.overlayColorMode == "oneColor" {
                Divider().padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Color")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(["Blue", "Red", "Green", "Yellow", "Orange", "Purple", "Pink", "Teal", "Indigo"], id: \.self) { colorName in
                                ColorModeTile(
                                    title: colorName,
                                    isSelected: mediaKeyManager.globalOverlayColor == colorName,
                                    colors: [OverlayColorManager.shared.parseColor(colorName)]
                                ) {
                                    mediaKeyManager.globalOverlayColor = colorName
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                    }
                }
                .onAppear {
                    if mediaKeyManager.globalOverlayColor == "Default" {
                        mediaKeyManager.globalOverlayColor = "Blue"
                    }
                }
            } else if mediaKeyManager.overlayColorMode.starts(with: "preset_") {
                Divider().padding(.vertical, 8)
                HStack {
                    Spacer()
                    Button(action: { showPresetDetails = true }) {
                        Text("Show Preset Details")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showPresetDetails) {
            PresetDetailsSheet(presetId: mediaKeyManager.overlayColorMode)
        }
    }
}

struct PresetDetailsSheet: View {
    let presetId: String
    @Environment(\.presentationMode) var presentationMode
    
    var preset: OverlayColorManager.ColorPreset? {
        OverlayColorManager.shared.presets.first(where: { $0.id == presetId })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(preset?.name ?? "Preset Details")
                    .font(.headline)
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                if let preset = preset {
                    let groupedKeys: [(String, [String])] = [
                        ("Volume", ["colorOnVolume"]),
                        ("Brightness", ["colorOnBrightness"]),
                        ("Keyboard Brightness", ["colorOnKeyboardBrightness"]),
                        ("Keyboard", ["colorOnCopy", "colorOnCut", "colorOnPaste", "colorOnCapsLock", "colorOnLanguageChange"]),
                        ("Media", ["colorMediaStart", "colorMediaPause", "colorMediaResume"]),
                        ("Wi-Fi", ["colorOnWiFiConnect"]),
                        ("Bluetooth", ["colorOnBluetoothConnect"]),
                        ("Privacy", ["colorOnMicOn", "colorOnCameraOn", "colorOnLocationOn"]),
                        ("Theme", ["colorOnThemeDark", "colorOnThemeLight"]),
                        ("Peripheral", ["colorOnPeripheralConnect"]),
                        ("Display", ["colorOnDisplayConnect", "colorOnDisplayModeChange"]),
                        ("System", ["colorOnHighRam"])
                    ]
                    
                    VStack(spacing: 0) {
                        ForEach(groupedKeys, id: \.0) { group in
                            // Only show group if preset has at least one color in this group
                            if group.1.contains(where: { preset.colors[$0] != nil }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(group.0)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 4)
                                    
                                    ForEach(group.1, id: \.self) { key in
                                        if let colorValue = preset.colors[key] {
                                            HStack {
                                                Text(OverlayColorManager.shared.overlayLabels[key] ?? key)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(OverlayColorManager.shared.parseColor(colorValue))
                                                        .frame(width: 12, height: 12)
                                                    Text(colorValue)
                                                        .font(.system(size: 13, design: .monospaced))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 8)
                                            
                                            Divider().padding(.leading, 24)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 350, height: 450)
    }
}

struct ColorModeTile: View {
    let title: String
    let isSelected: Bool
    let colors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: 80, height: 50)
                    
                    if colors.count > 1 {
                        PizzaColorView(colors: colors)
                            .frame(width: 80, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if let color = colors.first {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(width: 80, height: 50)
                    }
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue, lineWidth: 3)
                            .frame(width: 80, height: 50)
                    }
                }
                
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PizzaColorView: View {
    let colors: [Color]
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = max(geometry.size.width, geometry.size.height)
            
            ZStack {
                ForEach(0..<colors.count, id: \.self) { i in
                    let startAngle = Angle(degrees: Double(i) * (360.0 / Double(colors.count)) - 90)
                    let endAngle = Angle(degrees: Double(i + 1) * (360.0 / Double(colors.count)) - 90)
                    
                    Path { path in
                        path.move(to: center)
                        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                        path.closeSubpath()
                    }
                    .fill(colors[i])
                }
            }
        }
    }
}
