import re

with open('release.sh', 'r') as f:
    content = f.read()

# 1. Ganti menu teks
old_menu = """                echo "============================================================"
                echo "🛠️ PILIH AKSI UNTUK: ${#SELECTED_TARGETS[@]} Project(s) Terpilih"
                echo "============================================================"
                echo " 1) Full (Semua proses Utama)"
                echo " 2) Setup Konfigurasi"
                echo " 3) Bump Version"
                echo " 5) Upload APK & IPA ke Google Drive"
                echo " 6) Build APK & AAB"
                echo " 7) Create Playstore App"
                echo " 8) Setup Playstore App Information"
                echo " 9) Setup Store Listing"
                echo "10) Push Playstore Listing"
                                echo "12) Update Play Console Dashboard ID"
                echo "21) Upload AAB ke Play Store"
                echo "22) Build AAB Saja"
                echo "13) Build IPA"
                echo "14) Upload TestFlight"
                echo "15) Submit TestFlight (Lewati Upload IPA)"
                echo "16) Setup App Store Info"
                echo "17) Push App Store Metadata"
                echo "19) Request Unlisted App Distribution"
                echo "20) Submit for App Review"
                echo "------------------------------------------------------------"
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 6 9 13): "
"""

new_menu = """                echo "============================================================"
                echo "🛠️ PILIH AKSI UNTUK: ${#SELECTED_TARGETS[@]} Project(s) Terpilih"
                echo "============================================================"
                echo " 1) Setup Konfigurasi"
                echo " 2) Bump Version"
                echo " 3) Pod Install"
                echo " 4) Full Deploy iOS (Otomatis jalankan 5-12)"
                echo " 5) Create Appstore"
                echo " 6) Push Metadata (App Store)"
                echo " 7) Complete Appstore Info"
                echo " 8) Build IPA"
                echo " 9) Upload IPA (Ke Google Drive)"
                echo "10) Submit Testflight"
                echo "11) Submit Appstore Review"
                echo "12) Request Unlisted Distribution"
                echo "13) Full Deploy Android (Otomatis jalankan 14-21)"
                echo "14) Create Playstore"
                echo "15) Setup Playstore Info"
                echo "16) Upload Playstore Listing"
                echo "17) Build APK"
                echo "18) Upload to Google Drive (APK)"
                echo "19) Build AAB"
                echo "20) Upload Playstore (AAB)"
                echo "21) Submit Playstore (Playwright UI)"
                echo "22) Update Play Console Dashboard ID"
                echo "------------------------------------------------------------"
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 1 19 20): "
"""

if old_menu in content:
    content = content.replace(old_menu, new_menu)
else:
    # If the old menu string doesn't match perfectly, we can use regex to replace the entire block
    pattern = re.compile(r'echo "============================================================"\n\s*echo "🛠️ PILIH AKSI UNTUK:.*?\n\s*echo -n "Pilihan Anda \(pisahkan dengan spasi/koma.*?: "', re.DOTALL)
    content = pattern.sub(new_menu, content)


# 2. Modify execute_action to map to the new numbers
# We need to completely rewrite the body of execute_action
# Since the body is very large, I'll replace everything from `execute_action() {` to `}`

execute_action_new = """execute_action() {
    local action="$1"
    
    for TARGET_ID in "${SELECTED_TARGETS[@]}"; do
        if ! command -v jq >/dev/null 2>&1 || ! jq -e ".\\\"$TARGET_ID\\\"" "$PROJECT_FILE" >/dev/null 2>&1; then
            echo "❌ Error: Project dengan ID '$TARGET_ID' tidak ditemukan di projects.json."
            continue
        fi
        
        echo "============================================================"
        echo "🚀 MEMPROSES PROJECT: $TARGET_ID"
        echo "============================================================"
        
        # Eksekusi aksi yang berada di level target (tidak butuh looping per tipe aplikasi)
        case "$action" in
            5) 
                if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then
                    bash "${SCRIPT_DIR}/init_appstore.sh" "$TARGET_ID" || { echo "❌ Proses init appstore gagal!"; exit 1; }
                fi
                continue
                ;;
            14) 
                if node "${SCRIPT_DIR}/automation/create_app.js" "$TARGET_ID"; then
                    echo "✅ create_app.js berhasil"
                else
                    echo "❌ create_app.js gagal dijalankan."
                fi
                continue
                ;;
            15) 
                node "${SCRIPT_DIR}/automation/runner_app_info.js" "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                continue
                ;;
            21) 
                node "${SCRIPT_DIR}/automation/submit_playstore.js" "$TARGET_ID" || echo "❌ submit_playstore.js gagal dijalankan."
                continue
                ;;
            22) 
                node "${SCRIPT_DIR}/automation/update_dashboard_id.js" "$TARGET_ID" || echo "❌ update_dashboard_id.js gagal dijalankan."
                continue
                ;;
        esac
        
        # Dapatkan list tipe aplikasi untuk project ini
        clean_target_id=$(echo "$TARGET_ID" | tr '-' '_')
        dynamic_type=$(eval echo "\\$FILTERED_TYPE_${clean_target_id}")
        if [ -z "$dynamic_type" ]; then
            ACTIVE_TYPES=$(jq -r ".\\\"$TARGET_ID\\\".Project.Type // empty" "$PROJECT_FILE")
        else
            ACTIVE_TYPES="$dynamic_type"
        fi
        IFS=',' read -ra ACTIVE_TYPES_ARR <<< "$ACTIVE_TYPES"
        
        for current_type in "${ACTIVE_TYPES_ARR[@]}"; do
            type_clean=$(echo "$current_type" | xargs)
            type_slug=$(echo "$type_clean" | tr 'A-Z' 'a-z' | tr ' ' '_')
            
            # Ambil META informasi untuk project dan tipe ini
            CONFIG_FILE="${SCRIPT_DIR}/config.json"
            META_JSON=$(node "${SCRIPT_DIR}/scripts/app_meta.js" "$TARGET_ID" "" "$type_clean" "$CONFIG_FILE")
            APP_PACKAGE_NAME=$(echo "$META_JSON" | jq -r '.packageName')
            APP_NAME=$(echo "$META_JSON" | jq -r '.appName')
            PRIMARY_TYPE=$(echo "$META_JSON" | jq -r '.primaryType')
            PROJECT_NAME=$(jq -r ".\\\"$TARGET_ID\\\".Project.\\\"Project Name\\\" // empty" "$PROJECT_FILE")
            TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT_NAME}/${type_clean}"
            
            echo "============================================================"
            echo "⚙️ MENJALANKAN OPSI $action UNTUK: $type_clean ($APP_NAME)"
            echo "============================================================"
            
            case "$action" in
                1) # Setup Konfigurasi
                   bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }
                   script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
                   if [ -f "$script_file" ]; then
                       REGION=$(jq -r ".\\\"$TARGET_ID\\\".Project.Region // empty" "$PROJECT_FILE")
                       BASE_URL=$(jq -r ".\\\"$TARGET_ID\\\".Project.\\\"Base URL\\\" // empty" "$PROJECT_FILE")
                       DATABASE=$(jq -r ".\\\"$TARGET_ID\\\".Project.Database // empty" "$PROJECT_FILE")
                       bash "$script_file" "$TARGET_ID" "$REGION" "$APP_NAME" "$type_clean" "$BASE_URL" "$DATABASE" "$APP_PACKAGE_NAME" || { echo "❌ Proses setup $type_clean gagal!"; exit 1; }
                   fi
                   ;;
                2) ruby "${SCRIPT_DIR}/scripts/bump_version.rb" "$TARGET_ID" "$type_clean" || echo "❌ bump_version.rb gagal dijalankan." ;;
                3) # Pod Install
                   echo "📦 Menjalankan pod install untuk iOS..."
                   cd "${SCRIPT_DIR}/ios" || { echo "❌ Folder ios tidak ditemukan!"; exit 1; }
                   rm -f Podfile.lock
                   pod install || { echo "❌ pod install gagal!"; exit 1; }
                   cd "${SCRIPT_DIR}" || exit 1
                   ;;
                6) ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ push_appstore_metadata.rb gagal dijalankan." ;;
                7) ruby "${SCRIPT_DIR}/scripts/setup_appstore_info.rb" "$TARGET_ID" "$type_clean" || echo "❌ setup_appstore_info.rb gagal dijalankan." ;;
                8) # Build IPA
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_IPA=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                9) # Upload IPA to Google Drive
                   echo "🚀 MENGUNGGAH IPA KE GOOGLE DRIVE: $APP_NAME"
                   # Wait, earlier I only had upload_drive taking apk? The helper function finds *.apk.
                   # Let's override it or create upload_drive_ipa? 
                   # Wait, the user said "upload ipa", I will assume they meant Testflight OR GDrive. 
                   # If they meant Gdrive, I need a helper for IPA. Let's just inline it here for simplicity.
                   GDRIVE_FOLDER_ID=""
                   if [ -f "$CONFIG_FILE" ]; then GDRIVE_FOLDER_ID=$(jq -r ".types[\\\"$PRIMARY_TYPE\\\"].gdrive_folder_id // empty" "$CONFIG_FILE"); fi
                   ENV_FILE="${SCRIPT_DIR}/.env"
                   GDRIVE_CRED_PATH=""
                   if [ -f "$ENV_FILE" ]; then
                       RAW_CRED_PATH=$(grep '^GDRIVE_CREDENTIALS_PATH=' "$ENV_FILE" | cut -d '"' -f 2)
                       if [ -n "$RAW_CRED_PATH" ]; then GDRIVE_CRED_PATH="${SCRIPT_DIR}/${RAW_CRED_PATH}"; fi
                   fi
                   if [ -z "$GDRIVE_FOLDER_ID" ] || [ -z "$GDRIVE_CRED_PATH" ]; then echo "❌ Error: Konfigurasi GDrive tidak lengkap."; exit 1; fi
                   
                   LATEST_IPA=$(find "$TARGET_DIR" -name "*.ipa" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
                   if [ -n "$LATEST_IPA" ]; then
                       python3 "${SCRIPT_DIR}/scripts/upload_to_gdrive.py" "$LATEST_IPA" "$GDRIVE_FOLDER_ID" "$GDRIVE_CRED_PATH" "$PROJECT_NAME" "$APP_NAME"
                   else
                       echo "⚠️ File IPA tidak ditemukan di $TARGET_DIR"
                       exit 1
                   fi
                   ;;
                10) # Submit TestFlight
                   echo "🍎 MENGUNGGAH KE TESTFLIGHT: $APP_NAME"
                   # By default, upload_testflight helper does not skip upload unless SKIP_UPLOAD is set
                   upload_testflight "$TARGET_DIR" "$TARGET_ID" "$APP_PACKAGE_NAME" "$APP_NAME" "$type_clean"
                   ;;
                11) ruby "${SCRIPT_DIR}/scripts/submit_appstore_version.rb" "$TARGET_ID" "$type_clean" || echo "❌ submit_appstore_version.rb gagal dijalankan." ;;
                12) ruby "${SCRIPT_DIR}/scripts/request_unlisted_app.rb" "$TARGET_ID" "$type_clean" || echo "❌ request_unlisted_app.rb gagal dijalankan." ;;
                16) # Upload Playstore Listing
                   echo "============================================================"
                   echo "🛠️ PILIH METODE SETUP STORE LISTING"
                   echo "============================================================"
                   echo "1) Fastlane API (Direct upload, cepat & tanpa browser)"
                   echo "2) Playwright Browser (Semi-otomatis lewat UI browser)"
                   echo "------------------------------------------------------------"
                   echo -n "Pilihan Anda (default: 1): "
                   read -r method_choice
                   if [[ "$method_choice" == "2" ]]; then
                       node "${SCRIPT_DIR}/automation/runner_store_listing.js" "$TARGET_ID" || echo "❌ runner_store_listing.js gagal dijalankan."
                   else
                       ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$type_clean" || echo "❌ update_store_listing.rb gagal dijalankan."
                   fi
                   ;;
                17) # Build APK
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_APK=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                18) # Upload to Google Drive
                   echo "🚀 MENGUNGGAH APK KE GOOGLE DRIVE: $APP_NAME"
                   upload_drive "$TARGET_DIR" "$PRIMARY_TYPE" "$PROJECT_NAME" "$APP_NAME"
                   ;;
                19) # Build AAB
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_AAB=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                20) # Upload Play Store
                   ruby "${SCRIPT_DIR}/scripts/submit_playstore_version.rb" "$TARGET_ID" "$type_clean" || { echo "❌ Proses upload Play Store gagal!"; exit 1; }
                   ;;
            esac
        done
    done
}
"""
pattern_execute = re.compile(r'execute_action\(\) \{.*?\n\}\n', re.DOTALL)
content = pattern_execute.sub(execute_action_new + '\n', content)

# 3. Add handling for Meta Options 4 and 13
# We need to change the loop that processes ACTION_ARRAY
old_loop = """for CURRENT_ACTION in "${ACTION_ARRAY[@]}"; do
    if [ -z "$CURRENT_ACTION" ]; then
        continue
    fi
    
    if [ "$CURRENT_ACTION" = "1" ]; then
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: 1 (FULL PROSES)"
        echo "============================================================"
        echo "Menjalankan opsi penuh (1) akan diurai menjadi: 2 (Setup), 6 (Build APK & AAB), 13 (Build IPA), 5 (Upload GDrive), 14 (Upload TestFlight)"
        execute_action "2"
        execute_action "6"
        execute_action "13"
        execute_action "5"
        execute_action "14"
    else
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: $CURRENT_ACTION"
        echo "============================================================"
        execute_action "$CURRENT_ACTION"
    fi
done"""

new_loop = """for CURRENT_ACTION in "${ACTION_ARRAY[@]}"; do
    if [ -z "$CURRENT_ACTION" ]; then
        continue
    fi
    
    if [ "$CURRENT_ACTION" = "4" ]; then
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: 4 (FULL DEPLOY iOS)"
        echo "============================================================"
        for sub_action in 5 6 7 8 9 10 11 12; do
            execute_action "$sub_action"
        done
    elif [ "$CURRENT_ACTION" = "13" ]; then
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: 13 (FULL DEPLOY ANDROID)"
        echo "============================================================"
        for sub_action in 14 15 16 17 18 19 20 21; do
            execute_action "$sub_action"
        done
    else
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: $CURRENT_ACTION"
        echo "============================================================"
        execute_action "$CURRENT_ACTION"
    fi
done"""

if old_loop in content:
    content = content.replace(old_loop, new_loop)
else:
    pattern_loop = re.compile(r'for CURRENT_ACTION in "\$\{@ACTION_ARRAY.*done', re.DOTALL)
    # just brute force replace since we control the file
    pass # Wait, if it doesn't match perfectly, let's find it.
    
# Manual replace for the loop
pattern_loop = re.compile(r'for CURRENT_ACTION in "\$\{ACTION_ARRAY\[@\]\}"; do.*?done\n', re.DOTALL)
content = pattern_loop.sub(new_loop + '\n', content)

# 4. Modify the hardcoded PLAYWRIGHT dependency check
# Since we no longer have "4 7 8 9 12" as playwright dependencies for sure, wait, 4 is now "Full Deploy iOS" which doesn't need Playwright!
# 14 (Create Playstore), 15 (Setup Playstore info), 21 (Submit Playstore), 16 (Store Listing partially) need playwright.
old_dep_check = 'if [[ " ${ACTION_ARRAY[*]} " =~ " 7 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 8 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 9 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 12 " ]]; then'
new_dep_check = 'if [[ " ${ACTION_ARRAY[*]} " =~ " 13 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 14 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 15 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 16 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 21 " ]]; then'
content = content.replace(old_dep_check, new_dep_check)

with open('release.sh', 'w') as f:
    f.write(content)
