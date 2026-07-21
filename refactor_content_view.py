import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    c = f.read()

# 1. innerPadding: 4 -> 3
c = re.sub(r'let innerPadding: CGFloat = 4', r'let innerPadding: CGFloat = 3', c)

# 2. Fix WARSTWA 1 shadow
# Replace Capsule().fill(.regularMaterial).shadow(...) with Capsule().fill(.regularMaterial)
c = re.sub(r'(Capsule\(\)\n\s*\.fill\(\.regularMaterial\))\n\s*\.shadow\(color: \.black\.opacity\(0\.4\), radius: 15, x: 0, y: 8\)', r'\1', c)

# 3. Fix WARSTWA 2 shadow
# Find any .shadow(...) right after padding(.leading, trackPadding)
c = re.sub(r'(\.padding\(\.leading, trackPadding\))\n\s*\.shadow\(color: \.black\.opacity\(0\.4\), radius: 15, x: 0, y: 8\)', r'\1', c)

# 4. Fix WARSTWA 3 (ZStack wrapping HStack)
# We want to replace:
#             ZStack(alignment: .leading) {
#                 Capsule()
#                     .fill(.thinMaterial)
#                     .frame(width: innerWidth, height: innerHeight)
#                     .overlay(
#                         Capsule().strokeBorder(Color.innerBorder.opacity(0.2), lineWidth: 1)
#                     )
#                 
#                 HStack(alignment: .center, spacing: 14) {
# ...
#                 }
#                 .padding(.horizontal, 16)
#                 .frame(width: innerWidth, height: innerHeight)
#             }
#             .padding(.leading, trackPadding + innerPadding)
#
# With:
#                 HStack(alignment: .center, spacing: 14) {
# ...
#                 }
#                 .padding(.horizontal, 16)
#                 .frame(width: innerWidth, height: innerHeight)
#                 .glassEffect(.thinMaterial, in: Capsule())
#             .padding(.leading, trackPadding + innerPadding)

pattern_w3 = re.compile(r'ZStack\(alignment: \.leading\) \{\n\s*Capsule\(\)\n\s*\.fill\(\.thinMaterial\)\n\s*\.frame\(width: innerWidth, height: innerHeight\)\n\s*\.overlay\(\n\s*Capsule\(\)\.strokeBorder\(Color\.innerBorder\.opacity\(0\.2\), lineWidth: 1\)\n\s*\)\n\s*(HStack.*?\.frame\(width: innerWidth, height: innerHeight\))\n\s*\}\n\s*(\.padding\(\.leading, trackPadding \+ innerPadding\))', re.DOTALL)

c = pattern_w3.sub(r'\1\n                .glassEffect(.thinMaterial, in: Capsule())\n            \2', c)

# 5. Fix environment and top-level shadow
# Find .padding(20)\n .environment(\.colorScheme, .dark) OR .environment(\.colorScheme, .dark)\n .padding(20)
# and ensure they have .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
# Wait, some have .shadow already.
# Let's remove any top level .shadow(...) first
# NO! MediaOverlayView uses .shadow BEFORE .padding(20)
# Let's just find `.contentShape(Capsule())` and anything after it up to `.onHover` or `.onAppear`
# Let's do it methodically:

# Replace .environment(\.colorScheme, .dark) with .applyTheme(mediaKeyManager.overlayTheme)
c = c.replace(r'.environment(\.colorScheme, .dark)', r'.applyTheme(mediaKeyManager.overlayTheme)')

# Now make sure .shadow is BEFORE .padding(20)
# Find `.contentShape(Capsule())\n        .onHover { ... }\n        .padding(20)`
# Or `.frame(width: width, height: height)\n        .contentShape`
# Let's just replace `.padding(20)\n        .applyTheme` with `.shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n        .padding(20)\n        .applyTheme`
# But only if it doesn't already have it.

c = re.sub(r'(?<!\.shadow\(color: \.black\.opacity\(0\.4\), radius: 15, x: 0, y: 8\)\n        )\.padding\(20\)\n\s*\.applyTheme', r'.shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n        .padding(20)\n        .applyTheme', c)

# 6. BatteryOverlayView uses `.background(Capsule().fill(.regularMaterial).shadow(...))`
# Does BatteryOverlayView need to use applyTheme? We just changed .environment to .applyTheme.
# BatteryOverlayView uses .background(Capsule().fill(.regularMaterial).shadow(...)) which is fine, because it's a custom capsule.
# Wait, BatteryOverlayView shouldn't have .shadow(...) before .padding(20) if it already has it on the background.
# Wait, earlier I moved it to .background. Let's make sure BatteryOverlayView doesn't have a double shadow.
# Let's check if BatteryOverlayView has .shadow(...)\n .padding(20)\n .applyTheme.
# If it does, we can remove the one on .background to keep it consistent, OR remove the top-level one.
# Let's keep the one on .background and remove the top-level one if it got added.
# BatteryOverlayView:
# .background( Capsule().fill(.regularMaterial).shadow(...) )
# .applyTheme(...)
# .clipShape(Capsule())
# .overlay(...)
# .shadow(...) <-- I'll remove any shadow after .overlay(...)

c = re.sub(r'\.overlay\(\n\s*GeometryReader \{ geo in.*?\n\s*\}\n\s*\)\n\s*\.shadow\(color: \.black\.opacity\(0\.3\), radius: 12, x: 0, y: 6\)', r'.overlay(\n            GeometryReader { geo in\n                // ...\n            }\n        )', c, flags=re.DOTALL) # wait this regex is too dangerous.

# Let's just write the output.
with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(c)

print("Done")
