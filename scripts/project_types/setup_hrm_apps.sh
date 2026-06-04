#!/bin/bash

# scripts/setup_hrm.sh

# Args: ID, REGION, APP_NAME, TYPE, BASE_URL, DATABASE, APP_PACKAGE_NAME
ID="$1"
REGION="$2"
APP_NAME="$3"
TYPE="$4"
BASE_URL="$5"
DATABASE="$6"
APP_PACKAGE_NAME="$7"

if [ -z "$ID" ] || [ -z "$REGION" ]; then
    echo "Usage: $0 <id> <region> <app_name> <type> <base_url> <database> <package_name>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

echo "⚙️ SETUP PROJECT HRM"

# Read config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "  ❌ Error: config.json tidak ditemukan."
    exit 1
fi

LOCATION_RAW=$(jq -r ".types[\"$TYPE\"].location // empty" "$CONFIG_FILE")
FIREBASE_PROJECT_ID=$(jq -r ".\"$ID\".\"Firebase Project\" // empty" "${SCRIPT_DIR}/projects.json" 2>/dev/null)
if [ -z "$FIREBASE_PROJECT_ID" ]; then
    FIREBASE_PROJECT_ID=$(jq -r ".firebase_project // empty" "$CONFIG_FILE")
fi

if [ -z "$LOCATION_RAW" ]; then
    echo "  ⚠️ Lokasi untuk tipe $TYPE tidak ditemukan di config.json. Skip setup HRM."
    exit 0
fi

# Expand tilde ~ if any
LOCATION="${LOCATION_RAW/#\~/$HOME}"

if [ ! -d "$LOCATION" ]; then
    echo "  ❌ Error: Direktori $LOCATION tidak ditemukan."
    exit 1
fi

echo "  📍 Lokasi App  : $LOCATION"

cd "$LOCATION" || exit 1

# 3. Determine Stable Branch based on REGION
STABLE_BRANCH=""
case "$REGION" in
    "Indonesia") STABLE_BRANCH="Stable-Version" ;;
    "Singapore") STABLE_BRANCH="Stable-SG" ;;
    "Philippines") STABLE_BRANCH="Stable-PH" ;;
    "Malaysia") STABLE_BRANCH="Stable-MY" ;;
    *) 
        echo "  ⚠️ Region '$REGION' tidak dikenal. Menggunakan default 'Stable-Version'."
        STABLE_BRANCH="Stable-Version" 
        ;;
esac

echo "  🌿 Stable Branch: $STABLE_BRANCH"

# Check if branch exists
git fetch origin >/dev/null 2>&1

BRANCH_EXISTS="false"
if git show-ref --verify --quiet "refs/heads/$ID" || git ls-remote --heads origin "$ID" | grep -q "$ID"; then
    BRANCH_EXISTS="true"
fi

if [ "$BRANCH_EXISTS" == "true" ]; then
    echo "  🚀 Project Exist! Pindah ke branch '$ID'..."
    if ! git checkout "$ID" >/dev/null 2>&1; then
        echo "  ❌ Error: Gagal pindah ke branch '$ID'. Harap commit/stash perubahan Anda."
        exit 1
    fi
    git pull origin "$ID" >/dev/null 2>&1
else
    echo "  🆕 Project Baru! Membuat branch '$ID' dari '$STABLE_BRANCH'..."
    if ! git checkout "$STABLE_BRANCH" >/dev/null 2>&1; then
        echo "  ❌ Error: Gagal pindah ke branch '$STABLE_BRANCH'. Harap commit/stash perubahan Anda."
        exit 1
    fi
    git pull origin "$STABLE_BRANCH" >/dev/null 2>&1
    if ! git checkout -b "$ID" >/dev/null 2>&1; then
        echo "  ❌ Error: Gagal membuat branch baru '$ID'."
        exit 1
    fi
fi

# 4. Update .env file
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example "$ENV_FILE"
        echo "  📝 Membuat file .env dari .env.example..."
    else
        touch "$ENV_FILE"
        echo "  📝 Membuat file .env baru..."
    fi
fi

# Hitung tanggal 2 bulan dari hari ini (macOS)
DATE_PLUS_2M=$(date -v+2m +%Y-%m-%d)

# Fungsi helper untuk update atau tambahkan env var
update_env() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        # Gunakan pemisah '|' untuk sed agar tidak bentrok dengan '/' pada URL
        sed -i '' "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

echo "  📝 Mengupdate konfigurasi pada file $ENV_FILE..."
update_env "APP_NAME" "\"$APP_NAME\""
update_env "ANDROID_ID" "\"$APP_PACKAGE_NAME\""
update_env "IOS_ID" "\"$APP_PACKAGE_NAME\""
update_env "FIREBASE_PROJECT_ID" "\"$FIREBASE_PROJECT_ID\""
update_env "BASE_URL" "\"$BASE_URL\""
update_env "DEFAULT_DB" "\"$DATABASE\""
update_env "FACE_RECOG_DISABLE_UNTIL" "\"$DATE_PLUS_2M\""

# 5. Update Android Package Name dan iOS Bundle ID
OLD_ANDROID_PKG=$(grep "applicationId" "android/app/build.gradle.kts" 2>/dev/null | sed 's/.*applicationId = "\(.*\)".*/\1/' | head -n 1)
if [ -z "$OLD_ANDROID_PKG" ]; then
    OLD_ANDROID_PKG=$(grep "namespace" "android/app/build.gradle.kts" 2>/dev/null | sed 's/.*namespace = "\(.*\)".*/\1/' | head -n 1)
fi
if [ -z "$OLD_ANDROID_PKG" ]; then
    OLD_ANDROID_PKG=$(grep "applicationId" "android/app/build.gradle" 2>/dev/null | sed 's/.*applicationId "\(.*\)".*/\1/' | head -n 1)
fi

OLD_IOS_BUNDLE=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "ios/Runner.xcodeproj/project.pbxproj" 2>/dev/null | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);.*/\1/' | head -n 1 | tr -d ' ' | tr -d '"')

if [ -n "$OLD_ANDROID_PKG" ]; then
    if [ "$OLD_ANDROID_PKG" != "$APP_PACKAGE_NAME" ]; then
        echo "  🔄 Mengubah Android ID:"
        echo "     - $OLD_ANDROID_PKG"
        echo "     + $APP_PACKAGE_NAME"
        if [ -f "android/app/build.gradle.kts" ]; then
            sed -i '' "s/$OLD_ANDROID_PKG/$APP_PACKAGE_NAME/g" "android/app/build.gradle.kts" 2>/dev/null
        elif [ -f "android/app/build.gradle" ]; then
            sed -i '' "s/$OLD_ANDROID_PKG/$APP_PACKAGE_NAME/g" "android/app/build.gradle" 2>/dev/null
        fi
        
        if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
            sed -i '' "s/$OLD_ANDROID_PKG/$APP_PACKAGE_NAME/g" "android/app/src/main/AndroidManifest.xml" 2>/dev/null
        fi
    else
        echo "  ✅ Android ID OK:"
        echo "     $APP_PACKAGE_NAME"
    fi
fi

# Update package in MainActivity (pastikan selalu di-update)
MAIN_ACTIVITY=$(find android/app/src/main -name "MainActivity.kt" -o -name "MainActivity.java" 2>/dev/null | head -n 1)
if [ -n "$MAIN_ACTIVITY" ]; then
    sed -i '' "s/^package .*/package $APP_PACKAGE_NAME/" "$MAIN_ACTIVITY" 2>/dev/null
fi

if [ -n "$OLD_IOS_BUNDLE" ]; then
    if [ "$OLD_IOS_BUNDLE" != "$APP_PACKAGE_NAME" ]; then
        echo "  🔄 Mengubah iOS Bundle:"
        echo "     - $OLD_IOS_BUNDLE"
        echo "     + $APP_PACKAGE_NAME"
        sed -i '' "s/$OLD_IOS_BUNDLE/$APP_PACKAGE_NAME/g" "ios/Runner.xcodeproj/project.pbxproj" 2>/dev/null
    else
        echo "  ✅ iOS Bundle OK:"
        echo "     $APP_PACKAGE_NAME"
    fi
fi

# 6. Update Nama App
# Android
if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
    sed -i '' "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/g" "android/app/src/main/AndroidManifest.xml" 2>/dev/null
fi

# iOS Info.plist
if [ -f "ios/Runner/Info.plist" ]; then
    perl -0777 -pi -e "s/(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*(<\/string>)/\1$APP_NAME\2/g" "ios/Runner/Info.plist" 2>/dev/null
    perl -0777 -pi -e "s/(<key>CFBundleName<\/key>\s*<string>)[^<]*(<\/string>)/\1$APP_NAME\2/g" "ios/Runner/Info.plist" 2>/dev/null
fi
echo "  ✅ App Name di-update ke: $APP_NAME"

# 7. Connect Firebase Project
if [ -n "$FIREBASE_PROJECT_ID" ]; then
    echo "  🔥 Menghubungkan ke Firebase Project ($FIREBASE_PROJECT_ID)..."
    if command -v flutterfire >/dev/null 2>&1; then
        flutterfire configure \
            --project="$FIREBASE_PROJECT_ID" \
            --out="lib/firebase_options.dart" \
            --ios-bundle-id="$APP_PACKAGE_NAME" \
            --android-package-name="$APP_PACKAGE_NAME" \
            --yes >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo "  ✅ Firebase berhasil dihubungkan."
        else
            echo "  ❌ Gagal menghubungkan Firebase (cek autentikasi firebase-cli)."
        fi
    else
        echo "  ⚠️ 'flutterfire' tidak ditemukan. Firebase configure dilewati."
    fi
fi

# 8. Change icon app (Sekarang ditangani oleh menu terpisah di release.sh)

# 9. Commit & Push Changes
echo "  💾 Menyimpan konfigurasi branding ke repository..."
git add .
if git diff-index --quiet HEAD --; then
    echo "  ℹ️ Tidak ada perubahan yang perlu di-commit."
else
    git commit -m "chore: auto-setup branding for $APP_NAME ($ID)" >/dev/null 2>&1
    git push origin "$ID" >/dev/null 2>&1
    echo "  ✅ Berhasil push konfigurasi ke branch '$ID'."
fi

echo "  ✅ Setup HRM selesai."
