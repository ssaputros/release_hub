#!/bin/bash

# Inisialisasi variabel
RUN_ID="$1"

if [ -z "$RUN_ID" ]; then
    echo "⚠️ Penggunaan: ./init_appstore.sh <project_id>"
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
    
    APP_NAME=$(jq -r ".\"$RUN_ID\".Project.\"App Name\" // empty" "$PROJECT_FILE")
    TYPE=$(jq -r ".\"$RUN_ID\".Project.Type // empty" "$PROJECT_FILE")
    
    PREFIX=""
    if [ -f "$CONFIG_FILE" ]; then
        PREFIX=$(jq -r ".types[\"$TYPE\"].prefix // empty" "$CONFIG_FILE")
    fi

    if [ -z "$PREFIX" ]; then
        PREFIX="com.example"
    fi
    APP_PACKAGE_NAME="${PREFIX}.${RUN_ID}"
else
    echo "❌ Error: jq tidak ditemukan atau projects.json tidak valid."
    exit 1
fi

echo "============================================================"
echo "🍏 INISIALISASI APP STORE CONNECT"
echo "============================================================"

if command -v fastlane >/dev/null 2>&1; then
    echo "  - Bundle ID: $APP_PACKAGE_NAME"
    echo "  - App Name : $APP_NAME"
    
    # Mengambil kredensial dari .env jika ada
    ENV_FILE="${SCRIPT_DIR}/.env"
    APPLE_ID=""
    TEAM_ID=""
    ITC_TEAM_ID=""
    if [ -f "$ENV_FILE" ]; then
        APPLE_ID=$(grep '^APPLE_ID_USERNAME=' "$ENV_FILE" | cut -d '"' -f 2)
        TEAM_ID=$(grep '^TEAM_ID=' "$ENV_FILE" | cut -d '"' -f 2)
        ITC_TEAM_ID=$(grep '^ITC_TEAM_ID=' "$ENV_FILE" | cut -d '"' -f 2)
    fi
    
    FASTLANE_ARGS=("-a" "$APP_PACKAGE_NAME" "--app_name" "$APP_NAME" "--language" "English")
    if [ -n "$APPLE_ID" ]; then
        FASTLANE_ARGS+=("-u" "$APPLE_ID")
        echo "  - Apple ID : $APPLE_ID"
    fi
    if [ -n "$TEAM_ID" ]; then
        FASTLANE_ARGS+=("--team_id" "$TEAM_ID")
        echo "  - Team ID  : $TEAM_ID"
    fi
    if [ -n "$ITC_TEAM_ID" ]; then
        FASTLANE_ARGS+=("--itc_team_id" "$ITC_TEAM_ID")
        echo "  - ITC Team : $ITC_TEAM_ID"
    fi
    
    # Menjalankan fastlane produce
    fastlane produce "${FASTLANE_ARGS[@]}"
    
    if [ $? -eq 0 ]; then
        echo "  ✅ App Store Connect berhasil disiapkan."
    else
        echo "  ❌ Gagal menyiapkan App Store Connect."
    fi
else
    echo "  ⚠️ Command 'fastlane' tidak ditemukan. Pembuatan App Store Connect dilewati."
fi
echo "============================================================"
