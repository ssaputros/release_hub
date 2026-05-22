#!/bin/bash

# Pastikan script berhenti jika ada command yang gagal di pertengahan
set -e

APP_PACKAGE_NAME="$1"
APP_NAME="$2"

if [ -z "$APP_PACKAGE_NAME" ] || [ -z "$APP_NAME" ]; then
    echo "⚠️ Penggunaan: ./init_appstore.sh <Bundle ID> <App Name>"
    exit 1
fi

if command -v fastlane >/dev/null 2>&1; then
    echo "  🍏 Membuat App Store Connect via Fastlane..."
    echo "     - Bundle ID: $APP_PACKAGE_NAME"
    echo "     - App Name : $APP_NAME"
    
    # Menjalankan fastlane produce
    # Kami tidak menyertakan -u secara hardcode agar dapat mengambil dari environment 
    # variabel FASTLANE_USER atau meminta input interaktif.
    fastlane produce -a "$APP_PACKAGE_NAME" --app_name "$APP_NAME" --language "English"
    
    if [ $? -eq 0 ]; then
        echo "  ✅ App Store Connect berhasil disiapkan."
    else
        echo "  ❌ Gagal menyiapkan App Store Connect."
    fi
else
    echo "  ⚠️ Command 'fastlane' tidak ditemukan. Pembuatan App Store Connect dilewati."
fi
