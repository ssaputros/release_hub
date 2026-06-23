#!/bin/bash

# Inisialisasi variabel
RUN_ID="$1"
APP_TYPE="$2"

if [ -z "$RUN_ID" ] || [ -z "$APP_TYPE" ]; then
    echo "⚠️ Penggunaan: ./build_app.sh <project_id> <app_type>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_FILE="${SCRIPT_DIR}/projects.json"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

expand_path() {
    local path_value="$1"
    printf '%s' "${path_value/#\~/$HOME}"
}

resolve_app_location() {
    local app_type="$1"
    local raw_location=""

    if [ -n "${RELEASE_HUB_WORKTREE_PATH:-}" ] && { [ -z "${RELEASE_HUB_WORKTREE_TYPE:-}" ] || [ "$RELEASE_HUB_WORKTREE_TYPE" = "$app_type" ]; }; then
        expand_path "$RELEASE_HUB_WORKTREE_PATH"
        return
    fi

    if [ -f "$CONFIG_FILE" ]; then
        raw_location=$(jq -r ".types[\"$app_type\"].location // empty" "$CONFIG_FILE")
    fi

    if [ -n "$raw_location" ]; then
        expand_path "$raw_location"
    fi
}

if command -v jq >/dev/null 2>&1 && [ -f "$PROJECT_FILE" ]; then
    if ! jq -e ".\"$RUN_ID\"" "$PROJECT_FILE" >/dev/null 2>&1; then
        echo "❌ Error: Project '$RUN_ID' tidak ditemukan di projects.json"
        exit 1
    fi
    
    PROJECT=$(jq -r ".\"$RUN_ID\".Project.\"Project Name\" // empty" "$PROJECT_FILE")
    # Coba ambil App Name spesifik tipe, fallback ke App Name general
    APP_NAME=$(jq -r ".\"$RUN_ID\".Project.\"App Name\"[\"$APP_TYPE\"] // .\"$RUN_ID\".Project.\"App Name\" // empty" "$PROJECT_FILE")
    BRANCH=$(jq -r ".\"$RUN_ID\".Branch[\"$APP_TYPE\"] // empty" "$PROJECT_FILE")
    
    APP_LOCATION=$(resolve_app_location "$APP_TYPE")
    GDRIVE_FOLDER_ID=""
    if [ -f "$CONFIG_FILE" ]; then
        GDRIVE_FOLDER_ID=$(jq -r ".types[\"$APP_TYPE\"].gdrive_folder_id // empty" "$CONFIG_FILE")
    fi

    if [ -z "$APP_LOCATION" ] || [ ! -d "$APP_LOCATION" ]; then
        echo "❌ Error: Lokasi project untuk tipe '$APP_TYPE' tidak valid atau tidak ditemukan ($APP_LOCATION)."
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

VERSION=$(grep '^version: ' pubspec.yaml | head -n 1 | awk '{print $2}' | tr -d '\r')
TIMESTAMP=$(date +"%d-%m-%Y %H.%M")
TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT}/${APP_TYPE}"
mkdir -p "$TARGET_DIR"

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
        local base_filename=$(basename "$source_path")
        local new_name="${TIMESTAMP} ${APP_NAME} ${VERSION}.${extension}"
        
        # 1. Pindahkan (copy) dengan nama aslinya terlebih dahulu ke folder target
        cp "$source_path" "${TARGET_DIR}/${base_filename}"
        
        # 2. Lakukan rename setelah file sepenuhnya berada di folder target
        mv "${TARGET_DIR}/${base_filename}" "${TARGET_DIR}/${new_name}"
        
        echo "  ✅ Berhasil dipindahkan & di-rename: $new_name"
        
        if [ "$SKIP_UPLOAD" != "true" ] && [ -n "$GDRIVE_FOLDER_ID" ] && [ -n "$GDRIVE_CRED_PATH" ]; then
            python3 "${SCRIPT_DIR}/scripts/upload_to_gdrive.py" "${TARGET_DIR}/${new_name}" "$GDRIVE_FOLDER_ID" "$GDRIVE_CRED_PATH" "$PROJECT" "$APP_NAME"
        fi
    else
        echo "  ⚠️ File tidak ditemukan: $source_path"
    fi
}

if [ -z "$BUILD_TARGET_APK" ] && [ -z "$BUILD_TARGET_IPA" ] && [ -z "$BUILD_TARGET_AAB" ]; then
    BUILD_TARGET_APK=true
    BUILD_TARGET_IPA=true
    BUILD_TARGET_AAB=true
fi

if [ "$BUILD_TARGET_APK" = true ]; then
    echo "  > Build APK..."
    if ! fvm flutter build apk; then echo "❌ Gagal build APK"; exit 1; fi
    APK_FILE=$(find build/app/outputs -name "*.apk" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$APK_FILE" ]; then
        move_and_rename "$APK_FILE" "apk"
    else
        echo "  ⚠️ File APK tidak ditemukan di direktori build/app/outputs."
    fi
fi

if [ "$BUILD_TARGET_AAB" = true ]; then
    echo "  > Build App Bundle (AAB)..."
    if ! fvm flutter build appbundle; then echo "❌ Gagal build AAB"; exit 1; fi
    AAB_FILE=$(find build/app/outputs -name "*.aab" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$AAB_FILE" ]; then
        move_and_rename "$AAB_FILE" "aab"
    else
        echo "  ⚠️ File AAB tidak ditemukan di direktori build/app/outputs."
    fi
fi

if [ "$BUILD_TARGET_IPA" = true ]; then
    echo "  > Build IPA..."
    if ! fvm flutter build ipa; then echo "❌ Gagal build IPA"; exit 1; fi
    
    IPA_FILE=$(find build/ios/ipa -name "*.ipa" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$IPA_FILE" ]; then
        move_and_rename "$IPA_FILE" "ipa"
    else
        echo "  ⚠️ File IPA tidak ditemukan di direktori build/ios/ipa."
    fi
fi

echo "  > Membersihkan sisa perubahan (git restore .)..."
git restore . >/dev/null 2>&1

echo "============================================================"
echo "🎉 BUILD SELESAI!"
echo "============================================================"
