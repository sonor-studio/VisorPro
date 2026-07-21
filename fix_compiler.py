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
    
    # We will remove the assignments
    content = re.sub(r'\s*progressAnimation = .*?\n', '\n', content)
    content = re.sub(r'\s*animatedProgress = .*?\n', '\n', content)

    if content != original_content:
        with open(filepath, "w") as f:
            f.write(content)
        print(f"Updated {filename}")
