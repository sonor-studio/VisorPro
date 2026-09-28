import re

with open("UniversalOverlayView.swift", "r") as f:
    content = f.read()

# Replace my previous fix with drawingGroup()
old_block = """                ZStack(alignment: .leading) {
                    baseContent()
                        .frame(width: width, height: baseHeight)
                        .allowsHitTesting(false)
                        .animation(nil, value: isExpanded)
                        .contentTransition(.identity)
                        .transaction { t in
                            if isAnimating {
                                t.animation = nil
                            }
                        }
                        
                    HStack(spacing: 0) {"""

new_block = """                ZStack(alignment: .leading) {
                    baseContent()
                        .frame(width: width, height: baseHeight)
                        .allowsHitTesting(false)
                        .animation(nil, value: isExpanded)
                        .drawingGroup()
                        
                    HStack(spacing: 0) {"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open("UniversalOverlayView.swift", "w") as f:
        f.write(content)
    print("Added drawingGroup()")
else:
    print("Block not found!")
