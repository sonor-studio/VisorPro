import os
import re

directory = "/Users/macbook/Desktop/Dev/Visor/Visor"

for filename in os.listdir(directory):
    if not filename.endswith(".swift"):
        continue
    filepath = os.path.join(directory, filename)
    with open(filepath, "r") as f:
        content = f.read()

    original_content = content

    # 1. Add progressAnimation state if missing
    if "@State private var animatedProgress: CGFloat = 1.0" in content and "@State private var progressAnimation" not in content:
        content = content.replace(
            "@State private var animatedProgress: CGFloat = 1.0",
            "@State private var animatedProgress: CGFloat = 1.0\n    @State private var progressAnimation: Animation? = .linear(duration: 3.5)"
        )

    # 2. Add .transaction and .animation to Rectangle frame
    # We must be careful not to duplicate if it already exists (like in BluetoothOverlayView)
    
    # First, let's normalize by removing the existing .animation(progressAnimation, value: animatedProgress) in Bluetooth
    content = content.replace("                            .animation(progressAnimation, value: animatedProgress)\n", "")
    content = content.replace("                            .transaction { $0.animation = nil }\n", "")
    
    # Now replace .frame(...) with the block
    content = content.replace(
        "                            .frame(width: trackWidth * animatedProgress)",
        "                            .frame(width: trackWidth * animatedProgress)\n                            .transaction { $0.animation = nil }\n                            .animation(progressAnimation, value: animatedProgress)"
    )

    # 3. Replace withAnimation blocks in onChange(of: isHovering)
    content = re.sub(
        r'withAnimation\(\.easeOut\(duration: ([\d\.]+)\)\) \{ animatedProgress = 1\.0 \}',
        r'progressAnimation = .easeOut(duration: \1)\n                    animatedProgress = 1.0',
        content
    )
    content = re.sub(
        r'withAnimation\(\.linear\(duration: ([\d\.]+)\)\) \{ animatedProgress = 0\.0 \}',
        r'progressAnimation = .linear(duration: \1)\n                    animatedProgress = 0.0',
        content
    )

    # 4. Replace withAnimation blocks in onAppear
    # .onAppear { animatedProgress = 1.0; if !isPreview { withAnimation(.linear(duration: X)) { animatedProgress = 0.0 } } }
    # This might span multiple lines
    def onAppear_replacement(match):
        duration = match.group(1)
        return f'progressAnimation = .linear(duration: {duration})\n                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {{\n                    animatedProgress = 0.0\n                }}'
    
    content = re.sub(
        r'withAnimation\(\.linear\(duration: ([\d\.]+)\)\) \{\n\s*animatedProgress = 0\.0\n\s*\}',
        onAppear_replacement,
        content
    )

    if content != original_content:
        with open(filepath, "w") as f:
            f.write(content)
        print(f"Updated {filename}")
