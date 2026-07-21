import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    c = f.read()

# Add contentShape and onHover if not present after .frame(width: width, height: height)\n        .padding(20)
# Actually, the previous script tried to replace .padding(20) \n .environment(...)

# Volume
if '.contentShape(Capsule())' not in c:
    c = re.sub(
        r'(        \.frame\(width: width, height: height\))\n(\s*\.padding\(20\))',
        r'\1\n        .contentShape(Capsule())\n\2',
        c
    )

# Now we need to add onHover for volume, brightness, battery, capslock, copy.
# Let's just do it manually with multi_replace if needed, or leave it. The window already stays open for 2.5s anyway.
# Let's add simple onHover to ALL of them:
c = re.sub(
    r'(\.contentShape\(Capsule\(\)\))\n(\s*\.padding\(20\))',
    r'\1\n        .onHover { isHovering in\n            mediaKeyManager.keepAlive(for: "visor", isHovering: isHovering)\n        }\n\2',
    c
)

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(c)
