import re

with open("release.sh", "r") as f:
    lines = f.readlines()

# Goal 1: Fix declare -A
for i, line in enumerate(lines):
    if "declare -A PROJ_MAP" in line:
        lines[i] = "        declare -a PROJ_MAP\n"

# Goal 2: Fix App Type Selection Logic (lines 264 to 311 approximately)
start_app = -1
end_app = -1
for i, line in enumerate(lines):
    if "if [ ${#SELECTED_TARGETS[@]} -eq 1 ]; then" in line:
        start_app = i
    if "export FILTERED_TYPE=\"\"" in line and "fi" in lines[i+1]:
        end_app = i + 1
        break

app_type_replacement = """        for TARGET_ID in "${SELECTED_TARGETS[@]}"; do
            # Cek apakah project memiliki lebih dari satu Type (Tanyakan sebelum pilih aksi)
            if command -v jq >/dev/null 2>&1 && jq -e ".\\\"$TARGET_ID\\\"" "$PROJECT_FILE" >/dev/null 2>&1; then
                INTERACTIVE_TYPE=$(jq -r ".\\\"$TARGET_ID\\\".Project.Type // empty" "$PROJECT_FILE")
                if [[ "$INTERACTIVE_TYPE" == *","* ]]; then
                    tput clear
                    IFS=',' read -ra ALL_TYPES <<< "$INTERACTIVE_TYPE"
                    echo "============================================================"
                    echo "🗂️ PROJECT INI MEMILIKI BEBERAPA TIPE APLIKASI: $TARGET_ID"
                    echo "============================================================"
                    echo "1) Full (Semua Tipe: $INTERACTIVE_TYPE)"
                    
                    idx=2
                    for t in "${ALL_TYPES[@]}"; do
                        t_clean=$(echo "$t" | xargs)
                        echo "$idx) $t_clean"
                        ((idx++))
                    done
                    echo "------------------------------------------------------------"
                    echo -n "Pilih tipe yang ingin dieksekusi untuk $TARGET_ID (pisahkan spasi, misal: 2 3): "
                    read -r type_choice

                    if [[ "$type_choice" != "1" && -n "$type_choice" ]]; then
                        NEW_TYPE=""
                        choices=$(echo "$type_choice" | tr ',' ' ' | xargs)
                        for c in $choices; do
                            if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 2 ] && [ "$c" -lt "$idx" ]; then
                                selected_idx=$((c - 2))
                                t_clean=$(echo "${ALL_TYPES[$selected_idx]}" | xargs)
                                if [ -n "$NEW_TYPE" ]; then
                                    NEW_TYPE="${NEW_TYPE}, ${t_clean}"
                                else
                                    NEW_TYPE="${t_clean}"
                                fi
                            fi
                        done
                        
                        if [ -n "$NEW_TYPE" ]; then
                            # Dynamic variable export for this target
                            clean_target_id=$(echo "$TARGET_ID" | tr '-' '_')
                            eval "export FILTERED_TYPE_${clean_target_id}=\\"\\$NEW_TYPE\\""
                        fi
                    fi
                fi
            fi
        done
        tput clear
"""

if start_app != -1 and end_app != -1:
    lines = lines[:start_app] + [app_type_replacement] + lines[end_app+1:]


# Goal 3: Fix extraction inside the execution loop
for i, line in enumerate(lines):
    if "if [ -z \"$FILTERED_TYPE\" ]; then" in line:
        lines[i] = "                            clean_target_id=$(echo \"$TARGET_ID\" | tr '-' '_')\n                            dynamic_type=$(eval echo \"\\$FILTERED_TYPE_${clean_target_id}\")\n                            if [ -z \"$dynamic_type\" ]; then\n"
    elif "ACTIVE_TYPES=\"$FILTERED_TYPE\"" in line:
        lines[i] = "                                ACTIVE_TYPES=\"$dynamic_type\"\n"


with open("release.sh", "w") as f:
    f.writelines(lines)
    
print("App type logic replaced!")
