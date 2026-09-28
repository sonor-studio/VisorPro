import sys
import re

source_file = "/Users/macbook/Desktop/Dev/VisorPro/VisorPro/Managers/MediaKeyManager.swift"
dest_file = "/Users/macbook/Desktop/Dev/VisorPro/VisorPro/Managers/MediaKeySubManagers/MediaKeyManager+Indicators.swift"

def extract_function(content, func_name):
    pattern = r"(\s*)func " + func_name + r"\b"
    match = re.search(pattern, content)
    if not match:
        return content, None
    
    start_idx = match.start()
    
    brace_count = 0
    in_string = False
    escape = False
    
    idx = start_idx
    first_brace_found = False
    while idx < len(content):
        c = content[idx]
        if escape:
            escape = False
        elif c == '\\':
            escape = True
        elif c == '"':
            in_string = not in_string
        elif not in_string:
            if c == '{':
                first_brace_found = True
                brace_count += 1
            elif c == '}':
                brace_count -= 1
                if first_brace_found and brace_count == 0:
                    end_idx = idx + 1
                    func_body = content[start_idx:end_idx]
                    
                    # Look backwards to include comments or decorators if any
                    # Let's just grab what we have from func...
                    
                    new_content = content[:start_idx] + content[end_idx:]
                    return new_content, func_body
        idx += 1
        
    return content, None

with open(source_file, "r") as f:
    content = f.read()

funcs_to_extract = [
    "triggerVolumeIndicator",
    "triggerBrightnessIndicator",
    "triggerKeyboardBrightnessIndicator",
    "triggerCapsLockIndicator",
    "triggerThemeIndicator",
    "triggerLanguageIndicator",
    "triggerRamOverlay"
]

extracted = []
for func in funcs_to_extract:
    content, func_body = extract_function(content, func)
    if func_body:
        extracted.append(func_body)
    else:
        print(f"Could not find {func}")

if extracted:
    with open(source_file, "w") as f:
        f.write(content)
        
    with open(dest_file, "r") as f:
        dest_content = f.read()
        
    last_brace_idx = dest_content.rfind('}')
    if last_brace_idx != -1:
        new_dest_content = dest_content[:last_brace_idx] + "\n" + "\n\n".join(extracted) + "\n" + dest_content[last_brace_idx:]
        with open(dest_file, "w") as f:
            f.write(new_dest_content)
    else:
        with open(dest_file, "a") as f:
            f.write("\n\n" + "\n\n".join(extracted))

print("Done")
