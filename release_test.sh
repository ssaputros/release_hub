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
        *) 
            # Jika argumen tidak diawali '--' dan RUN_ID masih kosong, anggap itu ID project
            if [[ "$1" != --* ]] && [ -z "$RUN_ID" ]; then
                RUN_ID="$1"
            else
                echo "Error: Parameter tidak dikenal '$1'"
                exit 1
            fi
            ;;
    esac
    shift
done

# Fungsi untuk membuat ID (gabungan teks, lowercase, tanpa special char)
generate_id() {
    # Menghapus spasi dan semua karakter non-alfanumerik, lalu ubah ke lowercase
    echo "$1" | sed 's/[^a-zA-Z0-9]//g' | tr 'A-Z' 'a-z'
}


# Setel opsi Ruby untuk menyembunyikan warning bawaan (seperti error ekstensi belum di-build)
export RUBYOPT="-W0"

# Trap function untuk membersihkan temporary files dan memainkan suara ketika script berhenti
on_exit() {
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
                echo " 1) Full (Semua proses Utama)"
                echo " 2) Setup Konfigurasi"
                echo " 3) Bump Version"
                echo " 4) Record Playwright UI"
                echo " 5) Upload APK & IPA ke Google Drive"
                echo " 6) Build APK & AAB"
                echo " 7) Create Playstore App"
                echo " 8) Setup Playstore App Information"
                echo " 9) Setup Store Listing"
                echo "10) Push Playstore Listing"
                echo "11) Download Play Store Metadata"
                echo "12) Update Play Console Dashboard ID"
                echo "21) Upload AAB ke Play Store"
                echo "22) Build AAB Saja"
                echo "13) Build IPA"
                echo "14) Upload TestFlight"
                echo "15) Submit TestFlight (Lewati Upload IPA)"
                echo "16) Setup App Store Info"
                echo "17) Push App Store Metadata"
                echo "18) Download App Store Metadata"
                echo "19) Request Unlisted App Distribution"
                echo "20) Submit for App Review"
                echo "------------------------------------------------------------"
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 6 9 13): "
                read -r action_choice

                # Ganti koma dengan spasi dan tambahkan spasi di awal/akhir agar pengecekan angka lebih aman (mencegah 10 terbaca sebagai 1)
                clean_choice=" $(echo "$action_choice" | tr ',' ' ') "


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
            
            # Ambil META informasi untuk project dan tipe ini
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
                2) # Setup Konfigurasi
                   bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }
                   script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
                   if [ -f "$script_file" ]; then
                       REGION=$(jq -r ".\"$TARGET_ID\".Project.Region // empty" "$PROJECT_FILE")
                       BASE_URL=$(jq -r ".\"$TARGET_ID\".Project.\"Base URL\" // empty" "$PROJECT_FILE")
                       DATABASE=$(jq -r ".\"$TARGET_ID\".Project.Database // empty" "$PROJECT_FILE")
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
