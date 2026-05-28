import os

content = """
# Ganti koma dengan spasi dan pisahkan menjadi array
IFS=' ' read -ra ACTION_ARRAY <<< "$(echo "$action_choice" | tr ',' ' ')"

# Cek apakah ada opsi automasi (untuk install playwright)
if [[ " ${ACTION_ARRAY[*]} " =~ " 4 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 7 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 8 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 9 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 12 " ]]; then
    echo "============================================================"
    echo "📦 MENYIAPKAN DEPENDENSI AUTOMASI (Playwright)"
    echo "============================================================"
    cd "${SCRIPT_DIR}/automation" || exit 1
    if [ ! -d "node_modules" ]; then
        echo "📦 Menginstal dependensi automation (Playwright)..."
        npm install
        npx playwright install chromium
    fi
    
    if [ ! -d "${SCRIPT_DIR}/credentials/.chrome_profile" ]; then
        echo "⚠️ Profil Chrome (Login Play Console) belum ditemukan."
        npm run auth
    fi
    cd "${SCRIPT_DIR}" || exit 1
fi

# Fungsi helper untuk upload drive
upload_drive() {
    local target_dir="$1"
    local p_type="$2"
    local proj="$3"
    local a_name="$4"
    
    local gdrive_folder_id=""
    if [ -f "${SCRIPT_DIR}/config.json" ]; then
        gdrive_folder_id=$(jq -r ".types[\\\"$p_type\\\"].gdrive_folder_id // empty" "${SCRIPT_DIR}/config.json")
    fi
    
    local env_file="${SCRIPT_DIR}/.env"
    local gdrive_cred_path=""
    if [ -f "$env_file" ]; then
        local raw_cred_path=$(grep '^GDRIVE_CREDENTIALS_PATH=' "$env_file" | cut -d '"' -f 2)
        if [ -n "$raw_cred_path" ]; then
            gdrive_cred_path="${SCRIPT_DIR}/${raw_cred_path}"
        fi
    fi
    
    if [ -z "$gdrive_folder_id" ] || [ -z "$gdrive_cred_path" ]; then
        echo "❌ Error: Konfigurasi Google Drive tidak lengkap di config.json atau .env."
        exit 1
    fi
    
    local latest_apk=$(find "$target_dir" -name "*.apk" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$latest_apk" ]; then
        python3 "${SCRIPT_DIR}/scripts/upload_to_gdrive.py" "$latest_apk" "$gdrive_folder_id" "$gdrive_cred_path" "$proj" "$a_name"
    else
        echo "⚠️ File APK tidak ditemukan di $target_dir"
        exit 1
    fi
}

upload_testflight() {
    local target_dir="$1"
    local t_id="$2"
    local a_pkg="$3"
    local a_name="$4"
    local t_clean="$5"
    
    local latest_ipa=$(find "$target_dir" -name "*.ipa" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$latest_ipa" ]; then
        ruby "${SCRIPT_DIR}/scripts/upload_to_testflight.rb" "$latest_ipa" "$a_pkg" "$a_name" "$t_clean"
        local ruby_exit_code=$?
        
        if [ $ruby_exit_code -eq 2 ]; then
            echo "🕒 Menjadwalkan submit ulang TestFlight dalam 5 menit..."
            nohup bash -c "sleep 300 && cd \\\"${SCRIPT_DIR}\\\" && SKIP_UPLOAD=true ./release.sh -t \\\"$t_id\\\"" > "${SCRIPT_DIR}/testflight_retry.log" 2>&1 &
            local pid=$!
            echo "$pid|$t_id|$a_name|$(date +%s)" >> "${SCRIPT_DIR}/.schedulers"
            echo "✅ Penjadwalan berhasil (proses berjalan di background dengan PID: $pid)."
        elif [ $ruby_exit_code -ne 0 ]; then
            echo "❌ Upload ke TestFlight gagal."
            exit 1
        fi
    else
        echo "⚠️ File IPA tidak ditemukan di $target_dir"
        exit 1
    fi

    if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then
        bash "${SCRIPT_DIR}/init_appstore.sh" "$t_id" || { echo "❌ Proses init appstore gagal!"; exit 1; }
    fi
}

execute_action() {
    local action="$1"
    
    for TARGET_ID in "${SELECTED_TARGETS[@]}"; do
        echo "============================================================"
        echo "🚀 MEMPROSES PROJECT: $TARGET_ID"
        echo "============================================================"
        
        # Eksekusi aksi yang berada di level target (tidak butuh looping per tipe aplikasi)
        case "$action" in
            4) 
                echo "🎥 Membuka Playwright Inspector..."
                npm run record
                continue
                ;;
            7) 
                if node "${SCRIPT_DIR}/automation/create_app.js" "$TARGET_ID"; then
                    echo "✅ create_app.js berhasil"
                else
                    echo "❌ create_app.js gagal dijalankan."
                fi
                continue
                ;;
            8) 
                node "${SCRIPT_DIR}/automation/runner_app_info.js" "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                continue
                ;;
            12) 
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
                2) # Setup Konfigurasi
                   bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }
                   script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
                   if [ -f "$script_file" ]; then
                       REGION=$(jq -r ".\\\"$TARGET_ID\\\".Project.Region // empty" "$PROJECT_FILE")
                       BASE_URL=$(jq -r ".\\\"$TARGET_ID\\\".Project.\\\"Base URL\\\" // empty" "$PROJECT_FILE")
                       DATABASE=$(jq -r ".\\\"$TARGET_ID\\\".Project.Database // empty" "$PROJECT_FILE")
                       bash "$script_file" "$TARGET_ID" "$REGION" "$APP_NAME" "$type_clean" "$BASE_URL" "$DATABASE" "$APP_PACKAGE_NAME" || { echo "❌ Proses setup $type_clean gagal!"; exit 1; }
                   fi
                   ;;
                3) ruby "${SCRIPT_DIR}/scripts/bump_version.rb" "$TARGET_ID" "$type_clean" || echo "❌ bump_version.rb gagal dijalankan." ;;
                5) # Upload GDrive
                   echo "🚀 MENGUNGGAH KE GOOGLE DRIVE: $APP_NAME"
                   upload_drive "$TARGET_DIR" "$PRIMARY_TYPE" "$PROJECT_NAME" "$APP_NAME"
                   ;;
                6) # Build APK & AAB
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_APK=true BUILD_TARGET_AAB=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                9) # Setup Store Listing
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
                10) ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$type_clean" || echo "❌ update_store_listing.rb gagal dijalankan." ;;
                11) ruby "${SCRIPT_DIR}/scripts/download_playstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ download_playstore_metadata.rb gagal dijalankan." ;;
                13) # Build IPA
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_IPA=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
                14) # Upload TestFlight
                   echo "🍎 MENGUNGGAH KE TESTFLIGHT: $APP_NAME"
                   upload_testflight "$TARGET_DIR" "$TARGET_ID" "$APP_PACKAGE_NAME" "$APP_NAME" "$type_clean"
                   ;;
                15) # Submit TestFlight
                   echo "🍎 MENGUNGGAH KE TESTFLIGHT: $APP_NAME (Skip IPA Upload)"
                   export SKIP_UPLOAD=true
                   upload_testflight "$TARGET_DIR" "$TARGET_ID" "$APP_PACKAGE_NAME" "$APP_NAME" "$type_clean"
                   ;;
                16) ruby "${SCRIPT_DIR}/scripts/setup_appstore_info.rb" "$TARGET_ID" "$type_clean" || echo "❌ setup_appstore_info.rb gagal dijalankan." ;;
                17) ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ push_appstore_metadata.rb gagal dijalankan." ;;
                18) ruby "${SCRIPT_DIR}/scripts/download_appstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ download_appstore_metadata.rb gagal dijalankan." ;;
                19) ruby "${SCRIPT_DIR}/scripts/request_unlisted_app.rb" "$TARGET_ID" "$type_clean" || echo "❌ request_unlisted_app.rb gagal dijalankan." ;;
                20) ruby "${SCRIPT_DIR}/scripts/submit_appstore_version.rb" "$TARGET_ID" "$type_clean" || echo "❌ submit_appstore_version.rb gagal dijalankan." ;;
                21) # Upload Play Store
                   ruby "${SCRIPT_DIR}/scripts/submit_playstore_version.rb" "$TARGET_ID" "$type_clean" || { echo "❌ Proses upload Play Store gagal!"; exit 1; }
                   ;;
                22) # Build AAB Saja
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_AAB=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"
                       exit 1
                   fi
                   ;;
            esac
        done
    done
}

for CURRENT_ACTION in "${ACTION_ARRAY[@]}"; do
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
        execute_action "$CURRENT_ACTION"
    fi
done

echo ""
echo "============================================================"
echo "✅ SEMUA PROSES SELESAI!"
echo "============================================================"
exit 0
"""
with open('release_bottom.sh', 'w') as f:
    f.write(content)
