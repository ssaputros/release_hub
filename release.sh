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
    echo "  -u, --upload [ID]     Hanya mengunggah build terakhir (upload only) ke Google Drive. Bisa juga tanpa ID untuk memilih interaktif."
    echo "  -t, --testflight [ID] Hanya mengunggah IPA terakhir ke TestFlight External dan generate Public Link."
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
    echo "  release --project 'PT Baru' --app-name 'Baru HRIS' --type 'HRM Apps' --base-url 'https://api.baru.com' --database 'baru_db'"
    exit 0
}

# Looping untuk mem-parsing argumen
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
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

# Path file projects.json (satu folder dengan script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

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


if [ -z "$RUN_ID" ] && [ -z "$PROJECT" ] && [ -z "$UPLOAD_ONLY_ID" ]; then
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
        
        if [ -n "$local_input" ]; then
            if [ "$UPLOAD_ONLY_MODE" = true ]; then
                UPLOAD_ONLY_ID="$local_input"
            else
                RUN_ID="$local_input"
            fi
        else
            echo "❌ Batal memilih project."
            exit 0
        fi
    fi
fi

if [ -n "$UPLOAD_ONLY_ID" ]; then
    echo "============================================================"
    echo "🚀 MENGUNGGAH FILE BUILD: $UPLOAD_ONLY_ID"
    echo "============================================================"
    
    if command -v jq >/dev/null 2>&1 && [ -f "$PROJECT_FILE" ]; then
        if ! jq -e ".\"$UPLOAD_ONLY_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
            echo "❌ Error: Project '$UPLOAD_ONLY_ID' tidak ditemukan di projects.json"
            exit 1
        fi
        
        PROJECT=$(jq -r ".\"$UPLOAD_ONLY_ID\".Project.\"Project Name\" // empty" "$PROJECT_FILE")
        APP_NAME=$(jq -r ".\"$UPLOAD_ONLY_ID\".Project.\"App Name\" // empty" "$PROJECT_FILE")
        TYPE=$(jq -r ".\"$UPLOAD_ONLY_ID\".Project.Type // empty" "$PROJECT_FILE")
        TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT}"

        if [ ! -d "$TARGET_DIR" ]; then
            echo "❌ Error: Folder $TARGET_DIR tidak ditemukan."
            exit 1
        fi

        if [ "$TESTFLIGHT_MODE" = true ]; then
            echo "🍎 MENGUNGGAH KE TESTFLIGHT: $APP_NAME"
            LATEST_IPA=$(find "$TARGET_DIR" -name "*.ipa" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
            
            if [ -n "$LATEST_IPA" ]; then
                # Get Prefix from config.json based on App Type
                CONFIG_FILE="${SCRIPT_DIR}/config.json"
                PREFIX=""
                if command -v jq >/dev/null 2>&1 && [ -f "$CONFIG_FILE" ]; then
                    PREFIX=$(jq -r ".types[\"$TYPE\"].prefix // empty" "$CONFIG_FILE")
                fi
                if [ -z "$PREFIX" ]; then
                    PREFIX="com.example"
                fi
                APP_PACKAGE_NAME="${PREFIX}.${UPLOAD_ONLY_ID}"

                ruby "${SCRIPT_DIR}/scripts/upload_to_testflight.rb" "$LATEST_IPA" "$APP_PACKAGE_NAME" "$APP_NAME" "$TYPE"
            else
                echo "⚠️ File IPA tidak ditemukan di $TARGET_DIR"
                exit 1
            fi
        else
            CONFIG_FILE="${SCRIPT_DIR}/config.json"
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
        
        exit 0
    else
        echo "❌ Error: jq tidak ditemukan atau projects.json tidak valid."
        exit 1
    fi
fi

if [ -n "$RUN_ID" ]; then
    if command -v jq >/dev/null 2>&1 && jq -e ".\"$RUN_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
        echo "🚀 Mengeksekusi project terdaftar: $RUN_ID"
        PROJECT=$(jq -r ".\"$RUN_ID\".Project.\"Project Name\" // empty" "$PROJECT_FILE")
        REGION=$(jq -r ".\"$RUN_ID\".Project.Region // empty" "$PROJECT_FILE")
        APP_NAME=$(jq -r ".\"$RUN_ID\".Project.\"App Name\" // empty" "$PROJECT_FILE")
        TYPE=$(jq -r ".\"$RUN_ID\".Project.Type // empty" "$PROJECT_FILE")
        BASE_URL=$(jq -r ".\"$RUN_ID\".Project.\"Base URL\" // empty" "$PROJECT_FILE")
        DATABASE=$(jq -r ".\"$RUN_ID\".Project.Database // empty" "$PROJECT_FILE")
        ICON=$(jq -r ".\"$RUN_ID\".Project.Icon // empty" "$PROJECT_FILE")
        NOTES=$(jq -r ".\"$RUN_ID\".Project.Notes // empty" "$PROJECT_FILE")
        # Set ID agar prepare-icon bisa berjalan jika dibutuhkan
        ID="$RUN_ID"
    else
        echo "❌ Error: Project dengan ID '$RUN_ID' tidak ditemukan di projects.json, atau jq tidak terinstall."
        exit 1
    fi
else


# Membersihkan dan memformat BASE_URL
if [ -n "$BASE_URL" ]; then
    # Jika input berupa banyak URL (contoh: "url1, live url2"), ekstrak URL terakhir yang valid
    RAW_URL=$(echo "$BASE_URL" | tr ',' ' ' | tr ' ' '\n' | grep '\.' | tail -n 1)
    
    # 1. Hilangkan awalan http:// atau https://
    # 2. Ambil hanya bagian domain (potong sebelum tanda '/' pertama)
    CLEAN_URL=$(echo "$RAW_URL" | sed -E 's|^https?://||' | cut -d '/' -f 1)
    
    # 3. Pastikan menggunakan https
    BASE_URL="https://${CLEAN_URL}"
fi

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
    echo "Berikut adalah hasil data Anda:"
    cat <<EOF
{
    "$ID": {
        "Branch": "$BRANCH",
        "Project": {
            "Project Name": "$PROJECT",
            "Region": "$REGION",
            "App Name": "$APP_NAME",
            "Type": "$TYPE",
            "Base URL": "$BASE_URL",
            "Database": "$DATABASE",
            "Icon": "$ICON",
            "Notes": "$NOTES"
        }
    }
}
EOF
fi
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

if [ -n "$ICON" ]; then
    echo "============================================================"
    echo "🖼️ MENYIAPKAN IKON APLIKASI"
    echo "============================================================"
    bash "${SCRIPT_DIR}/scripts/prepare-icon.sh" "$ICON" || { echo "❌ Gagal menyiapkan ikon!"; exit 1; }
    echo ""
fi

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

if [ -f "${SCRIPT_DIR}/build_app.sh" ]; then
    bash "${SCRIPT_DIR}/build_app.sh" "$ID" || { echo "❌ Proses build gagal!"; exit 1; }
fi
