import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    c = f.read()

# For VolumeOverlayView
c = re.sub(
    r'(        \.frame\(width: width, height: height\))\n(\s*\.padding\(20\)\n\s*\.environment\\\(\\\.colorScheme, \.dark\\\)\n\s*\.onAppear)',
    r'\1\n        .contentShape(Capsule())\n        .onHover { isHovering in\n            mediaKeyManager.keepAlive(for: "volume", isHovering: isHovering)\n        }\n\2',
    c,
    count=1
)

# For BrightnessOverlayView
# Find the second occurrence (which should be Brightness)
c = re.sub(
    r'(        \.frame\(width: width, height: height\))\n(\s*\.padding\(20\)\n\s*\.environment\\\(\\\.colorScheme, \.dark\\\)\n\s*\.onAppear)',
    r'\1\n        .contentShape(Capsule())\n        .onHover { isHovering in\n            mediaKeyManager.keepAlive(for: "brightness", isHovering: isHovering)\n        }\n\2',
    c,
    count=1 # wait, the previous sub already replaced the first one. So this will match the new "first" one, which is Brightness.
)

# For BatteryOverlayView
c = re.sub(
    r'(        \.frame\(width: width, height: height\))\n(\s*\.padding\(20\)\n\s*\.applyTheme\(mediaKeyManager\.overlayTheme\)\n\s*\.onChange\(of: isHovering\))',
    r'\1\n        .contentShape(Capsule())\n        .onHover { isHovering in\n            self.isHovering = isHovering\n            mediaKeyManager.keepAlive(for: "battery", isHovering: isHovering)\n        }\n\2',
    c
)

# For CapsLockOverlayView
c = re.sub(
    r'(        \.frame\(width: width, height: height\))\n(\s*\.padding\(20\)\n\s*\.applyTheme\(mediaKeyManager\.overlayTheme\)\n\s*\.onChange\(of: actualIsOn\))',
    r'\1\n        .contentShape(Capsule())\n        .onHover { isHovering in\n            mediaKeyManager.keepAlive(for: "capslock", isHovering: isHovering)\n        }\n\2',
    c
)

# For CopyOverlayView
c = re.sub(
    r'(        \.frame\(width: width, height: height\))\n(\s*\.padding\(20\)\n\s*\.applyTheme\(mediaKeyManager\.overlayTheme\)\n\s*\.onAppear)',
    r'\1\n        .contentShape(Capsule())\n        .onHover { isHovering in\n            mediaKeyManager.keepAlive(for: "copy", isHovering: isHovering)\n        }\n\2',
    c
)

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(c)
