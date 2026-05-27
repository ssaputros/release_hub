import re

with open("release.sh", "r") as f:
    lines = f.readlines()

# Goal 1: Replace TUI from line 200 (local_input="") down to line 290 (tput cnorm)
start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if "local_input=\"\"" in line and start_idx == -1:
        start_idx = i
    if "tput cnorm" in line and start_idx != -1:
        end_idx = i
        break

tui_replacement = """        # Ekstrak data project HANYA SEKALI
        projects_data=$(jq -r 'to_entries | .[] | "\\(.key)|\\(.value.Project["Project Name"])"' "$PROJECT_FILE")
        
        echo "============================================================"
        echo "📋 DAFTAR PROJECT"
        echo "============================================================"
        
        # Simpan keys dalam array map index -> project_id
        declare -A PROJ_MAP
        no=1
        while IFS="|" read -r pid pname; do
            printf "%-3s %-20s %s\\n" "$no)" "$pid" "$pname"
            PROJ_MAP[$no]="$pid"
            ((no++))
        done <<< "$projects_data"
        
        echo "------------------------------------------------------------"
        echo -n "Masukkan nomor project (pisahkan dengan spasi/koma, misal: 2 4 5) atau 'all': "
        read -r project_input
        
        SELECTED_TARGETS=()
        
        if [[ "$project_input" == "all" ]]; then
            for idx in $(seq 1 $((no-1))); do
                SELECTED_TARGETS+=("${PROJ_MAP[$idx]}")
            done
        else
            clean_proj_input=$(echo "$project_input" | tr ',' ' ')
            for c in $clean_proj_input; do
                if [ -n "${PROJ_MAP[$c]}" ]; then
                    SELECTED_TARGETS+=("${PROJ_MAP[$c]}")
                fi
            done
        fi
        
        if [ ${#SELECTED_TARGETS[@]} -eq 0 ]; then
            echo "❌ Tidak ada project yang dipilih."
            exit 1
        fi
"""

if start_idx != -1 and end_idx != -1:
    lines = lines[:start_idx] + [tui_replacement] + lines[end_idx+1:]

# Goal 2: Modify the legacy mappings
for i, line in enumerate(lines):
    if "TARGET_ID=\"${UPLOAD_ONLY_ID}\"" in line:
        lines[i] = "    SELECTED_TARGETS=(\"${UPLOAD_ONLY_ID}\")\n"
    if "TARGET_ID=\"${BUILD_ONLY_ID}\"" in line:
        lines[i] = "    SELECTED_TARGETS=(\"${BUILD_ONLY_ID}\")\n"
    if "TARGET_ID=\"$RUN_ID\"" in line:
        lines[i] = "    SELECTED_TARGETS=(\"$RUN_ID\")\n"

# Goal 3: App Type Selection. Replace TARGET_ID="$local_input" and interactive prompt
start_app_type = -1
end_app_type = -1
for i, line in enumerate(lines):
    if "if [ -n \"$local_input\" ]; then" in line: # This is dead code now, local_input is removed. Let's find "if [ \"$UPLOAD_ONLY_MODE\" = true ]; then"
        pass
    if "if [ \"$UPLOAD_ONLY_MODE\" = true ]; then" in line and "TARGET_ID=\"$local_input\"" in lines[i+1]:
        start_app_type = i - 1
        
for i, line in enumerate(lines):
    if "tput clear" in line and i > start_app_type and start_app_type != -1:
        # Wait, the end of the app type selection is around line 363 (fi \n fi \n tput clear \n fi \n fi)
        # Let's find "echo \"🛠️ PILIH AKSI UNTUK: $local_input\""
        pass
    if "echo \"🛠️ PILIH AKSI UNTUK: " in line:
        end_app_type = i - 2
        break

app_type_replacement = """
        if [ ${#SELECTED_TARGETS[@]} -eq 1 ]; then
            TARGET_ID="${SELECTED_TARGETS[0]}"
            tput clear
            # Cek apakah project memiliki lebih dari satu Type (Tanyakan sebelum pilih aksi)
            if command -v jq >/dev/null 2>&1 && jq -e ".\\\"$TARGET_ID\\\"" "$PROJECT_FILE" >/dev/null 2>&1; then
                INTERACTIVE_TYPE=$(jq -r ".\\\"$TARGET_ID\\\".Project.Type // empty" "$PROJECT_FILE")
                if [[ "$INTERACTIVE_TYPE" == *","* ]]; then
                    IFS=',' read -ra ALL_TYPES <<< "$INTERACTIVE_TYPE"
                    echo "============================================================"
                    echo "🗂️ PROJECT INI MEMILIKI BEBERAPA TIPE APLIKASI"
                    echo "============================================================"
                    echo "1) Full (Semua Tipe: $INTERACTIVE_TYPE)"
                    
                    idx=2
                    for t in "${ALL_TYPES[@]}"; do
                        t_clean=$(echo "$t" | xargs)
                        echo "$idx) $t_clean"
                        ((idx++))
                    done
                    echo "------------------------------------------------------------"
                    echo -n "Pilih tipe yang ingin dieksekusi (bisa lebih dari satu, pisahkan spasi, misal: 2 3): "
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
                            export FILTERED_TYPE="$NEW_TYPE"
                        fi
                    fi
                fi
                tput clear
            fi
        else
            # Multiple targets selected, skip interactive type choice and assume Full
            export FILTERED_TYPE=""
        fi
"""

if start_app_type != -1 and end_app_type != -1:
    lines = lines[:start_app_type] + [app_type_replacement] + lines[end_app_type+1:]

# Goal 4: Update 'echo "🛠️ PILIH AKSI UNTUK: $local_input"'
for i, line in enumerate(lines):
    if "echo \"🛠️ PILIH AKSI UNTUK: " in line:
        lines[i] = "                echo \"🛠️ PILIH AKSI UNTUK: ${#SELECTED_TARGETS[@]} Project(s) Terpilih\"\n"

# Goal 5: Wrap Execution logic in loop
start_exec = -1
end_exec = -1
for i, line in enumerate(lines):
    if "if [[ \"$clean_choice\" == *\" 3 \"* ]] || [[ \"$clean_choice\" == *\" 4 \"* ]]" in line and "echo \"🤖 MENYIAPKAN AUTOMASI" in lines[i+2]:
        start_exec = i
    if "exit 0" in line and "done" in lines[i-1]:
        end_exec = i + 1

if start_exec != -1 and end_exec != -1:
    # Wrap lines between start_exec and end_exec inside a target loop
    new_exec_block = []
    
    # Put playwright setup outside target loop
    new_exec_block.append(lines[start_exec]) # if [[ "$clean_choice" ...
    new_exec_block.append(lines[start_exec+1]) # echo
    new_exec_block.append(lines[start_exec+2]) # echo "Menyiapkan automasi..."
    new_exec_block.append(lines[start_exec+3]) # echo
    new_exec_block.append(lines[start_exec+4]) # # Hanya install...
    new_exec_block.append(lines[start_exec+5]) # if playwright..
    new_exec_block.append(lines[start_exec+6]) # cd
    new_exec_block.append(lines[start_exec+7]) # if ! -d node_modules
    new_exec_block.append(lines[start_exec+8]) # echo
    new_exec_block.append(lines[start_exec+9]) # npm install
    new_exec_block.append(lines[start_exec+10]) # npx playwright
    new_exec_block.append(lines[start_exec+11]) # fi
    new_exec_block.append(lines[start_exec+12]) # if ! chrome_profile
    new_exec_block.append(lines[start_exec+13]) # echo
    new_exec_block.append(lines[start_exec+14]) # npm run auth
    new_exec_block.append(lines[start_exec+15]) # fi
    new_exec_block.append(lines[start_exec+16]) # fi
    new_exec_block.append("                        cd \"${SCRIPT_DIR}\" || exit 1\n")
    new_exec_block.append("\n")
    new_exec_block.append("                        for TARGET_ID in \"${SELECTED_TARGETS[@]}\"; do\n")
    new_exec_block.append("                            echo \"============================================================\"\n")
    new_exec_block.append("                            echo \"🚀 MEMPROSES PROJECT: $TARGET_ID\"\n")
    new_exec_block.append("                            echo \"============================================================\"\n")
    
    # Process the rest of the block inside the loop
    rest_of_block = lines[start_exec+17:end_exec-1]
    
    # we need to remove `cd "${SCRIPT_DIR}" || exit 1` from the middle since we hoisted it
    clean_rest = []
    skip_next = False
    for r in rest_of_block:
        if skip_next:
            skip_next = False
            continue
        if "# Kembali ke direktori utama" in r:
            skip_next = True # skip the next 'cd' line
            continue
        if "exit 0" in r:
            continue # remove exit 0
        clean_rest.append("    " + r)
        
    new_exec_block.extend(clean_rest)
    new_exec_block.append("                        done\n")
    new_exec_block.append("                        exit 0\n")
    new_exec_block.append("                    fi\n")
    
    lines = lines[:start_exec] + new_exec_block + lines[end_exec+1:]

with open("release.sh", "w") as f:
    f.writelines(lines)
    
print("SUCCESS")
