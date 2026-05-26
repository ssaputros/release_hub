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
        local_input=""
        local_char=""
        
        # Ekstrak data project HANYA SEKALI di luar loop untuk menghindari lag (debounce issue)
        projects_data=$(jq -r 'to_entries | .[] | "\(.key)|\(.value.Project["Project Name"])"' "$PROJECT_FILE")
        
        tput civis
        
        while true; do
            tput clear
            
            echo "============================================================"
            echo "📋 DAFTAR PROJECT"
            echo "============================================================"
            
            match_count=0
            first_match=""
            exact_match=""
            no=1
            
            input_lower=$(echo "$local_input" | tr 'A-Z' 'a-z')
            
            while IFS="|" read -r pid pname; do
                pid_lower=$(echo "$pid" | tr 'A-Z' 'a-z')
                pname_lower=$(echo "$pname" | tr 'A-Z' 'a-z')
                
                if [[ -z "$input_lower" || "$no" == "$input_lower"* || "$pid_lower" == *"$input_lower"* || "$pname_lower" == *"$input_lower"* ]]; then
                    printf "%-3s %-20s %s\n" "$no." "$pid" "$pname"
                    if [ $match_count -eq 0 ]; then
                        first_match="$pid"
                    fi
                    if [[ "$no" == "$input_lower" || "$pid_lower" == "$input_lower" ]]; then
                        exact_match="$pid"
                    fi
                    ((match_count++))
                fi
                ((no++))
            done <<< "$projects_data"
            
            echo "------------------------------------------------------------"
            echo -n "Masukkan Project ID (Tab untuk auto-complete): $local_input"
            
            # Mulai baca input pertama (blocking)
            IFS= read -r -s -n 1 local_char
            
            # Loop kecil untuk memproses input cepat / debounce
            while true; do
                if [[ -z "$local_char" ]]; then
                    if [ -n "$exact_match" ]; then
                        local_input="$exact_match"
                    elif [ -n "$first_match" ]; then
                        local_input="$first_match"
                    fi
                    echo
                    break 2
                elif [[ "$local_char" == $'\x09' ]]; then
                    if [ -n "$exact_match" ]; then
                        local_input="$exact_match"
                    elif [ -n "$first_match" ]; then
                        local_input="$first_match"
                    fi
                elif [[ "$local_char" == $'\x7f' || "$local_char" == $'\b' || "$local_char" == $'\177' ]]; then
                    if [ ${#local_input} -gt 0 ]; then
                        local_input="${local_input%?}"
                    fi
                elif [[ "$local_char" == $'\e' ]]; then
                    # Deteksi sequence seperti Delete (\e[3~) atau Arrow Keys
                    if IFS= read -r -s -n 2 -t 0.05 seq; then
                        if [[ "$seq" == "[3" ]]; then
                            IFS= read -r -s -n 1 -t 0.05 seq2
                            if [[ "$seq2" == "~" ]] && [ ${#local_input} -gt 0 ]; then
                                local_input="${local_input%?}"
                            fi
                        fi
                    fi
                else
                    # Karakter biasa
                    if [[ "$local_char" == [[:print:]] ]]; then
                        local_input="${local_input}${local_char}"
                    fi
                fi
                
                # Debounce: Coba baca input selanjutnya. Jika tidak ada yang diketik dalam 0.3s, keluar loop dan render ulang
                if ! IFS= read -r -s -n 1 -t 0.3 local_char; then
                    break
                fi
            done
        done
        
        tput cnorm
        
# Default flags
OPT_SETUP=false
OPT_BUILD=false
OPT_UPLOAD_DRIVE=false
OPT_UPLOAD_TESTFLIGHT=false

# Map legacy args to flags
if [ "$UPLOAD_ONLY_MODE" = true ]; then
    if [ "$TESTFLIGHT_MODE" = true ]; then
        OPT_UPLOAD_TESTFLIGHT=true
    else
        OPT_UPLOAD_DRIVE=true
    fi
    TARGET_ID="${UPLOAD_ONLY_ID}"
elif [ "$BUILD_ONLY_MODE" = true ]; then
    OPT_BUILD=true
    TARGET_ID="${BUILD_ONLY_ID}"
elif [ -n "$RUN_ID" ]; then
    OPT_SETUP=true
    OPT_BUILD=true
    OPT_UPLOAD_DRIVE=true
    TARGET_ID="$RUN_ID"
fi
        if [ -n "$local_input" ]; then
            if [ "$UPLOAD_ONLY_MODE" = true ]; then
                TARGET_ID="$local_input"
            elif [ "$BUILD_ONLY_MODE" = true ]; then
                TARGET_ID="$local_input"
            else
                TARGET_ID="$local_input"
                tput clear
                
                # Cek apakah project memiliki lebih dari satu Type (Tanyakan sebelum pilih aksi)
                if command -v jq >/dev/null 2>&1 && jq -e ".\"$TARGET_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
                    INTERACTIVE_TYPE=$(jq -r ".\"$TARGET_ID\".Project.Type // empty" "$PROJECT_FILE")
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
                        tput clear
                    fi
                fi

                echo "============================================================"
                echo "🛠️ PILIH AKSI UNTUK: $local_input"
                echo "============================================================"
                echo "1) Full (Semua proses)"
                echo "2) Setup Konfigurasi"
                echo "3) Build APK & AAB"
                echo "4) Build IPA"
                echo "5) Upload Drive"
                echo "6) Upload TestFlight"
                echo "7) Submit TestFlight (Lewati Upload IPA)"
                echo "8) Create Playstore App"
                echo "9) Setup Playstore App Information"
                echo "10) Setup Store Listing"
                echo "11) Record Playwright UI"
                echo "12) Update Play Console Dashboard ID"
                echo "13) Bump Version"
                echo "14) Push Playstore Listing"
                echo "15) Download App Store Metadata"
                echo "16) Push App Store Metadata"
                echo "17) Download Play Store Metadata"
                echo "------------------------------------------------------------"
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 3 5 12): "
                read -r action_choice

                # Ganti koma dengan spasi dan tambahkan spasi di awal/akhir agar pengecekan angka lebih aman (mencegah 10 terbaca sebagai 1)
                clean_choice=" $(echo "$action_choice" | tr ',' ' ') "

                if [[ "$clean_choice" == *" 1 "* ]]; then
                    OPT_SETUP=true
                    OPT_BUILD=true
                    export BUILD_TARGET_APK=true
                    export BUILD_TARGET_IPA=true
                    OPT_UPLOAD_DRIVE=true
                    OPT_UPLOAD_TESTFLIGHT=true
                else
                    if [[ "$clean_choice" == *" 2 "* ]]; then OPT_SETUP=true; fi
                    if [[ "$clean_choice" == *" 3 "* ]]; then OPT_BUILD=true; export BUILD_TARGET_APK=true; fi
                    if [[ "$clean_choice" == *" 4 "* ]]; then OPT_BUILD=true; export BUILD_TARGET_IPA=true; fi
                    if [[ "$clean_choice" == *" 5 "* ]]; then OPT_UPLOAD_DRIVE=true; fi
                    if [[ "$clean_choice" == *" 6 "* ]]; then OPT_UPLOAD_TESTFLIGHT=true; fi
                    if [[ "$clean_choice" == *" 7 "* ]]; then 
                        OPT_UPLOAD_TESTFLIGHT=true
                        export SKIP_UPLOAD=true
                    fi

                    if [[ "$clean_choice" == *" 8 "* ]] || [[ "$clean_choice" == *" 9 "* ]] || [[ "$clean_choice" == *" 10 "* ]] || [[ "$clean_choice" == *" 11 "* ]] || [[ "$clean_choice" == *" 12 "* ]] || [[ "$clean_choice" == *" 13 "* ]] || [[ "$clean_choice" == *" 14 "* ]] || [[ "$clean_choice" == *" 15 "* ]] || [[ "$clean_choice" == *" 16 "* ]] || [[ "$clean_choice" == *" 17 "* ]]; then
                        echo "============================================================"
                        echo "🤖 MENYIAPKAN AUTOMASI / SETUP STORE"
                        echo "============================================================"
                        
                        # Hanya install dan masuk ke folder automation jika memilih opsi Playwright
                        if [[ "$clean_choice" == *" 8 "* ]] || [[ "$clean_choice" == *" 9 "* ]] || [[ "$clean_choice" == *" 10 "* ]] || [[ "$clean_choice" == *" 11 "* ]] || [[ "$clean_choice" == *" 12 "* ]]; then
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
                        fi
                        
                        if [[ "$clean_choice" == *" 12 "* ]]; then
                            node update_dashboard_id.js "$TARGET_ID" || echo "❌ update_dashboard_id.js gagal dijalankan."
                        fi
                        
                        if [[ "$clean_choice" == *" 8 "* ]]; then
                            if node create_app.js "$TARGET_ID"; then
                                if [[ "$clean_choice" != *" 9 "* ]]; then
                                    echo "🚀 Otomatis melanjutkan ke Setup Playstore App Information (Langkah 9)..."
                                    node runner_app_info.js "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                                fi
                            else
                                echo "❌ create_app.js gagal dijalankan."
                            fi
                        fi
                        
                        if [[ "$clean_choice" == *" 9 "* ]]; then
                            node runner_app_info.js "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                        fi

                        if [[ "$clean_choice" == *" 10 "* ]]; then
                            echo "============================================================"
                            echo "🛠️ PILIH METODE SETUP STORE LISTING"
                            echo "============================================================"
                            echo "1) Fastlane API (Direct upload, cepat & tanpa browser)"
                            echo "2) Playwright Browser (Semi-otomatis lewat UI browser)"
                            echo "------------------------------------------------------------"
                            echo -n "Pilihan Anda (default: 1): "
                            read -r method_choice
                            
                            if [[ "$method_choice" == "2" ]]; then
                                node runner_store_listing.js "$TARGET_ID" || echo "❌ runner_store_listing.js gagal dijalankan."
                            else
                                ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$FILTERED_TYPE" || echo "❌ update_store_listing.rb gagal dijalankan."
                            fi
                        fi

                        if [[ "$clean_choice" == *" 11 "* ]]; then
                            echo "🎥 Membuka Playwright Inspector..."
                            npm run record
                        fi
                        
                        # Kembali ke direktori utama
                        cd "${SCRIPT_DIR}" || exit 1
                        
                        if [[ "$clean_choice" == *" 13 "* ]]; then
                            ruby "${SCRIPT_DIR}/scripts/bump_version.rb" "$TARGET_ID" || echo "❌ bump_version.rb gagal dijalankan."
                        fi

                        if [[ "$clean_choice" == *" 14 "* ]]; then
                            ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$FILTERED_TYPE" || echo "❌ update_store_listing.rb gagal dijalankan."
                        fi

                        if [[ "$clean_choice" == *" 15 "* ]]; then
                            ruby "${SCRIPT_DIR}/scripts/download_appstore_metadata.rb" "$TARGET_ID" "$FILTERED_TYPE" || echo "❌ download_appstore_metadata.rb gagal dijalankan."
                        fi

                        if [[ "$clean_choice" == *" 16 "* ]]; then
                            ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "$TARGET_ID" "$FILTERED_TYPE" || echo "❌ push_appstore_metadata.rb gagal dijalankan."
                        fi

                        if [[ "$clean_choice" == *" 17 "* ]]; then
                            ruby "${SCRIPT_DIR}/scripts/download_playstore_metadata.rb" "$TARGET_ID" "$FILTERED_TYPE" || echo "❌ download_playstore_metadata.rb gagal dijalankan."
                        fi
                        exit 0
                    fi
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
        if [ -n "$FILTERED_TYPE" ]; then
            TYPE="$FILTERED_TYPE"
        fi
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
          --arg branch "$BRANCH" \
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

# Jika tidak ada opsi eksekusi yang aktif (hanya menambahkan project), maka keluar dengan bersih
if [ "$OPT_SETUP" != true ] && [ "$OPT_BUILD" != true ] && [ "$OPT_UPLOAD_DRIVE" != true ] && [ "$OPT_UPLOAD_TESTFLIGHT" != true ] && [ "$UPLOAD_ONLY_MODE" != true ] && [ "$BUILD_ONLY_MODE" != true ]; then
    trap - EXIT
    exit 0
fi

# Gunakan script general (app_meta.js) untuk memproses Package Name dan App Name
CONFIG_FILE="${SCRIPT_DIR}/config.json"
META_JSON=$(node "${SCRIPT_DIR}/scripts/app_meta.js" "$ID" "$APP_NAME" "$TYPE" "$CONFIG_FILE")
APP_PACKAGE_NAME=$(echo "$META_JSON" | jq -r '.packageName')
APP_NAME=$(echo "$META_JSON" | jq -r '.appName')
PRIMARY_TYPE=$(echo "$META_JSON" | jq -r '.primaryType')


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

    # Eksekusi script setup dinamis berdasarkan Type
    IFS=',' read -ra ADDR <<< "$TYPE"
    for type_item in "${ADDR[@]}"; do
        type_clean=$(echo "$type_item" | xargs)
        type_slug=$(echo "$type_clean" | tr 'A-Z' 'a-z' | tr ' ' '_')
        
        script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
        
        if [ -f "$script_file" ]; then
            echo "============================================================"
            echo "⚙️ SETUP PROJECT: $type_clean"
            echo "============================================================"
            bash "$script_file" "$ID" "$REGION" "$APP_NAME" "$type_clean" "$BASE_URL" "$DATABASE" "$APP_PACKAGE_NAME" || { echo "❌ Proses setup $type_clean gagal!"; exit 1; }
            echo "============================================================"
        fi
    done

    if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then
        bash "${SCRIPT_DIR}/init_appstore.sh" "$ID" || { echo "❌ Proses init appstore gagal!"; exit 1; }
    fi
fi

# STAGE 2: BUILD
if [ "$OPT_BUILD" = true ]; then
    if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
        SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$ID" || { echo "❌ Proses build gagal!"; exit 1; }
    else
        echo "❌ Script build_app.sh tidak ditemukan!"
        exit 1
    fi
fi

# STAGE 3: UPLOAD
TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT}"

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
        GDRIVE_FOLDER_ID=$(jq -r ".types[\"$PRIMARY_TYPE\"].gdrive_folder_id // empty" "$CONFIG_FILE")
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
        ruby_exit_code=$?
        
        if [ $ruby_exit_code -eq 2 ]; then
            echo "🕒 Menjadwalkan submit ulang TestFlight dalam 5 menit..."
            nohup bash -c "sleep 300 && cd \"${SCRIPT_DIR}\" && SKIP_UPLOAD=true ./release.sh -t \"$ID\"" > "${SCRIPT_DIR}/testflight_retry.log" 2>&1 &
            PID=$!
            echo "$PID|$ID|$APP_NAME|$(date +%s)" >> "${SCRIPT_DIR}/.schedulers"
            echo "✅ Penjadwalan berhasil (proses berjalan di background dengan PID: $PID)."
        elif [ $ruby_exit_code -ne 0 ]; then
            echo "❌ Upload ke TestFlight gagal."
            exit 1
        fi
    else
        echo "⚠️ File IPA tidak ditemukan di $TARGET_DIR"
        exit 1
    fi
fi
