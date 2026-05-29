Semua ini dilakukan di branch Approval Apps

1. Stable-branchnya: development

2. Check current project branch, kalau udah ada di git project berarti project Exist, kalau belum ada berarti project Baru.

3. Kalau project Baru, buat branch baru dari stable branch

4. Cari file .env di root project, update variable berikut:
- APP_NAME
- ANDROID_ID
- IOS_ID
- FIREBASE_PROJECT_ID
- BASE_URL
- PORT (kosongkan)
- DEFAULT_DB
- TARGET_RELEASE_DATE -> Set ke tanggal 2 bulan dari hari ini

5. Update android package name (ganti juga package di android/app/src/main/kotlin/com/example/hrm_apps/MainActivity.kt) dan ios bundle id

6. Update nama app

7. Connect firebase project ke apps

8. Change icon app
- Tambahkan ini sebagai step terakhir change icon di approval apps: Hapus adaptive icon XML kosong yang menyebabkan blank icon di Android 8+
ADAPTIVE_ICON_DIR="android/app/src/main/res/mipmap-anydpi-v26"
if [ -d "$ADAPTIVE_ICON_DIR" ]; then
    rm -rf "$ADAPTIVE_ICON_DIR"
    echo "🗑️  Removed $ADAPTIVE_ICON_DIR to prevent blank adaptive icon"
fi


Aturan bump version:
1. Cukup ubah di file pubspec.yaml saja
