import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    c = f.read()

# 1. Replace all colored icons with .primary
c = re.sub(r'(\s*Image\(systemName:[^\)]+\)\n\s*\.font\([^\)]+\)\n\s*)\.foregroundColor\((?:actionColor|iconColor)\)', r'\1.foregroundColor(.primary)', c)

# 2. Replace BatteryOverlayView body
# Find the start of `var body: some View {` inside `struct BatteryOverlayView`
# and replace it up to `.padding(20)`

new_battery_body = """    var body: some View {
        let width: CGFloat = 260
        let height: CGFloat = 56
        let trackPadding: CGFloat = 4
        let innerPadding: CGFloat = 3
        
        let trackWidth = width - (trackPadding * 2)
        let trackHeight = height - (trackPadding * 2)
        let innerWidth = trackWidth - (innerPadding * 2)
        let innerHeight = trackHeight - (innerPadding * 2)
        
        ZStack(alignment: .leading) {
            // WARSTWA 1: Baza
            ZStack {
                Capsule()
                    .fill(.regularMaterial)
                
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: innerPadding)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: width, height: height)
            
            // WARSTWA 2: Pasek postępu baterii (dookoła)
            CustomCapsule()
                .trim(from: 0, to: animatedBatteryProgress)
                .stroke(batteryColor, style: StrokeStyle(lineWidth: innerPadding, lineCap: .round))
                .frame(width: trackWidth - innerPadding, height: trackHeight - innerPadding)
                .padding(.leading, trackPadding + (innerPadding / 2.0))
                .opacity(isWarningMode && isPulsing ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            
            // WARSTWA 3: Górna warstwa
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 26, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    if actualPercentage == 100 {
                        Text("Connected")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: false, color: .primary, isPluggedIn: actualIsPluggedIn)
                    } else {
                        AnimatablePercentageText(progress: animatedBatteryProgress, isTopTitle: true, color: .primary, isPluggedIn: actualIsPluggedIn)
                        MarqueeText(text: mockedTimeRemaining(for: actualPercentage), font: .system(size: 11, weight: .bold, design: .rounded), foregroundColor: .gray)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .frame(width: innerWidth, height: innerHeight)
            .glassEffect(.thinMaterial, in: Capsule())
            .padding(.leading, trackPadding + innerPadding)
            
            if !isWarningMode && actualIsPluggedIn {
                Image(systemName: "powerplug.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundColor(batteryColor)
                    .shadow(color: batteryColor.opacity(0.8), radius: 4)
                    .modifier(PlugIconMover(
                        progress: animatedBatteryProgress,
                        targetProgress: CGFloat(actualPercentage) / 100.0,
                        width: trackWidth - innerPadding,
                        height: trackHeight - innerPadding
                    ))
                    .padding(.leading, trackPadding + (innerPadding / 2.0))
            }
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onHover { isHovering in
            self.isHovering = isHovering
            mediaKeyManager.keepAlive(for: "battery", isHovering: isHovering)
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .padding(20)"""

pattern = re.compile(r'    var body: some View \{\s*\n\s*HStack\(spacing: 14\) \{.*?\)\n\s*\.padding\(20\)', re.DOTALL)
c = pattern.sub(new_battery_body, c)

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(c)

print("Done")
