#!/bin/bash

# scripts/rebrand.sh

NEW_PACKAGE_NAME=$1

if [ -z "$NEW_PACKAGE_NAME" ]; then
    echo "Usage: $0 <new_package_name>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
APP_LOCATION="${RELEASE_HUB_WORKTREE_PATH:-$SCRIPT_DIR}"
APP_LOCATION="${APP_LOCATION/#\~/$HOME}"

if [ ! -d "$APP_LOCATION" ]; then
    echo "❌ Error: Direktori aplikasi tidak ditemukan: $APP_LOCATION"
    exit 1
fi

ANDROID_GRADLE_KTS="${APP_LOCATION}/android/app/build.gradle.kts"
ANDROID_GRADLE="${APP_LOCATION}/android/app/build.gradle"
ANDROID_MANIFEST="${APP_LOCATION}/android/app/src/main/AndroidManifest.xml"
IOS_PROJECT="${APP_LOCATION}/ios/Runner.xcodeproj/project.pbxproj"

# Get OLD Android Package Name
OLD_ANDROID_PKG=""
if [ -f "$ANDROID_GRADLE_KTS" ]; then
    OLD_ANDROID_PKG=$(grep "applicationId" "$ANDROID_GRADLE_KTS" 2>/dev/null | sed 's/.*applicationId = "\(.*\)".*/\1/' | head -n 1)
    if [ -z "$OLD_ANDROID_PKG" ]; then
        OLD_ANDROID_PKG=$(grep "namespace" "$ANDROID_GRADLE_KTS" 2>/dev/null | sed 's/.*namespace = "\(.*\)".*/\1/' | head -n 1)
    fi
elif [ -f "$ANDROID_GRADLE" ]; then
    OLD_ANDROID_PKG=$(grep "applicationId" "$ANDROID_GRADLE" 2>/dev/null | sed 's/.*applicationId "\(.*\)".*/\1/' | head -n 1)
fi

# Get OLD iOS Bundle Identifier
OLD_IOS_BUNDLE=""
if [ -f "$IOS_PROJECT" ]; then
    OLD_IOS_BUNDLE=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "$IOS_PROJECT" 2>/dev/null | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);.*/\1/' | head -n 1 | tr -d ' ' | tr -d '"')
fi

echo "🚀 Menyesuaikan Konfigurasi Aplikasi..."
echo "  📍 Lokasi App  : $APP_LOCATION"

if [ -n "$OLD_ANDROID_PKG" ]; then
    if [ "$OLD_ANDROID_PKG" != "$NEW_PACKAGE_NAME" ]; then
        echo "  🔄 Mengubah Android ID:"
        echo "     - $OLD_ANDROID_PKG"
        echo "     + $NEW_PACKAGE_NAME"
        if [ -f "$ANDROID_GRADLE_KTS" ]; then
            sed -i '' "s/$OLD_ANDROID_PKG/$NEW_PACKAGE_NAME/g" "$ANDROID_GRADLE_KTS"
        elif [ -f "$ANDROID_GRADLE" ]; then
            sed -i '' "s/$OLD_ANDROID_PKG/$NEW_PACKAGE_NAME/g" "$ANDROID_GRADLE"
        fi
        
        if [ -f "$ANDROID_MANIFEST" ]; then
            sed -i '' "s/$OLD_ANDROID_PKG/$NEW_PACKAGE_NAME/g" "$ANDROID_MANIFEST"
        fi
    else
        echo "  ✅ Android ID OK:"
        echo "     $NEW_PACKAGE_NAME"
    fi
fi

if [ -n "$OLD_IOS_BUNDLE" ]; then
    if [ "$OLD_IOS_BUNDLE" != "$NEW_PACKAGE_NAME" ]; then
        echo "  🔄 Mengubah iOS Bundle:"
        echo "     - $OLD_IOS_BUNDLE"
        echo "     + $NEW_PACKAGE_NAME"
        sed -i '' "s/$OLD_IOS_BUNDLE/$NEW_PACKAGE_NAME/g" "$IOS_PROJECT"
    else
        echo "  ✅ iOS Bundle OK:"
        echo "     $NEW_PACKAGE_NAME"
    fi
fi

echo "  ✨ Konfigurasi Selesai."
