        if [ -n "$local_input" ]; then
            if [ "$UPLOAD_ONLY_MODE" = true ]; then
                TARGET_ID="$local_input"
            elif [ "$BUILD_ONLY_MODE" = true ]; then
                TARGET_ID="$local_input"
            else
                TARGET_ID="$local_input"
                tput clear
                echo "============================================================"
                echo "🛠️ PILIH AKSI UNTUK: $local_input"
                echo "============================================================"
                echo "1) Full (Semua proses)"
                echo "2) Setup Konfigurasi"
                echo "3) Build"
                echo "4) Upload Drive"
                echo "5) Upload TestFlight"
                echo "------------------------------------------------------------"
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 3 5): "
                read -r action_choice

                if [[ "$action_choice" == *1* ]]; then
                    OPT_SETUP=true
                    OPT_BUILD=true
                    OPT_UPLOAD_DRIVE=true
                    OPT_UPLOAD_TESTFLIGHT=true
                else
                    if [[ "$action_choice" == *2* ]]; then OPT_SETUP=true; fi
                    if [[ "$action_choice" == *3* ]]; then OPT_BUILD=true; fi
                    if [[ "$action_choice" == *4* ]]; then OPT_UPLOAD_DRIVE=true; fi
                    if [[ "$action_choice" == *5* ]]; then OPT_UPLOAD_TESTFLIGHT=true; fi
                fi
                
                if [ "$OPT_SETUP" = false ] && [ "$OPT_BUILD" = false ] && [ "$OPT_UPLOAD_DRIVE" = false ] && [ "$OPT_UPLOAD_TESTFLIGHT" = false ]; then
                    echo "❌ Pilihan tidak valid."
                    exit 1
                fi
            fi
        else
            echo "❌ Batal memilih project."
            exit 0
        fi
    fi
fi

if [ -n "$TARGET_ID" ]; then
    if command -v jq >/dev/null 2>&1 && jq -e ".\"$TARGET_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
        echo "🚀 Mengeksekusi project terdaftar: $TARGET_ID"
        PROJECT=$(jq -r ".\"$TARGET_ID\".Project.\"Project Name\" // empty" "$PROJECT_FILE")
        REGION=$(jq -r ".\"$TARGET_ID\".Project.Region // empty" "$PROJECT_FILE")
        APP_NAME=$(jq -r ".\"$TARGET_ID\".Project.\"App Name\" // empty" "$PROJECT_FILE")
        TYPE=$(jq -r ".\"$TARGET_ID\".Project.Type // empty" "$PROJECT_FILE")
        BASE_URL=$(jq -r ".\"$TARGET_ID\".Project.\"Base URL\" // empty" "$PROJECT_FILE")
        DATABASE=$(jq -r ".\"$TARGET_ID\".Project.Database // empty" "$PROJECT_FILE")
        ICON=$(jq -r ".\"$TARGET_ID\".Project.Icon // empty" "$PROJECT_FILE")
        NOTES=$(jq -r ".\"$TARGET_ID\".Project.Notes // empty" "$PROJECT_FILE")
        ID="$TARGET_ID"
    else
        echo "❌ Error: Project dengan ID '$TARGET_ID' tidak ditemukan di projects.json, atau jq tidak terinstall."
        exit 1
    fi
else
    # Generate ID dari Project Name
    ID=$(generate_id "$PROJECT")
    if [ -z "$ID" ]; then
        # Fallback jika nama project kosong
        ID=$(generate_id "$APP_NAME")
        if [ -z "$ID" ]; then
            ID="default_id"
        fi
    fi

    # Set Branch sama dengan ID
    BRANCH="$ID"

    # Generate Branch JSON object based on TYPE
    BRANCH_JSON="{"
    IFS=',' read -ra ADDR <<< "$TYPE"
    for i in "${!ADDR[@]}"; do
        type_clean=$(echo "${ADDR[$i]}" | xargs)
        BRANCH_JSON+="\"$type_clean\": \"$BRANCH\""
        if [ $i -lt $((${#ADDR[@]}-1)) ]; then
            BRANCH_JSON+=", "
        fi
    done
    BRANCH_JSON+="}"


    # Membersihkan dan memformat BASE_URL
    if [ -n "$BASE_URL" ]; then
        RAW_URL=$(echo "$BASE_URL" | tr ',' ' ' | tr ' ' '\n' | grep '\.' | tail -n 1)
        CLEAN_URL=$(echo "$RAW_URL" | sed -E 's|^https?://||' | cut -d '/' -f 1)
        BASE_URL="https://${CLEAN_URL}"
    fi

    # Inisialisasi projects.json jika belum ada atau kosong
    if [ ! -s "$PROJECT_FILE" ]; then
        echo "{}" > "$PROJECT_FILE"
    fi

    # Mencetak output dalam format JSON dan menyimpannya ke projects.json
    if command -v jq >/dev/null 2>&1; then
        NEW_PROJECT=$(jq -n \
          --arg id "$ID" \
          --argjson branch "$BRANCH_JSON" \
          --arg pn "$PROJECT" \
          --arg r "$REGION" \
          --arg an "$APP_NAME" \
          --arg t "$TYPE" \
          --arg bu "$BASE_URL" \
          --arg db "$DATABASE" \
          --arg ic "$ICON" \
          --arg n "$NOTES" \
          '{
            ($id): {
              "Branch": $branch,
              "Project": {
                "Project Name": $pn,
                "Region": $r,
                "App Name": $an,
                "Type": $t,
                "Base URL": $bu,
                "Database": $db,
                "Icon": $ic,
                "Notes": $n
              }
            }
          }')
        
        # Gabungkan (merge) project baru ke dalam projects.json
        jq --argjson newProj "$NEW_PROJECT" '. * $newProj' "$PROJECT_FILE" > "${PROJECT_FILE}.tmp" && mv "${PROJECT_FILE}.tmp" "$PROJECT_FILE"
        echo "✓ Project '$ID' berhasil ditambahkan/diperbarui di projects.json!"
    else
        echo "⚠️ Peringatan: Program 'jq' tidak ditemukan."
        echo "Harap install 'jq' agar data bisa disimpan otomatis ke projects.json."
    fi
    TARGET_ID="$ID"
fi

echo "============================================================"
echo "📋 PROJECT INFORMATION"
echo "============================================================"
if command -v jq >/dev/null 2>&1 && [ -f "$PROJECT_FILE" ]; then
    jq ".\"$ID\"" "$PROJECT_FILE"
else
    echo "ID: $ID | Project: $PROJECT | App Name: $APP_NAME"
fi
echo ""

# Get Prefix from config.json based on App Type
CONFIG_FILE="${SCRIPT_DIR}/config.json"
PREFIX=""
if command -v jq >/dev/null 2>&1 && [ -f "$CONFIG_FILE" ]; then
    PREFIX=$(jq -r ".types[\"$TYPE\"].prefix // empty" "$CONFIG_FILE")
fi
if [ -z "$PREFIX" ]; then
    PREFIX="com.example"
fi
APP_PACKAGE_NAME="${PREFIX}.${ID}"


# STAGE 1: SETUP
if [ "$OPT_SETUP" = true ]; then
    if [ -n "$ICON" ]; then
        echo "============================================================"
        echo "🖼️ MENYIAPKAN IKON APLIKASI"
        echo "============================================================"
        bash "${SCRIPT_DIR}/scripts/prepare-icon.sh" "$ICON" || { echo "❌ Gagal menyiapkan ikon!"; exit 1; }
        echo ""
    fi

    echo "============================================================"
    echo "📊 INFORMASI APLIKASI (Release Hub)"
    echo "============================================================"
    bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }

    if [ "$TYPE" == "HRM Apps" ]; then
        echo "============================================================"
        bash "${SCRIPT_DIR}/scripts/setup_hrm.sh" "$ID" "$REGION" "$APP_NAME" "$TYPE" "$BASE_URL" "$DATABASE" "$APP_PACKAGE_NAME" || { echo "❌ Proses setup HRM gagal!"; exit 1; }
        echo "============================================================"
    fi

    if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then
        bash "${SCRIPT_DIR}/init_appstore.sh" "$ID" || { echo "❌ Proses init appstore gagal!"; exit 1; }
    fi
fi

# STAGE 2: BUILD
if [ "$OPT_BUILD" = true ]; then
    if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
        export SKIP_UPLOAD=true
        bash "${SCRIPT_DIR}/build_app.sh" "$ID" || { echo "❌ Proses build gagal!"; exit 1; }
    else
        echo "❌ Script build_app.sh tidak ditemukan!"
        exit 1
    fi
fi

# STAGE 3: UPLOAD
TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT}/${type_clean}"

if [ "$OPT_UPLOAD_DRIVE" = true ]; then
    echo "============================================================"
    echo "🚀 MENGUNGGAH KE GOOGLE DRIVE: $APP_NAME"
    echo "============================================================"
    
    if [ ! -d "$TARGET_DIR" ]; then
        echo "❌ Error: Folder $TARGET_DIR tidak ditemukan."
        exit 1
    fi
    
    GDRIVE_FOLDER_ID=""
    if [ -f "$CONFIG_FILE" ]; then
        GDRIVE_FOLDER_ID=$(jq -r ".types[\"$TYPE\"].gdrive_folder_id // empty" "$CONFIG_FILE")
    fi
    
    ENV_FILE="${SCRIPT_DIR}/.env"
    GDRIVE_CRED_PATH=""
    if [ -f "$ENV_FILE" ]; then
        RAW_CRED_PATH=$(grep '^GDRIVE_CREDENTIALS_PATH=' "$ENV_FILE" | cut -d '"' -f 2)
        if [ -n "$RAW_CRED_PATH" ]; then
            GDRIVE_CRED_PATH="${SCRIPT_DIR}/${RAW_CRED_PATH}"
        fi
    fi
    
    if [ -z "$GDRIVE_FOLDER_ID" ] || [ -z "$GDRIVE_CRED_PATH" ]; then
        echo "❌ Error: Konfigurasi Google Drive tidak lengkap di config.json atau .env."
        exit 1
    fi
    
    LATEST_APK=$(find "$TARGET_DIR" -name "*.apk" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$LATEST_APK" ]; then
        python3 "${SCRIPT_DIR}/scripts/upload_to_gdrive.py" "$LATEST_APK" "$GDRIVE_FOLDER_ID" "$GDRIVE_CRED_PATH" "$PROJECT" "$APP_NAME"
    else
        echo "⚠️ File APK tidak ditemukan di $TARGET_DIR"
        exit 1
    fi
fi

if [ "$OPT_UPLOAD_TESTFLIGHT" = true ]; then
    echo "============================================================"
    echo "🍎 MENGUNGGAH KE TESTFLIGHT: $APP_NAME"
    echo "============================================================"
    
    if [ ! -d "$TARGET_DIR" ]; then
        echo "❌ Error: Folder $TARGET_DIR tidak ditemukan."
        exit 1
    fi
    
    LATEST_IPA=$(find "$TARGET_DIR" -name "*.ipa" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$LATEST_IPA" ]; then
        ruby "${SCRIPT_DIR}/scripts/upload_to_testflight.rb" "$LATEST_IPA" "$APP_PACKAGE_NAME" "$APP_NAME" "$TYPE"
    else
        echo "⚠️ File IPA tidak ditemukan di $TARGET_DIR"
        exit 1
    fi
fi
