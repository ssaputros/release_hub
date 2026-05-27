import re

with open("release.sh", "r") as f:
    lines = f.readlines()

# Goal 1: Add option 21 to the menu
for i, line in enumerate(lines):
    if "echo \"12) Update Play Console Dashboard ID\"" in line:
        lines.insert(i+1, "                echo \"21) Upload AAB ke Play Store\"\n")
        break

# Goal 2: Add 21 to the condition logic
for i, line in enumerate(lines):
    if "if [[ \"$clean_choice\" == *\" 3 \"* ]]" in line and "*\" 20 \"*" in line:
        # It's the big if condition
        lines[i] = line.replace('*" 20 "* ]]; then', '*" 20 "* ]] || [[ "$clean_choice" == *" 21 "* ]]; then')
        break

# Goal 3: Add the execution of option 21 inside the fastlane loop
for i, line in enumerate(lines):
    if "if [[ \"$clean_choice\" == *\" 20 \"* ]]; then" in line:
        opt_21_code = """
                                if [[ "$clean_choice" == *" 21 "* ]]; then
                                    ruby "${SCRIPT_DIR}/scripts/submit_playstore_version.rb" "$TARGET_ID" "$current_type" || echo "❌ submit_playstore_version.rb gagal dijalankan."
                                fi
"""
        lines.insert(i, opt_21_code)
        break

# Goal 4: Wrap the second half in a loop
start_idx = -1
for i, line in enumerate(lines):
    if "if [ -n \"$TARGET_ID\" ]; then" in line and "PROJECT_FILE" in "".join(lines[i:i+5]):
        start_idx = i
        break

if start_idx != -1:
    # Find the end of the file or where the last logic block ends
    # The last logic block ends before any functions or just at EOF
    # Let's wrap from start_idx to the end of the file
    
    # We will replace `if [ -n "$TARGET_ID" ]; then` with `for TARGET_ID in "${SELECTED_TARGETS[@]}"; do`
    # Then we add `done` at the bottom.
    lines[start_idx] = "for TARGET_ID in \"${SELECTED_TARGETS[@]}\"; do\n"
    
    # Since it was an `if`, we need to find the matching `fi`.
    # Let's just append `done` at the end and remove the last `fi`
    
    # Wait, there's an `else` branch for `if command -v jq >/dev/null 2>&1 && jq -e ".\"$TARGET_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then`!
    # No, wait. 
    # Let's look at the structure:
    # if [ -n "$TARGET_ID" ]; then
    #     if command -v jq ...
    #         ...
    #     else
    #         # Generate ID ...
    #     fi
    #     
    #     if [ "$OPT_SETUP" = true ]; then ... fi
    #     if [ "$OPT_BUILD" = true ]; then ... fi
    #     if [ "$OPT_UPLOAD_DRIVE" = true ]; then ... fi
    #     if [ "$OPT_UPLOAD_TESTFLIGHT" = true ]; then ... fi
    # fi
    
    # I need to find the `fi` that closes `if [ -n "$TARGET_ID" ]; then`. It's likely the very last `fi` in the file.
    last_fi_idx = -1
    for i in range(len(lines)-1, -1, -1):
        if lines[i].strip() == "fi":
            last_fi_idx = i
            break
            
    if last_fi_idx != -1:
        lines[last_fi_idx] = "done\n"

with open("release.sh", "w") as f:
    f.writelines(lines)
    
print("Successfully refactored release.sh")
