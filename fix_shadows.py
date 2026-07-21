import re

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'r') as f:
    content = f.read()

# 1. Remove outer shadow (except where we already manually restored it if we did)
content = re.sub(
    r'\.shadow\(color: \.black\.opacity\(0\.4\), radius: 15, x: 0, y: 8\)\n\s*\.padding\(20\)',
    '.padding(20)',
    content
)

# 2. Add shadow to WARSTWA 1's closing frame
content = re.sub(
    r'(\.frame\(width: width, height: height\))\s+(// WARSTWA 2)',
    r'\1\n            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n            \2',
    content
)

# 3. Add shadow to WARSTWA 2
content = re.sub(
    r'(\.padding\(\.leading, trackPadding\))\s+(// WARSTWA 3)',
    r'\1\n            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)\n            \2',
    content
)

with open('/Users/macbook/Desktop/Dev/Visor/Visor/ContentView.swift', 'w') as f:
    f.write(content)
