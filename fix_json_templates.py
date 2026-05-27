import re

files_to_fix = ["release.sh", "new_release_bottom.sh"]

for file_name in files_to_fix:
    with open(file_name, "r") as f:
        content = f.read()
    
    # We need to insert the BRANCH_JSON generation right after `BRANCH="$ID"`
    branch_json_code = """
    # Generate Branch JSON object based on TYPE
    BRANCH_JSON="{"
    IFS=',' read -ra ADDR <<< "$TYPE"
    for i in "${!ADDR[@]}"; do
        type_clean=$(echo "${ADDR[$i]}" | xargs)
        BRANCH_JSON+="\\\"$type_clean\\\": \\\"$BRANCH\\\""
        if [ $i -lt $((${#ADDR[@]}-1)) ]; then
            BRANCH_JSON+=", "
        fi
    done
    BRANCH_JSON+="}"
"""
    
    # Replace --arg branch "$BRANCH" \ with --argjson branch "$BRANCH_JSON" \
    content = content.replace('--arg branch "$BRANCH" \\', '--argjson branch "$BRANCH_JSON" \\')
    
    # Find `BRANCH="$ID"` and append the BRANCH_JSON logic
    if "BRANCH=\"$ID\"" in content:
        # Avoid duplicating if already there
        if "BRANCH_JSON=" not in content:
            content = content.replace('BRANCH="$ID"', 'BRANCH="$ID"\n' + branch_json_code)

    with open(file_name, "w") as f:
        f.write(content)

print("Updated JSON templates in release.sh and new_release_bottom.sh")
