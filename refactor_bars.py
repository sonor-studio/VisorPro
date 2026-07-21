import os
import re

directory = "/Users/macbook/Desktop/Dev/Visor/Visor"

for filename in os.listdir(directory):
    if not filename.endswith(".swift") or filename == "TimeoutProgressBar.swift":
        continue
    filepath = os.path.join(directory, filename)
    with open(filepath, "r") as f:
        content = f.read()

    original_content = content

    # 1. Remove state variables
    content = re.sub(r'\s*@State private var animatedProgress: CGFloat = 1\.0\n', '\n', content)
    content = re.sub(r'\s*@State private var progressAnimation: Animation\? = .*?\n', '\n', content)

    # 2. Replace Rectangle block
    content = re.sub(
        r'Rectangle\(\)\n\s*\.frame\(width: trackWidth \* animatedProgress\)\n\s*\.animation\(progressAnimation, value: animatedProgress\)',
        r'TimeoutProgressBar(trackWidth: trackWidth, isHovering: isHovering, initialDuration: 3.5, hoverOutDuration: 2.5)',
        content
    )
    
    # 3. We will wipe the onChange block that modifies progressAnimation
    content = re.sub(
        r'\s*\.onChange\(of: isHovering\) \{ hovering in\n\s*if !isPreview \{\n\s*progressAnimation = .*?\n\s*animatedProgress = .*?\n\s*\}\n\s*\}',
        '',
        content
    )
    
    # 4. We will wipe the onAppear block that modifies animatedProgress
    content = re.sub(
        r'\s*\.onAppear \{\n\s*animatedProgress = 1\.0\n\s*if !isPreview \{\n\s*progressAnimation = .*?\n\s*DispatchQueue\.main\.asyncAfter.*?\{\n\s*animatedProgress = 0\.0\n\s*\}\n\s*\}\n\s*\}',
        '',
        content
    )

    if content != original_content:
        with open(filepath, "w") as f:
            f.write(content)
        print(f"Updated {filename}")
