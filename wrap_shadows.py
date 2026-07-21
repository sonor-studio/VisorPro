import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    content = f.read()

# 1. Remove all currently misplaced shadows
content = content.replace('            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n', '')
content = content.replace('        .shadow(color: .clear, radius: 0) // Placeholder\n', '')
content = content.replace('        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n', '')

# Now, we need to wrap WARSTWA 1 and WARSTWA 2 in a ZStack with a shadow.
# Let's find all overlay views. They all start with:
#         ZStack(alignment: .leading) {
#             // WARSTWA 1: Baza
# and end with WARSTWA 3.

# We want to replace:
#             // WARSTWA 1: Baza
# with
#             ZStack(alignment: .leading) {
#                 // WARSTWA 1: Baza
# 
# And we want to replace:
#             // WARSTWA 3: Górna warstwa
# with
#             }
#             .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
#             
#             // WARSTWA 3: Górna warstwa

# But wait, we need to indent everything between WARSTWA 1 and WARSTWA 3?
# In Swift, indentation is ignored by the compiler, so we don't strict-need to indent it, but it's cleaner.
# Let's just inject the ZStack wrapper without changing inner indentation.

# Wait, BatteryOverlayView has // WARSTWA 4: Ikona wtyczki.
# And CapsLockOverlayView doesn't have WARSTWA 2 comment.
# Let's do it manually for each view to be safe!

content = re.sub(
    r'(ZStack\(alignment: \.leading\) \{\n)(\s*// WARSTWA 1: Baza)',
    r'\1            ZStack(alignment: .leading) {\n\2',
    content
)

content = re.sub(
    r'(\s*// WARSTWA 3: Górna warstwa)',
    r'\n            }\n            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n\1',
    content
)

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(content)
