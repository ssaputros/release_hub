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

# Looping untuk mem-parsing argumen
while [[ "$#" -gt 0 ]]; do
    case $1 in
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
    echo "🧹 Membersihkan perubahan temporary pada Release Hub..."
    git checkout -- android/ ios/ >/dev/null 2>&1
    rm -f icon/*.png icon/icon_raw >/dev/null 2>&1

    if [ -f "${SCRIPT_DIR}/assets/done_sound.wav" ]; then
        afplay "${SCRIPT_DIR}/assets/done_sound.wav" >/dev/null 2>&1 &
    fi
}
trap on_exit EXIT

PROJECT_FILE="${SCRIPT_DIR}/projects.json"

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
