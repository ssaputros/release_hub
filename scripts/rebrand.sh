#!/bin/bash

# scripts/rebrand.sh

NEW_PACKAGE_NAME=$1

if [ -z "$NEW_PACKAGE_NAME" ]; then
    echo "Usage: $0 <new_package_name>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"

# Get OLD Android Package Name
OLD_ANDROID_PKG=$(grep "applicationId" "${SCRIPT_DIR}/android/app/build.gradle.kts" | sed 's/.*applicationId = "\(.*\)".*/\1/' | head -n 1)

if [ -z "$OLD_ANDROID_PKG" ]; then
    OLD_ANDROID_PKG=$(grep "namespace" "${SCRIPT_DIR}/android/app/build.gradle.kts" | sed 's/.*namespace = "\(.*\)".*/\1/' | head -n 1)
fi

# Get OLD iOS Bundle Identifier
OLD_IOS_BUNDLE=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "${SCRIPT_DIR}/ios/Runner.xcodeproj/project.pbxproj" | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);.*/\1/' | head -n 1 | tr -d ' ' | tr -d '"')

echo "🚀 Menyesuaikan Konfigurasi Aplikasi..."

if [ -n "$OLD_ANDROID_PKG" ]; then
    if [ "$OLD_ANDROID_PKG" != "$NEW_PACKAGE_NAME" ]; then
        echo "  🔄 Mengubah Android ID:"
        echo "     - $OLD_ANDROID_PKG"
        echo "     + $NEW_PACKAGE_NAME"
        sed -i '' "s/$OLD_ANDROID_PKG/$NEW_PACKAGE_NAME/g" "${SCRIPT_DIR}/android/app/build.gradle.kts"
        
        if [ -f "${SCRIPT_DIR}/android/app/src/main/AndroidManifest.xml" ]; then
            sed -i '' "s/$OLD_ANDROID_PKG/$NEW_PACKAGE_NAME/g" "${SCRIPT_DIR}/android/app/src/main/AndroidManifest.xml"
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
        sed -i '' "s/$OLD_IOS_BUNDLE/$NEW_PACKAGE_NAME/g" "${SCRIPT_DIR}/ios/Runner.xcodeproj/project.pbxproj"
    else
        echo "  ✅ iOS Bundle OK:"
        echo "     $NEW_PACKAGE_NAME"
    fi
fi

echo "  ✨ Konfigurasi Selesai."
