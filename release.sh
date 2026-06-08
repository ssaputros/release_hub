#!/bin/bash

# Inisialisasi variabel
PROJECT=""
REGION=""
APP_NAME=""
TYPE=""
BASE_URL=""
DATABASE=""
ICON=""
NOTES=""
RUN_ID=""
UPLOAD_ONLY_ID=""
UPLOAD_ONLY_MODE=false
TESTFLIGHT_MODE=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Load .env variables automatically
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
    
    # Map APPLE_ID_USERNAME to FASTLANE_USER for spaceship
    if [ -n "$APPLE_ID_USERNAME" ]; then
        export FASTLANE_USER="$APPLE_ID_USERNAME"
    fi
    
    # Map TEAM_ID and ITC_TEAM_ID for spaceship to avoid Team prompts
    if [ -n "$TEAM_ID" ]; then
        export FASTLANE_TEAM_ID="$TEAM_ID"
    fi
    if [ -n "$ITC_TEAM_ID" ]; then
        export FASTLANE_ITC_TEAM_ID="$ITC_TEAM_ID"
    fi
fi

manage_jobs() {
    local schedulers_file="${SCRIPT_DIR}/.schedulers"
    if [ ! -s "$schedulers_file" ]; then
        echo "ℹ️ Tidak ada scheduler TestFlight yang aktif."
        exit 0
    fi
    
    echo "============================================================"
    echo "🕒 DAFTAR SCHEDULER AKTIF"
    echo "============================================================"
    
    local active_jobs=()
    local temp_file="${schedulers_file}.tmp"
    > "$temp_file"
    
    local no=1
    while IFS="|" read -r pid target_id app_name timestamp; do
        if kill -0 "$pid" 2>/dev/null; then
            local time_str=$(date -r "$timestamp" "+%H:%M:%S" 2>/dev/null || date -d "@$timestamp" "+%H:%M:%S" 2>/dev/null)
            if [ -z "$time_str" ]; then time_str="Unknown"; fi
            printf "%-3s PID: %-6s Project: %-15s App: %-15s Waktu Jadwal: %s\n" "$no." "$pid" "$target_id" "$app_name" "$time_str"
            active_jobs+=("$pid|$target_id")
            echo "$pid|$target_id|$app_name|$timestamp" >> "$temp_file"
            ((no++))
        fi
    done < "$schedulers_file"
    
    mv "$temp_file" "$schedulers_file"
    
    if [ ${#active_jobs[@]} -eq 0 ]; then
        echo "ℹ️ Tidak ada scheduler TestFlight yang aktif (sudah selesai semua)."
        exit 0
    fi
    
    echo "------------------------------------------------------------"
    echo -n "Pilih nomor scheduler yang ingin dibatalkan (atau 0 untuk keluar): "
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le ${#active_jobs[@]} ]; then
        local selected_idx=$((choice - 1))
        local selected_job="${active_jobs[$selected_idx]}"
        local selected_pid="${selected_job%%|*}"
        
        echo "🛑 Membatalkan scheduler dengan PID: $selected_pid..."
        kill -9 "$selected_pid" 2>/dev/null
        
        # Hapus dari file
        grep -v "^${selected_pid}|" "$schedulers_file" > "$temp_file"
        mv "$temp_file" "$schedulers_file"
        echo "✅ Scheduler berhasil dibatalkan."
    else
        echo "Keluar."
    fi
    exit 0
}
# Fungsi untuk menampilkan bantuan
show_help() {
    echo "============================================================"
    echo "🚀 RELEASE HUB CLI"
    echo "============================================================"
    echo "Penggunaan: release [OPTIONS] [PROJECT_ID]"
    echo ""
    echo "Jika dipanggil tanpa parameter, akan memunculkan menu interaktif untuk memilih project."
    echo ""
    echo "Opsi:"
    echo "  -h, --help            Menampilkan bantuan ini"
    echo "  -j, --jobs            Mengelola daftar scheduler TestFlight yang sedang berjalan"
    echo "  -u, --upload [ID]     Hanya mengunggah build terakhir (upload only) ke Google Drive. Bisa juga tanpa ID untuk memilih interaktif."
    echo "  -t, --testflight [ID] Hanya mengunggah IPA terakhir ke TestFlight External dan generate Public Link."
    echo "  -b, --build           Hanya menjalankan proses build aplikasi (APK/IPA) tanpa melakukan setup environment atau upload."
    echo "  --project <nama>      Menentukan Nama Project baru"
    echo "  --region <region>     Menentukan Region Project"
    echo "  --app-name <nama>     Menentukan Nama Aplikasi"
    echo "  --type <tipe>         Menentukan Tipe Aplikasi (contoh: 'HRM Apps')"
    echo "  --base-url <url>      Menentukan Base URL API"
    echo "  --database <db>       Menentukan Nama Database"
    echo "  --icon <url>          URL Google Drive gambar untuk diconvert otomatis menjadi ikon aplikasi"
    echo "  --notes <catatan>     Menambahkan catatan tambahan"
    echo ""
    echo "Contoh:"
    echo "  release                         # Membuka menu pilihan project secara interaktif"
    echo "  release smkgemanusantara        # Build project dengan ID 'smkgemanusantara'"
    echo "  release -u                      # Pilih project interaktif lalu hanya upload APK tanpa build ulang"
    echo "  release -u smkgemanusantara     # Upload APK dari 'smkgemanusantara' tanpa build ulang"
    echo "  release -b                      # Build aplikasi dari environment saat ini tanpa setup ulang dan tanpa upload"
    echo "  release --project 'PT Baru' --app-name 'Baru HRIS' --type 'HRM Apps' --base-url 'https://api.baru.com' --database 'baru_db'"
    exit 0
}

# Looping untuk mem-parsing argumen
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -j|--jobs) manage_jobs ;;
        -b|--build) 
            BUILD_ONLY_MODE=true
            if [[ -n "$2" && "$2" != -* ]]; then
                BUILD_ONLY_ID="$2"
                shift
            fi
            ;;
        -u|--upload) 
            UPLOAD_ONLY_MODE=true
            if [[ -n "$2" && "$2" != -* ]]; then
                UPLOAD_ONLY_ID="$2"
                shift
            fi
            ;;
        -t|--testflight)
            TESTFLIGHT_MODE=true
            UPLOAD_ONLY_MODE=true
            if [[ -n "$2" && "$2" != -* ]]; then
                UPLOAD_ONLY_ID="$2"
                shift
            fi
            ;;
        --project) PROJECT="$2"; shift ;;
        --region) REGION="$2"; shift ;;
        --app-name) APP_NAME="$2"; shift ;;
        --type) TYPE="$2"; shift ;;
        --base-url) BASE_URL="$2"; shift ;;
        --database) DATABASE="$2"; shift ;;
        --icon) ICON="$2"; shift ;;
        --notes) NOTES="$2"; shift ;;
        --project-key) PROJECT_KEY="$2"; shift ;;
        --branch-name) BRANCH_NAME="$2"; shift ;;
        --firebase-project) FIREBASE_PROJECT="$2"; shift ;;
        -m|--menu) MENU_CHOICE="$2"; shift ;;
        -a|--action) ACTION_CHOICE="$2"; shift ;;
        -f|--file) FILE_PATH_ARG="$2"; shift ;;
        --bundle-id) BUNDLE_ID_ARG="$2"; shift ;;
        --track) TRACK_ARG="$2"; shift ;;
        --method) METHOD_ARG="$2"; shift ;;
        *) 
            # Jika argumen berupa durasi waktu (15m, 1h, 30s)
            if [[ "$1" =~ ^[0-9]+[mhsd]$ ]]; then
                DELAY_TIME="$1"
            # Jika argumen tidak diawali '--' dan RUN_ID masih kosong, anggap itu ID project
            elif [[ "$1" != --* ]] && [ -z "$RUN_ID" ]; then
                RUN_ID="$1"
            else
                echo "Error: Parameter tidak dikenal '$1'"
                exit 1
            fi
            ;;
    esac
    shift
done

ORIGINAL_ARGS="$*"

LOG_FILE="${SCRIPT_DIR}/release_scheduler.log"
log_action() {
    local status="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $message" >> "$LOG_FILE"
}

wait_if_scheduled() {
    if [ -n "$DELAY_TIME" ] && [ "${ALREADY_WAITED:-false}" != "true" ]; then
        log_action "INFO" "Scheduled release started. Waiting for $DELAY_TIME. Args: $ORIGINAL_ARGS"
        echo "============================================================"
        echo "⏳ MENJADWALKAN EKSEKUSI DI BACKGROUND..."
        echo "============================================================"
        echo "Script akan berjalan dalam $DELAY_TIME."
        echo "Anda dapat menutup terminal ini dengan aman."
        
        # Eksekusi background menggunakan nohup
        # Kita menggunakan exec untuk menggantikan current process atau spawn baru yang disown
        # Tapi karena ini bash function, kita spawn script ini lagi tanpa argumen delay
        
        local clean_args=$(echo "$ORIGINAL_ARGS" | sed -E "s/\\b[0-9]+[mhsd]\\b//g")
        nohup bash -c "sleep $DELAY_TIME && \"${SCRIPT_DIR}/release.sh\" $clean_args" >> "$LOG_FILE" 2>&1 &
        local pid=$!
        
        echo "✅ Proses berjalan di background (PID: $pid)."
        echo "Log dapat dilihat di: $LOG_FILE"
        exit 0
    fi
}

# Fungsi untuk membuat ID (gabungan teks, lowercase, tanpa special char)
generate_id() {
    # Menghapus spasi dan semua karakter non-alfanumerik, lalu ubah ke lowercase
    echo "$1" | sed 's/[^a-zA-Z0-9]//g' | tr 'A-Z' 'a-z'
}


# Setel opsi Ruby untuk menyembunyikan warning bawaan (seperti error ekstensi belum di-build)
export RUBYOPT="-W0"

# Trap function untuk membersihkan temporary files dan memainkan suara ketika script berhenti
on_exit() {
    local exit_code=$?
    
    if [ -n "$DELAY_TIME" ]; then
        if [ $exit_code -eq 0 ]; then
            log_action "SUCCESS" "Scheduled release ($DELAY_TIME) finished successfully. Target: ${RUN_ID:-Interactive}"
        else
            log_action "ERROR" "Scheduled release ($DELAY_TIME) failed with exit code $exit_code. Target: ${RUN_ID:-Interactive}"
        fi
    fi

    echo ""
    echo "🧹 Membersihkan perubahan temporary pada Release Hub..."
    git checkout -- android/ ios/ >/dev/null 2>&1
    rm -f icon/*.png icon/icon_raw >/dev/null 2>&1

    if [ -f "${SCRIPT_DIR}/assets/done_sound.wav" ]; then
        afplay "${SCRIPT_DIR}/assets/done_sound.wav" >/dev/null 2>&1 &
    fi
}
trap on_exit EXIT

PROJECT_FILE="${SCRIPT_DIR}/projects.json"


if [ -z "$RUN_ID" ] && [ -z "$PROJECT" ] && [ -z "$UPLOAD_ONLY_ID" ] && [ -z "$BUILD_ONLY_ID" ]; then
    if [ -s "$PROJECT_FILE" ] && command -v jq >/dev/null 2>&1; then
        # Ekstrak data project HANYA SEKALI
        projects_data=$(jq -r 'to_entries | .[] | "\(.key)|\(.value.Project["Project Name"])"' "$PROJECT_FILE")
        
        echo "============================================================"
        echo "🔧 UTILITIES (GLOBAL)"
        echo "============================================================"
        echo "A) Record Playwright UI"
        echo "B) Download Play Store Metadata"
        echo "C) Download App Store Metadata"
        echo "D) Create New Project"
        echo "E) Upload Google Drive (File Bebas)"
        echo "F) Submit Testflight (File IPA)"
        echo "G) Upload Appstore (File IPA)"
        echo "H) Submit Appstore Review (Bundle ID)"
        echo "I) Submit Playstore (File AAB)"
        echo "J) Import Project from Branch (Reverse Setup)"
        echo "K) Login Google Drive"
        echo "L) Push Metadata (App Store) Manual"
        echo "============================================================"
        echo "📋 DAFTAR PROJECT"
        echo "============================================================"
        
        # Simpan keys dalam array map index -> project_id
        declare -a PROJ_MAP
        no=1
        while IFS="|" read -r pid pname; do
            printf "%-3s %-20s %s\n" "$no)" "$pid" "$pname"
            PROJ_MAP[$no]="$pid"
            ((no++))
        done <<< "$projects_data"
        
        echo "------------------------------------------------------------"
        if [ -n "$MENU_CHOICE" ]; then
            project_input="$MENU_CHOICE"
            echo "Pilihan otomatis (dari argumen): $project_input"
        else
            echo -n "Masukkan nomor project (misal: 2 4 5), 'all', atau opsi utilities (A/B/C/D/E/F/G/H/I/J/K/L): "
            read -r project_input
        fi
        
        if [ -z "$project_input" ]; then
            echo "❌ Input tidak boleh kosong."
            exit 1
        fi

        if [[ "$project_input" =~ ^[Aa]$ ]]; then
            echo "============================================================"
            echo "📦 MENYIAPKAN DEPENDENSI AUTOMASI (Playwright)"
            echo "============================================================"
            cd "${SCRIPT_DIR}/automation" || exit 1
            if [ ! -d "node_modules" ]; then
                echo "📦 Menginstal dependensi automation (Playwright)..."
                npm install
                npx playwright install chromium
            fi
            echo "🎥 Membuka Playwright Inspector..."
            npm run record
            exit 0
        elif [[ "$project_input" =~ ^[Bb]$ ]]; then
            ruby "${SCRIPT_DIR}/scripts/download_playstore_metadata.rb"
            exit 0
        elif [[ "$project_input" =~ ^[Cc]$ ]]; then
            ruby "${SCRIPT_DIR}/scripts/download_appstore_metadata.rb"
            exit 0
        elif [[ "$project_input" =~ ^[Dd]$ ]]; then
            echo "============================================================"
            echo "➕ CREATE NEW PROJECT"
            echo "============================================================"
            read -p "1. Project Key (kunci utama JSON, misal: namaclient) [Auto-generate]: " IN_PROJECT_KEY; PROJECT_KEY="${IN_PROJECT_KEY:-$PROJECT_KEY}"
            read -p "2. App Types (Pilih: HRM Apps / Approval Apps / Keduanya) [${TYPE:-HRM Apps}]: " IN_TYPE; TYPE="${IN_TYPE:-${TYPE:-HRM Apps}}"
            read -p "3. Project Name (Nama lengkap client/project, misal: PT Nama Client) [${PROJECT}]: " IN_PROJECT; PROJECT="${IN_PROJECT:-$PROJECT}"
            read -p "4. Region (misal: Indonesia) [${REGION:-Indonesia}]: " IN_REGION; REGION="${IN_REGION:-${REGION:-Indonesia}}"
            read -p "5. Base URL (misal: https://namaclient.hashmicro.co) [${BASE_URL}]: " IN_BASE_URL; BASE_URL="${IN_BASE_URL:-$BASE_URL}"
            read -p "6. Database (Nama database Odoo, misal: namaclient-live) [${DATABASE}]: " IN_DATABASE; DATABASE="${IN_DATABASE:-$DATABASE}"
            read -p "7. Branch Name (Nama branch di Git) [${BRANCH_NAME:-Sama dengan Project Key}]: " IN_BRANCH_NAME; BRANCH_NAME="${IN_BRANCH_NAME:-$BRANCH_NAME}"
            read -p "8. Base Nama Aplikasi (misal 'ZPP', otomatis ditambah suffix) [${APP_NAME}]: " IN_APP_NAME; APP_NAME="${IN_APP_NAME:-$APP_NAME}"
            read -p "9. Firebase Project (misal: hashmicro-production-17, kosongkan jika tidak ada) [${FIREBASE_PROJECT}]: " IN_FIREBASE_PROJECT; FIREBASE_PROJECT="${IN_FIREBASE_PROJECT:-$FIREBASE_PROJECT}"
            read -p "10. Icon (URL GDrive / Path Lokal, kosongkan jika belum ada) [${ICON}]: " IN_ICON; ICON="${IN_ICON:-$ICON}"
            exec "$0" --project "$PROJECT" --region "$REGION" --app-name "$APP_NAME" --type "$TYPE" --base-url "$BASE_URL" --database "$DATABASE" --icon "$ICON" --project-key "$PROJECT_KEY" --branch-name "$BRANCH_NAME" --firebase-project "$FIREBASE_PROJECT"
        elif [[ "$project_input" =~ ^[Ee]$ ]]; then
            echo "============================================================"
            echo "📁 UPLOAD GOOGLE DRIVE (FILE BEBAS)"
            echo "============================================================"
            FILE_PATH="${FILE_PATH_ARG}"
            if [ -z "$FILE_PATH" ]; then read -e -p "Masukkan Path File: " FILE_PATH; fi
            
            FOLDER_NAME="${APP_NAME}"
            if [ -z "$FOLDER_NAME" ]; then read -p "Masukkan Nama Folder: " FOLDER_NAME; fi
            
            if [ ! -f "$FILE_PATH" ]; then
                echo "❌ File tidak ditemukan: $FILE_PATH"
                exit 1
            fi
            
            CONFIG_FILE="${SCRIPT_DIR}/config.json"
            GDRIVE_FOLDER_ID=$(jq -r ".types[\"HRM Apps\"].gdrive_folder_id // empty" "$CONFIG_FILE")
            ENV_FILE="${SCRIPT_DIR}/.env"
            GDRIVE_CRED_PATH=""
            if [ -f "$ENV_FILE" ]; then
                RAW_CRED_PATH=$(grep '^GDRIVE_CREDENTIALS_PATH=' "$ENV_FILE" | cut -d '"' -f 2)
                if [ -n "$RAW_CRED_PATH" ]; then GDRIVE_CRED_PATH="${SCRIPT_DIR}/${RAW_CRED_PATH}"; fi
            fi
            if [ -z "$GDRIVE_FOLDER_ID" ] || [ -z "$GDRIVE_CRED_PATH" ]; then
                echo "❌ Error: Konfigurasi GDrive tidak lengkap (cek config.json atau .env)."
                exit 1
            fi
            python3 "${SCRIPT_DIR}/scripts/upload_to_gdrive.py" "$FILE_PATH" "$GDRIVE_FOLDER_ID" "$GDRIVE_CRED_PATH" "$FOLDER_NAME" ""
            exit 0
        elif [[ "$project_input" =~ ^[Ff]$ ]]; then
            echo "============================================================"
            echo "🍎 SUBMIT TESTFLIGHT (FILE IPA)"
            echo "============================================================"
            FILE_PATH="${FILE_PATH_ARG}"
            if [ -z "$FILE_PATH" ]; then read -e -p "Masukkan Path File (.ipa): " FILE_PATH; fi
            
            if [ ! -f "$FILE_PATH" ]; then
                echo "❌ File tidak ditemukan: $FILE_PATH"
                exit 1
            fi
            
            echo "🔍 Mengekstrak Bundle ID dari file IPA..."
            BUNDLE_ID=$(unzip -p "$FILE_PATH" Payload/*.app/Info.plist | plutil -extract CFBundleIdentifier raw -)
            if [ -z "$BUNDLE_ID" ]; then
                echo "❌ Gagal mengekstrak Bundle ID dari IPA. Pastikan file IPA valid."
                exit 1
            fi
            echo "✅ Bundle ID: $BUNDLE_ID"
            
            ruby "${SCRIPT_DIR}/scripts/upload_to_testflight.rb" "$FILE_PATH" "$BUNDLE_ID" "Custom App" "Standalone"
            exit 0
        elif [[ "$project_input" =~ ^[Gg]$ ]]; then
            echo "============================================================"
            echo "🍎 UPLOAD APP STORE (FILE IPA)"
            echo "============================================================"
            FILE_PATH="${FILE_PATH_ARG}"
            if [ -z "$FILE_PATH" ]; then read -e -p "Masukkan Path File (.ipa): " FILE_PATH; fi
            
            if [ ! -f "$FILE_PATH" ]; then
                echo "❌ File tidak ditemukan: $FILE_PATH"
                exit 1
            fi
            
            echo "🔍 Mengekstrak Bundle ID dari file IPA..."
            BUNDLE_ID=$(unzip -p "$FILE_PATH" Payload/*.app/Info.plist | plutil -extract CFBundleIdentifier raw -)
            if [ -z "$BUNDLE_ID" ]; then
                echo "❌ Gagal mengekstrak Bundle ID dari IPA. Pastikan file IPA valid."
                exit 1
            fi
            echo "✅ Bundle ID: $BUNDLE_ID"
            
            ruby "${SCRIPT_DIR}/scripts/upload_to_appstore.rb" "$FILE_PATH" "$BUNDLE_ID"
            exit 0
        elif [[ "$project_input" =~ ^[Hh]$ ]]; then
            echo "============================================================"
            echo "🍎 SUBMIT APPSTORE REVIEW"
            echo "============================================================"
            BUNDLE_ID="${BUNDLE_ID_ARG}"
            if [ -z "$BUNDLE_ID" ]; then read -p "Masukkan Bundle ID Aplikasi (misal: com.domain.app): " BUNDLE_ID; fi
            
            if [ -z "$BUNDLE_ID" ]; then
                echo "❌ Bundle ID tidak boleh kosong."
                exit 1
            fi
            
            ruby "${SCRIPT_DIR}/scripts/submit_appstore_version.rb" "standalone" "Standalone" "$BUNDLE_ID"
            exit 0
        elif [[ "$project_input" =~ ^[Ii]$ ]]; then
            echo "============================================================"
            echo "🍎 SUBMIT PLAYSTORE (FILE AAB)"
            echo "============================================================"
            FILE_PATH="${FILE_PATH_ARG}"
            if [ -z "$FILE_PATH" ]; then read -e -p "Masukkan Path File (.aab): " FILE_PATH; fi
            
            if [ ! -f "$FILE_PATH" ]; then
                echo "❌ File tidak ditemukan: $FILE_PATH"
                exit 1
            fi
            
            echo "🔍 Mengekstrak Package Name dari file AAB..."
            # Cari aapt2 di Android SDK
            AAPT2_PATH=$(find ~/Library/Android/sdk/build-tools -name "aapt2" 2>/dev/null | sort -r | head -n 1)
            
            if [ -z "$AAPT2_PATH" ]; then
                echo "❌ aapt2 tidak ditemukan di Android SDK (~/Library/Android/sdk/build-tools). Tidak dapat mengekstrak Package Name."
                exit 1
            fi
            
            PACKAGE_NAME=$("$AAPT2_PATH" dump packagename "$FILE_PATH" 2>/dev/null | tr -d '\n' | tr -d '\r')
            if [ -z "$PACKAGE_NAME" ]; then
                echo "❌ Gagal mengekstrak Package Name dari AAB. Pastikan file AAB valid."
                exit 1
            fi
            echo "✅ Package Name: $PACKAGE_NAME"
            
            TRACK_INPUT="${TRACK_ARG}"
            if [ -z "$TRACK_INPUT" ]; then read -p "Masukkan track rilis (default: internal): " TRACK_INPUT; fi
            TRACK="${TRACK_INPUT:-internal}"
            
            ruby "${SCRIPT_DIR}/scripts/upload_to_playstore.rb" "$FILE_PATH" "$PACKAGE_NAME" "$TRACK"
            exit 0
        elif [[ "$project_input" =~ ^[Jj]$ ]]; then
            ruby "${SCRIPT_DIR}/scripts/import_project.rb"
            exit 0
        elif [[ "$project_input" =~ ^[Kk]$ ]]; then
            python3 "${SCRIPT_DIR}/scripts/generate_token.py"
            exit 0
        elif [[ "$project_input" =~ ^[Ll]$ ]]; then
            ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "manual"
            exit 0
        fi

        
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
        
# Default flags
OPT_SETUP=false
OPT_BUILD=false
OPT_UPLOAD_DRIVE=false
OPT_UPLOAD_TESTFLIGHT=false
OPT_UPLOAD_PLAYSTORE=false

# Map legacy args to flags
if [ "$UPLOAD_ONLY_MODE" = true ]; then
    if [ "$TESTFLIGHT_MODE" = true ]; then
        OPT_UPLOAD_TESTFLIGHT=true
    else
        OPT_UPLOAD_DRIVE=true
    fi
    SELECTED_TARGETS=("${UPLOAD_ONLY_ID}")
elif [ "$BUILD_ONLY_MODE" = true ]; then
    OPT_BUILD=true
    SELECTED_TARGETS=("${BUILD_ONLY_ID}")
elif [ -n "$RUN_ID" ]; then
    OPT_SETUP=true
    OPT_BUILD=true
    OPT_UPLOAD_DRIVE=true
    SELECTED_TARGETS=("$RUN_ID")
fi

        for TARGET_ID in "${SELECTED_TARGETS[@]}"; do
            # Cek apakah project memiliki lebih dari satu Type (Tanyakan sebelum pilih aksi)
            if command -v jq >/dev/null 2>&1 && jq -e ".\"$TARGET_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
                INTERACTIVE_TYPE=$(jq -r ".\"$TARGET_ID\".Project.Type // empty" "$PROJECT_FILE")
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
                            eval "export FILTERED_TYPE_${clean_target_id}=\"\$NEW_TYPE\""
                        fi
                    fi
                fi
            fi
        done
        tput clear
                                echo "============================================================"
                echo "🛠️ PILIH AKSI UNTUK: ${#SELECTED_TARGETS[@]} Project(s) Terpilih"
                echo "============================================================"
                echo " 1) Setup Konfigurasi"
                echo " 2) Change Icon"
                echo " 3) Rebrand Package Name/Bundle ID"
                echo " 4) Bump Version"
                echo " 5) Clean & Pod Install"
                echo " 6) Update Play Console Dashboard ID"
                echo " 7) Full Deploy iOS (Otomatis jalankan 8-15)"
                echo " 8) Create Appstore"
                echo " 9) Push Metadata (App Store)"
                echo "10) Complete Appstore Info"
                echo "11) Build IPA"
                echo "12) Upload IPA & Submit Testflight"
                echo "13) Submit Testflight (Tanpa Upload)"
                echo "14) Submit Appstore Review"
                echo "15) Request Unlisted Distribution"
                echo "16) Full Deploy Android (Otomatis jalankan 17-24)"
                echo "17) Create Playstore"
                echo "18) Setup Playstore Info"
                echo "19) Upload Playstore Listing"
                echo "20) Build APK"
                echo "21) Upload to Google Drive (APK)"
                echo "22) Build AAB"
                echo "23) Upload Playstore (AAB)"
                echo "24) Submit Playstore (Playwright UI)"
                echo "------------------------------------------------------------"
                if [ -n "$ACTION_CHOICE" ]; then
                    action_choice="$ACTION_CHOICE"
                    echo "Pilihan otomatis (dari argumen): $action_choice"
                else
                    echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 1 22 23): "
                    read -r action_choice
                fi


                if [ -z "$action_choice" ]; then
                    echo "❌ Pilihan tidak valid."
                    exit 1
                fi
                
                if [[ " $action_choice " =~ " 19 " ]] || [[ " $action_choice " =~ " 16 " ]]; then
                    export GLOBAL_METHOD_CHOICE="${METHOD_ARG:-1}"
                fi
    fi
fi

# Fallback untuk mode non-interaktif
if [ "$UPLOAD_ONLY_MODE" = true ]; then
    if [ "$TESTFLIGHT_MODE" = true ]; then
        action_choice="12"
    else
        action_choice="21"
    fi
elif [ "$BUILD_ONLY_MODE" = true ]; then
    action_choice="11 19 22"
elif [ -n "$RUN_ID" ]; then
    # Full default behavior for direct RUN_ID
    action_choice="1 2 3 19 21"
fi

# Jika menggunakan --project, tambahkan ke projects.json
if [ -n "$PROJECT" ] && [ ${#SELECTED_TARGETS[@]} -eq 0 ]; then
    while true; do
        echo "============================================================"
        echo "➕ KONFIRMASI DATA PROJECT BARU"
        echo "============================================================"
        echo "1. Project Key  : ${PROJECT_KEY:-[Auto-generate]}"
        echo "2. Tipe Aplikasi: $TYPE"
        echo "3. Project Name : $PROJECT"
        echo "4. Region       : $REGION"
        echo "5. Base URL     : $BASE_URL"
        echo "6. Database     : $DATABASE"
        echo "7. Branch Name  : ${BRANCH_NAME:-[Sama dengan Project Key]}"
        echo "8. Base Nama App: $APP_NAME"
        echo "9. Firebase Proj: $FIREBASE_PROJECT"
        echo "10. Icon        : $ICON"
        echo "------------------------------------------------------------"
        read -p "Apakah data di atas sudah benar? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            echo "Silakan edit data berikut (tekan Enter untuk menyimpan nilai lama jika tidak diubah):"
            read -p "1. Project Key [${PROJECT_KEY}]: " IN_PROJECT_KEY; PROJECT_KEY="${IN_PROJECT_KEY:-$PROJECT_KEY}"
            read -p "2. Tipe Aplikasi [${TYPE:-HRM Apps}]: " IN_TYPE; TYPE="${IN_TYPE:-${TYPE:-HRM Apps}}"
            read -p "3. Nama Project [${PROJECT}]: " IN_PROJECT; PROJECT="${IN_PROJECT:-$PROJECT}"
            read -p "4. Region [${REGION:-Indonesia}]: " IN_REGION; REGION="${IN_REGION:-${REGION:-Indonesia}}"
            read -p "5. Base URL [${BASE_URL}]: " IN_BASE_URL; BASE_URL="${IN_BASE_URL:-$BASE_URL}"
            read -p "6. Database [${DATABASE}]: " IN_DATABASE; DATABASE="${IN_DATABASE:-$DATABASE}"
            read -p "7. Branch Name [${BRANCH_NAME}]: " IN_BRANCH_NAME; BRANCH_NAME="${IN_BRANCH_NAME:-$BRANCH_NAME}"
            read -p "8. Base Nama Aplikasi [${APP_NAME}]: " IN_APP_NAME; APP_NAME="${IN_APP_NAME:-$APP_NAME}"
            read -p "9. Firebase Project [${FIREBASE_PROJECT}]: " IN_FIREBASE_PROJECT; FIREBASE_PROJECT="${IN_FIREBASE_PROJECT:-$FIREBASE_PROJECT}"
            read -p "10. Icon (URL GDrive / Path Lokal) [${ICON}]: " IN_ICON; ICON="${IN_ICON:-$ICON}"
            echo ""
        fi
    done
    # Generate ID dari Project Name
    if [ -n "$PROJECT_KEY" ]; then
        ID="$PROJECT_KEY"
    else
        ID=$(generate_id "$PROJECT")
        if [ -z "$ID" ]; then
            ID=$(generate_id "$APP_NAME")
            if [ -z "$ID" ]; then ID="default_id"; fi
        fi
    fi
    
    if [ -n "$BRANCH_NAME" ]; then
        BRANCH="$BRANCH_NAME"
    else
        BRANCH="$ID"
    fi
    
    BRANCH_JSON="{"
    APP_NAME_JSON="{"
    PACKAGE_ID_JSON="{"
    BUNDLE_ID_JSON="{"
    PLAY_CONSOLE_JSON="{"
    
    IFS=',' read -ra ADDR <<< "$TYPE"
    for i in "${!ADDR[@]}"; do
        type_clean=$(echo "${ADDR[$i]}" | xargs)
        BRANCH_JSON+="\"$type_clean\": \"$BRANCH\""
        PLAY_CONSOLE_JSON+="\"$type_clean\": \"\""
        
        if [[ "$type_clean" == "Approval Apps" ]]; then
            APP_NAME_VAL="${APP_NAME} Approval"
            PKG_VAL="com.hashmicro.approval.${ID}"
        elif [[ "$type_clean" == "HRM Apps" ]]; then
            APP_NAME_VAL="${APP_NAME} HRIS"
            PKG_VAL="com.hashmicro.eva.${ID}"
        else
            APP_NAME_VAL="${APP_NAME}"
            PKG_VAL="com.hashmicro.eva.${ID}"
        fi
        APP_NAME_JSON+="\"$type_clean\": \"$APP_NAME_VAL\""
        PACKAGE_ID_JSON+="\"$type_clean\": \"$PKG_VAL\""
        BUNDLE_ID_JSON+="\"$type_clean\": \"$PKG_VAL\""

        if [ $i -lt $((${#ADDR[@]}-1)) ]; then 
            BRANCH_JSON+=", "
            APP_NAME_JSON+=", "
            PACKAGE_ID_JSON+=", "
            BUNDLE_ID_JSON+=", "
            PLAY_CONSOLE_JSON+=", "
        fi
    done
    BRANCH_JSON+="}"
    APP_NAME_JSON+="}"
    PACKAGE_ID_JSON+="}"
    BUNDLE_ID_JSON+="}"
    PLAY_CONSOLE_JSON+="}"

    if [ -n "$BASE_URL" ]; then
        RAW_URL=$(echo "$BASE_URL" | tr ',' ' ' | tr ' ' '\n' | grep '\.' | tail -n 1)
        CLEAN_URL=$(echo "$RAW_URL" | sed -E 's|^https?://||' | cut -d '/' -f 1)
        BASE_URL="https://${CLEAN_URL}"
    fi

    if [ ! -s "$PROJECT_FILE" ]; then echo "{}" > "$PROJECT_FILE"; fi

    if command -v jq >/dev/null 2>&1; then
        NEW_PROJECT=$(jq -n \
          --arg id "$ID" \
          --argjson branch "$BRANCH_JSON" \
          --arg pn "$PROJECT" \
          --arg r "$REGION" \
          --argjson an "$APP_NAME_JSON" \
          --arg t "$TYPE" \
          --arg bu "$BASE_URL" \
          --arg db "$DATABASE" \
          --arg ic "$ICON" \
          --arg fp "$FIREBASE_PROJECT" \
          --argjson pkg "$PACKAGE_ID_JSON" \
          --argjson bdl "$BUNDLE_ID_JSON" \
          --argjson pc "$PLAY_CONSOLE_JSON" \
          '{
            ($id): {
              "Branch": $branch,
              "Play Console Dashboard": $pc,
              "Firebase Project": $fp,
              "Project": {
                "Project Name": $pn,
                "Region": $r,
                "App Name": $an,
                "Type": $t,
                "Base URL": $bu,
                "Database": $db,
                "Icon": $ic
              },
              "Package ID": $pkg,
              "Bundle ID": $bdl
            }
          }')
        jq --argjson newProj "$NEW_PROJECT" '. * $newProj' "$PROJECT_FILE" > "${PROJECT_FILE}.tmp" && mv "${PROJECT_FILE}.tmp" "$PROJECT_FILE"
        echo "✓ Project '$ID' berhasil ditambahkan/diperbarui di projects.json!"
    else
        echo "⚠️ Peringatan: Program 'jq' tidak ditemukan."
    fi
    SELECTED_TARGETS=("$ID")
fi

if [ -z "$action_choice" ]; then
    trap - EXIT
    exit 0
fi

# Parsing ACTION ARRAY
IFS=' ' read -ra ACTION_ARRAY <<< "$(echo "$action_choice" | tr ',' ' ')"

# Global setup untuk Playwright
if [[ " ${ACTION_ARRAY[*]} " =~ " 6 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 16 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 17 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 18 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 19 " ]] || [[ " ${ACTION_ARRAY[*]} " =~ " 24 " ]]; then
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

upload_drive() {
    local target_dir="$1"
    local p_type="$2"
    local proj="$3"
    local a_name="$4"
    
    local gdrive_folder_id=""
    if [ -f "${SCRIPT_DIR}/config.json" ]; then
        gdrive_folder_id=$(jq -r ".types[\"$p_type\"].gdrive_folder_id // empty" "${SCRIPT_DIR}/config.json")
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
            nohup bash -c "sleep 300 && cd \"${SCRIPT_DIR}\" && SKIP_UPLOAD=true ./release.sh -t \"$t_id\"" > "${SCRIPT_DIR}/testflight_retry.log" 2>&1 &
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
        bash "${SCRIPT_DIR}/init_appstore.sh" "$t_id" "$t_clean" || { echo "❌ Proses init appstore gagal!"; exit 1; }
    fi
}

execute_action() {
    local action="$1"
    
    for TARGET_ID in "${SELECTED_TARGETS[@]}"; do
        if ! command -v jq >/dev/null 2>&1 || ! jq -e ".\"$TARGET_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
            echo "❌ Error: Project dengan ID '$TARGET_ID' tidak ditemukan di projects.json."
            continue
        fi
        
        echo "============================================================"
        echo "🚀 MEMPROSES PROJECT: $TARGET_ID"
        echo "============================================================"
        
        # Target-level actions
        case "$action" in
            6) 
                node "${SCRIPT_DIR}/automation/update_dashboard_id.js" "$TARGET_ID" || echo "❌ update_dashboard_id.js gagal dijalankan."
                continue
                ;;
            17) 
                if node "${SCRIPT_DIR}/automation/create_app.js" "$TARGET_ID"; then
                    echo "✅ create_app.js berhasil"
                else
                    echo "❌ create_app.js gagal dijalankan."
                fi
                continue
                ;;
            18) 
                node "${SCRIPT_DIR}/automation/runner_app_info.js" "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                continue
                ;;
            24) 
                node "${SCRIPT_DIR}/automation/submit_playstore.js" "$TARGET_ID" || echo "❌ submit_playstore.js gagal dijalankan."
                continue
                ;;
        esac
        
        clean_target_id=$(echo "$TARGET_ID" | tr '-' '_')
        dynamic_type=$(eval echo "\$FILTERED_TYPE_${clean_target_id}")
        if [ -z "$dynamic_type" ]; then
            ACTIVE_TYPES=$(jq -r ".\"$TARGET_ID\".Project.Type // empty" "$PROJECT_FILE")
        else
            ACTIVE_TYPES="$dynamic_type"
        fi
        IFS=',' read -ra ACTIVE_TYPES_ARR <<< "$ACTIVE_TYPES"
        
        for current_type in "${ACTIVE_TYPES_ARR[@]}"; do
            type_clean=$(echo "$current_type" | xargs)
            type_slug=$(echo "$type_clean" | tr 'A-Z' 'a-z' | tr ' ' '_')
            
            CONFIG_FILE="${SCRIPT_DIR}/config.json"
            META_JSON=$(node "${SCRIPT_DIR}/scripts/app_meta.js" "$TARGET_ID" "" "$type_clean" "$CONFIG_FILE")
            APP_PACKAGE_NAME=$(echo "$META_JSON" | jq -r '.packageName')
            APP_NAME=$(echo "$META_JSON" | jq -r '.appName')
            PRIMARY_TYPE=$(echo "$META_JSON" | jq -r '.primaryType')
            PROJECT_NAME=$(jq -r ".\"$TARGET_ID\".Project.\"Project Name\" // empty" "$PROJECT_FILE")
            TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT_NAME}/${type_clean}"
            
            echo "============================================================"
            echo "⚙️ MENJALANKAN OPSI $action UNTUK: $type_clean ($APP_NAME)"
            echo "============================================================"
            
            case "$action" in
                1) 
                   script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
                   if [ -f "$script_file" ]; then
                       REGION=$(jq -r ".\"$TARGET_ID\".Project.Region // empty" "$PROJECT_FILE")
                       BASE_URL=$(jq -r ".\"$TARGET_ID\".Project.\"Base URL\" // empty" "$PROJECT_FILE")
                       DATABASE=$(jq -r ".\"$TARGET_ID\".Project.Database // empty" "$PROJECT_FILE")
                       bash "$script_file" "$TARGET_ID" "$REGION" "$APP_NAME" "$type_clean" "$BASE_URL" "$DATABASE" "$APP_PACKAGE_NAME" || { echo "❌ Proses setup $type_clean gagal!"; exit 1; }
                   fi
                   ;;
                2)
                   ICON_URL=$(jq -r ".\"$TARGET_ID\".Project.Icon // empty" "$PROJECT_FILE")
                   if [ -n "$ICON_URL" ]; then
                       bash "${SCRIPT_DIR}/scripts/prepare-icon.sh" "$ICON_URL"
                   fi
                   
                   RAW_LOCATION=$(jq -r ".types[\"$PRIMARY_TYPE\"].location // empty" "$CONFIG_FILE")
                   APP_LOCATION=$(eval echo "$RAW_LOCATION")
                   OPTIMIZED_ICON="${SCRIPT_DIR}/icon/icon.png"
                   if [ -n "$APP_LOCATION" ] && [ -d "$APP_LOCATION" ] && [ -f "$OPTIMIZED_ICON" ]; then
                       echo "  🖼️  Menerapkan icon kustom ke project $APP_LOCATION..."
                       mkdir -p "${APP_LOCATION}/icon"
                       cp "$OPTIMIZED_ICON" "${APP_LOCATION}/icon/icon.png"
                       
                       cd "$APP_LOCATION" || exit 1
                       if command -v fvm >/dev/null 2>&1; then
                           fvm flutter pub get >/dev/null 2>&1
                           fvm dart run flutter_launcher_icons >/dev/null 2>&1
                       else
                           flutter pub get >/dev/null 2>&1
                           dart run flutter_launcher_icons >/dev/null 2>&1
                       fi
                       
                       ADAPTIVE_ICON_DIR="android/app/src/main/res/mipmap-anydpi-v26"
                       if [ -d "$ADAPTIVE_ICON_DIR" ]; then
                           rm -rf "$ADAPTIVE_ICON_DIR"
                           echo "  🗑️  Removed $ADAPTIVE_ICON_DIR to prevent blank adaptive icon"
                       fi
                       cd "${SCRIPT_DIR}" || exit 1
                       echo "  ✅ Icon berhasil diperbarui di project."
                   fi
                   ;;
                3)
                   bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }
                   ;;
                4) ruby "${SCRIPT_DIR}/scripts/bump_version.rb" "$TARGET_ID" "$type_clean" || echo "❌ bump_version.rb gagal dijalankan." ;;
                5) 
                   RAW_LOCATION=$(jq -r ".types[\"$PRIMARY_TYPE\"].location // empty" "$CONFIG_FILE")
                   APP_LOCATION=$(eval echo "$RAW_LOCATION")
                   if [ -z "$APP_LOCATION" ] || [ ! -d "$APP_LOCATION" ]; then
                       echo "❌ Folder project untuk tipe $PRIMARY_TYPE tidak ditemukan ($APP_LOCATION)"
                       exit 1
                   fi
                   
                   echo "🧹 Menjalankan fvm flutter clean & pub get di $APP_LOCATION..."
                   cd "$APP_LOCATION" || exit 1
                   fvm flutter clean || { echo "❌ fvm flutter clean gagal!"; exit 1; }
                   fvm flutter pub get || { echo "❌ fvm flutter pub get gagal!"; exit 1; }
                   echo "📦 Menjalankan pod install untuk iOS..."
                   cd ios || { echo "❌ Folder ios tidak ditemukan di $APP_LOCATION!"; exit 1; }
                   rm -f Podfile.lock
                   pod install || { echo "❌ pod install gagal!"; exit 1; }
                   cd "${SCRIPT_DIR}" || exit 1
                   ;;
                8) 
                   if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then
                       bash "${SCRIPT_DIR}/init_appstore.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses init appstore gagal!"; exit 1; }
                   fi
                   ;;
                9) ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ push_appstore_metadata.rb gagal dijalankan." ;;
                10) ruby "${SCRIPT_DIR}/scripts/setup_appstore_info.rb" "$TARGET_ID" "$type_clean" || echo "❌ setup_appstore_info.rb gagal dijalankan." ;;
                11) 
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_IPA=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"; exit 1
                   fi
                   ;;
                12) 
                   echo "🍎 MENGUNGGAH KE APP STORE CONNECT / TESTFLIGHT: $APP_NAME"
                   upload_testflight "$TARGET_DIR" "$TARGET_ID" "$APP_PACKAGE_NAME" "$APP_NAME" "$type_clean"
                   ;;
                13) 
                   echo "🍎 SUBMIT TESTFLIGHT (TANPA UPLOAD): $APP_NAME"
                   SKIP_UPLOAD=true upload_testflight "$TARGET_DIR" "$TARGET_ID" "$APP_PACKAGE_NAME" "$APP_NAME" "$type_clean"
                   ;;
                14) ruby "${SCRIPT_DIR}/scripts/submit_appstore_version.rb" "$TARGET_ID" "$type_clean" "$APP_PACKAGE_NAME" || echo "❌ submit_appstore_version.rb gagal dijalankan." ;;
                15) ruby "${SCRIPT_DIR}/scripts/request_unlisted_app.rb" "$TARGET_ID" "$type_clean" "$APP_PACKAGE_NAME" || echo "❌ request_unlisted_app.rb gagal dijalankan." ;;
                19) 
                   if [[ "${GLOBAL_METHOD_CHOICE:-1}" == "2" ]]; then
                       node "${SCRIPT_DIR}/automation/runner_store_listing.js" "$TARGET_ID" || echo "❌ runner_store_listing.js gagal dijalankan."
                   else
                       ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$type_clean" || echo "❌ update_store_listing.rb gagal dijalankan."
                   fi
                   ;;
                20) 
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_APK=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"; exit 1
                   fi
                   ;;
                21) 
                   echo "🚀 MENGUNGGAH APK KE GOOGLE DRIVE: $APP_NAME"
                   upload_drive "$TARGET_DIR" "$PRIMARY_TYPE" "$PROJECT_NAME" "$APP_NAME"
                   ;;
                22) 
                   if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
                       BUILD_TARGET_AAB=true SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean" || { echo "❌ Proses build gagal!"; exit 1; }
                   else
                       echo "❌ Script build_app.sh tidak ditemukan!"; exit 1
                   fi
                   ;;
                23) 
                   ruby "${SCRIPT_DIR}/scripts/submit_playstore_version.rb" "$TARGET_ID" "$type_clean" || { echo "❌ Proses upload Play Store gagal!"; exit 1; }
                   ;;
            esac
        done
    done
}

for CURRENT_ACTION in "${ACTION_ARRAY[@]}"; do
    if [ -z "$CURRENT_ACTION" ]; then
        continue
    fi
    
    if [ "$CURRENT_ACTION" = "7" ]; then
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: 7 (FULL DEPLOY iOS)"
        echo "============================================================"
        for sub_action in 8 9 10 11 12 14 15; do
            execute_action "$sub_action"
        done
    elif [ "$CURRENT_ACTION" = "16" ]; then
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: 16 (FULL DEPLOY ANDROID)"
        echo "============================================================"
        for sub_action in 17 18 19 20 21 22 23 24; do
            execute_action "$sub_action"
        done
    else
        echo "============================================================"
        echo "▶️ MENGEKSEKUSI OPSI: $CURRENT_ACTION"
        echo "============================================================"
        execute_action "$CURRENT_ACTION"
    fi
done

echo ""
echo "============================================================"
echo "✅ SEMUA PROSES SELESAI!"
echo "============================================================"
exit 0
