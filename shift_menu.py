import re

with open('release.sh', 'r') as f:
    content = f.read()

# 1. Update the printed menu
old_menu = """                echo " 1) Setup Konfigurasi"
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

new_menu = """                echo " 1) Setup Konfigurasi"
                echo " 2) Bump Version"
                echo " 3) Pod Install"
                echo " 4) Update Play Console Dashboard ID"
                echo " 5) Full Deploy iOS (Otomatis jalankan 6-13)"
                echo " 6) Create Appstore"
                echo " 7) Push Metadata (App Store)"
                echo " 8) Complete Appstore Info"
                echo " 9) Build IPA"
                echo "10) Upload IPA (Ke Google Drive)"
                echo "11) Submit Testflight"
                echo "12) Submit Appstore Review"
                echo "13) Request Unlisted Distribution"
                echo "14) Full Deploy Android (Otomatis jalankan 15-22)"
                echo "15) Create Playstore"
                echo "16) Setup Playstore Info"
                echo "17) Upload Playstore Listing"
                echo "18) Build APK"
                echo "19) Upload to Google Drive (APK)"
                echo "20) Build AAB"
                echo "21) Upload Playstore (AAB)"
                echo "22) Submit Playstore (Playwright UI)"
                echo "------------------------------------------------------------"
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 1 20 21): "
"""

content = content.replace(old_menu, new_menu)

# 2. Update the switch-case in execute_action()
# Old values: 5(appstore), 6(push_meta), 7(setup_info), 8(build_ipa), 9(upload_ipa_gdrive), 10(testflight), 11(review), 12(unlisted)
# 14(create_playstore), 15(setup_playstore_info), 16(upload_listing), 17(build_apk), 18(upload_gdrive), 19(build_aab), 20(submit_playstore_version), 21(submit_playstore playwright), 22(update_dashboard)

# Replace target-level case
old_target_case = """        case "$action" in
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
        esac"""

new_target_case = """        case "$action" in
            4) 
                node "${SCRIPT_DIR}/automation/update_dashboard_id.js" "$TARGET_ID" || echo "❌ update_dashboard_id.js gagal dijalankan."
                continue
                ;;
            6) 
                if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then
                    bash "${SCRIPT_DIR}/init_appstore.sh" "$TARGET_ID" || { echo "❌ Proses init appstore gagal!"; exit 1; }
                fi
                continue
                ;;
            15) 
                if node "${SCRIPT_DIR}/automation/create_app.js" "$TARGET_ID"; then
                    echo "✅ create_app.js berhasil"
                else
                    echo "❌ create_app.js gagal dijalankan."
                fi
                continue
                ;;
            16) 
                node "${SCRIPT_DIR}/automation/runner_app_info.js" "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                continue
                ;;
            22) 
                node "${SCRIPT_DIR}/automation/submit_playstore.js" "$TARGET_ID" || echo "❌ submit_playstore.js gagal dijalankan."
                continue
                ;;
        esac"""

content = content.replace(old_target_case, new_target_case)


# Replace type-level case numbers
# Note: we only increment numbers 6 to 12 (now 7 to 13) and 16 to 20 (now 17 to 21).
# Number 5 became 6 (in target_case)
# Old 6 becomes 7, 7 -> 8, 8 -> 9, 9 -> 10, 10 -> 11, 11 -> 12, 12 -> 13
# Old 16 becomes 17, 17 -> 18, 18 -> 19, 19 -> 20, 20 -> 21

# Let's replace the whole type-level case block carefully to avoid regex issues
old_type_case = """            case "$action" in
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
            esac"""

new_type_case = """            case "$action" in
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
                7) ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ push_appstore_metadata.rb gagal dijalankan." ;;
                8) ruby "${SCRIPT_DIR}/scripts/setup_appstore_info.rb" "$TARGET_ID" "$type_clean" || echo "❌ setup_appstore_info.rb gagal dijalankan." ;;
                9) # Build IPA
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_IPA=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                10) # Upload IPA to Google Drive
                   echo "🚀 MENGUNGGAH IPA KE GOOGLE DRIVE: $APP_NAME"
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
                11) # Submit TestFlight
                   echo "🍎 MENGUNGGAH KE TESTFLIGHT: $APP_NAME"
                   upload_testflight "$TARGET_DIR" "$TARGET_ID" "$APP_PACKAGE_NAME" "$APP_NAME" "$type_clean"
                   ;;
                12) ruby "${SCRIPT_DIR}/scripts/submit_appstore_version.rb" "$TARGET_ID" "$type_clean" || echo "❌ submit_appstore_version.rb gagal dijalankan." ;;
                13) ruby "${SCRIPT_DIR}/scripts/request_unlisted_app.rb" "$TARGET_ID" "$type_clean" || echo "❌ request_unlisted_app.rb gagal dijalankan." ;;
                17) # Upload Playstore Listing
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
                18) # Build APK
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_APK=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                19) # Upload to Google Drive
                   echo "🚀 MENGUNGGAH APK KE GOOGLE DRIVE: $APP_NAME"
                   upload_drive "$TARGET_DIR" "$PRIMARY_TYPE" "$PROJECT_NAME" "$APP_NAME"
                   ;;
                20) # Build AAB
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_AAB=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                21) # Upload Play Store
                   ruby "${SCRIPT_DIR}/scripts/submit_playstore_version.rb" "$TARGET_ID" "$type_clean" || { echo "❌ Proses upload Play Store gagal!"; exit 1; }
                   ;;
            esac"""

content = content.replace(old_type_case, new_type_case)

# 3. Modify Meta loops for 5 and 14 (used to be 4 and 13)
# Note: Since the loop runs "for CURRENT_ACTION in ACTION_ARRAY", we intercept 5 and 14 instead of 4 and 13
old_loop_if = """    if [ "$CURRENT_ACTION" = "4" ]; then
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
        done"""

new_loop_if = """    if [ "$CURRENT_ACTION" = "5" ]; then
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: 5 (FULL DEPLOY iOS)"
        echo "============================================================"
        for sub_action in 6 7 8 9 10 11 12 13; do
            execute_action "$sub_action"
        done
    elif [ "$CURRENT_ACTION" = "14" ]; then
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: 14 (FULL DEPLOY ANDROID)"
        echo "============================================================"
        for sub_action in 15 16 17 18 19 20 21 22; do
            execute_action "$sub_action"
        done"""

content = content.replace(old_loop_if, new_loop_if)

# 4. Modify dependency check for playwright
# Old: 13, 14, 15, 16, 21
# New: 14 (Full Android), 15 (Create), 16 (Setup Info), 17 (Upload Listing), 22 (Submit playwright), 4 (Update dashboard)
old_dep_check = 'if [[ " ${ACTION_ARRAY[*]} " =~ " 13 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 14 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 15 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 16 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 21 " ]]; then'
new_dep_check = 'if [[ " ${ACTION_ARRAY[*]} " =~ " 4 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 14 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 15 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 16 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 17 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 22 " ]]; then'
content = content.replace(old_dep_check, new_dep_check)

with open('release.sh', 'w') as f:
    f.write(content)
