#!/bin/bash

# Inisialisasi variabel
RUN_ID="$1"

if [ -z "$RUN_ID" ]; then
    echo "⚠️ Penggunaan: ./build_app.sh <project_id>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_FILE="${SCRIPT_DIR}/projects.json"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

if command -v jq >/dev/null 2>&1 && [ -f "$PROJECT_FILE" ]; then
    if ! jq -e ".\"$RUN_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
        echo "❌ Error: Project '$RUN_ID' tidak ditemukan di projects.json"
        exit 1
    fi
    
    PROJECT=$(jq -r ".\"$RUN_ID\".Project.\"Project Name\" // empty" "$PROJECT_FILE")
    APP_NAME=$(jq -r ".\"$RUN_ID\".Project.\"App Name\" // empty" "$PROJECT_FILE")
    TYPE=$(jq -r ".\"$RUN_ID\".Project.Type // empty" "$PROJECT_FILE")
    BRANCH=$(jq -r ".\"$RUN_ID\".Branch // empty" "$PROJECT_FILE")
    
    APP_LOCATION=""
    GDRIVE_FOLDER_ID=""
    if [ -f "$CONFIG_FILE" ]; then
        RAW_LOCATION=$(jq -r ".types[\"$TYPE\"].location // empty" "$CONFIG_FILE")
        APP_LOCATION=$(eval echo "$RAW_LOCATION")
        GDRIVE_FOLDER_ID=$(jq -r ".types[\"$TYPE\"].gdrive_folder_id // empty" "$CONFIG_FILE")
    fi

    if [ -z "$APP_LOCATION" ] || [ ! -d "$APP_LOCATION" ]; then
        echo "❌ Error: Lokasi project untuk tipe '$TYPE' tidak valid atau tidak ditemukan ($APP_LOCATION)."
        exit 1
    fi
else
    echo "❌ Error: jq tidak ditemukan atau projects.json tidak valid."
    exit 1
fi

echo "============================================================"
echo "🔨 MEMULAI FULL BUILD: $APP_NAME"
echo "============================================================"

cd "$APP_LOCATION" || exit 1
echo "  📍 Lokasi: $APP_LOCATION"

if [ -n "$BRANCH" ]; then
    echo "  🌿 Pindah ke branch: $BRANCH"
    git checkout "$BRANCH" >/dev/null 2>&1
    git pull origin "$BRANCH" >/dev/null 2>&1
fi

echo "  > Build APK..."
if ! fvm flutter build apk; then echo "❌ Gagal build APK"; exit 1; fi

echo "  > Build IPA..."
if ! fvm flutter build ipa; then echo "❌ Gagal build IPA"; exit 1; fi

echo "  > Build App Bundle (AAB)..."
if ! fvm flutter build appbundle; then echo "❌ Gagal build AAB"; exit 1; fi

echo "============================================================"
echo "📦 RENAME & MOVE BUILD"
echo "============================================================"

TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT}"
mkdir -p "$TARGET_DIR"

TIMESTAMP=$(date +"%d-%m-%Y %H.%M")
VERSION=$(grep '^version: ' pubspec.yaml | head -n 1 | awk '{print $2}' | tr -d '\r')

# Mengambil konfigurasi Google Drive dari .env
ENV_FILE="${SCRIPT_DIR}/.env"
GDRIVE_CRED_PATH=""
if [ -f "$ENV_FILE" ]; then
    RAW_CRED_PATH=$(grep '^GDRIVE_CREDENTIALS_PATH=' "$ENV_FILE" | cut -d '"' -f 2)
    if [ -n "$RAW_CRED_PATH" ]; then
        GDRIVE_CRED_PATH="${SCRIPT_DIR}/${RAW_CRED_PATH}"
    fi
fi

move_and_rename() {
    local source_path="$1"
    local extension="$2"
    
    if [ -f "$source_path" ]; then
        local new_name="${TIMESTAMP} ${APP_NAME} ${VERSION}.${extension}"
        cp "$source_path" "${TARGET_DIR}/${new_name}"
        echo "  ✅ Berhasil dipindahkan: $new_name"
        
        if [ -n "$GDRIVE_FOLDER_ID" ] && [ -n "$GDRIVE_CRED_PATH" ]; then
            python3 "${SCRIPT_DIR}/scripts/upload_to_gdrive.py" "${TARGET_DIR}/${new_name}" "$GDRIVE_FOLDER_ID" "$GDRIVE_CRED_PATH" "$PROJECT" "$APP_NAME"
        fi
    else
        echo "  ⚠️ File tidak ditemukan: $source_path"
    fi
}

move_and_rename "build/app/outputs/flutter-apk/app-release.apk" "apk"
move_and_rename "build/app/outputs/bundle/release/app-release.aab" "aab"

IPA_FILE=$(find build/ios/ipa -name "*.ipa" 2>/dev/null | head -n 1)
if [ -n "$IPA_FILE" ]; then
    move_and_rename "$IPA_FILE" "ipa"
else
    echo "  ⚠️ File IPA tidak ditemukan."
fi

echo "  > Membersihkan sisa perubahan (git restore .)..."
git restore . >/dev/null 2>&1

echo "============================================================"
echo "🎉 BUILD SELESAI!"
echo "============================================================"
