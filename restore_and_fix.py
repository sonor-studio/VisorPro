import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    c = f.read()

# 1. Fix onChange warnings
c = c.replace('.onChange(of: isVisible) { visible in', '.onChange(of: isVisible) { _, visible in')
c = c.replace('.onChange(of: overlayWindow) { window in', '.onChange(of: overlayWindow) { _, window in')

# 2. Convert old Text elements to MarqueeText
volume_text = '''                    Text(actualIsMuted ? "Muted" : mediaKeyManager.currentAudioDeviceName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)'''
volume_marquee = '''                    MarqueeText(text: actualIsMuted ? "Muted" : mediaKeyManager.currentAudioDeviceName, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)'''
c = c.replace(volume_text, volume_marquee)

brightness_text = '''                    Text("Display")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)'''
brightness_marquee = '''                    MarqueeText(text: "Display", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)'''
c = c.replace(brightness_text, brightness_marquee)

capslock_text = '''                        Text(actionTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)'''
capslock_marquee = '''                        MarqueeText(text: actionTitle, font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)'''
c = c.replace(capslock_text, capslock_marquee)

copy_text = '''                    Text(isCopy ? "Skopiowano" : "Wklejono")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)'''
copy_marquee = '''                    MarqueeText(text: isCopy ? "Skopiowano" : "Wklejono", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)'''
c = c.replace(copy_text, copy_marquee)

# 3. Add inner border to WARSTWA 3 where it's missing (Volume, Brightness, CapsLock, Copy, Battery)
# It matches:
#                 Capsule()
#                     .fill(.thinMaterial)
#                     .frame(width: innerWidth, height: innerHeight)
c = re.sub(
    r'(Capsule\(\)\n\s*\.fill\(\.thinMaterial\)\n\s*\.frame\(width: innerWidth, height: innerHeight\))(\n)',
    r'\1\n                    .overlay(\n                        Capsule().strokeBorder(Color.innerBorder.opacity(0.2), lineWidth: 1)\n                    )\2',
    c
)

# 4. Fix WARSTWA 1 border color
c = c.replace('Color.white.opacity(0.15)', 'Color.primary.opacity(0.15)')

# 5. Fix Shadows
# 5a. Remove outer shadow
c = c.replace('        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n        .padding(20)', '        .padding(20)')

# 5b. Add desktop shadow to Capsule().fill(.regularMaterial)
# Replace:
#                 Capsule()
#                     .fill(.regularMaterial)
# With:
#                 Capsule()
#                     .fill(.regularMaterial)
#                     .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
c = re.sub(
    r'(Capsule\(\)\n\s*\.fill\(\.regularMaterial\))\n',
    r'\1\n                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n',
    c
)

# 5c. Add inner shadow to WARSTWA 2
# After the mask and padding
c = re.sub(
    r'(\.padding\(\.leading, trackPadding(?: \+ \(innerPadding / 2\))?\))\n',
    r'\1\n            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n',
    c
)

# Wait! Is there anything else?
# Let's save!
with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(c)
