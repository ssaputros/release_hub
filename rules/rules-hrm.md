Semua ini dilakukan di lokasi hrm app

1. Stable branch tiap region:
- Singapore (Stable-SG)
- Indonesia (Stable-Version)
- Philippines (Stable-PH)
- Malaysia (Stable-MY)

2. Check current project branch, kalau udah ada di git project berarti project Exist, kalau belum ada berarti project Baru.

3. Kalau project Baru, buat branch baru dari stable branch, sesuaikan region.

4. Cari file .env di root project, update variable berikut:
- APP_NAME
- ANDROID_ID
- IOS_ID
- FIREBASE_PROJECT_ID
- BASE_URL
- DEFAULT_DB
- FACE_RECOG_DISABLE_UNTIL -> Set ke tanggal 2 bulan dari hari ini

5. Update android package name (ganti juga package di android/app/src/main/kotlin/com/example/hrm_apps/MainActivity.kt) dan ios bundle id

6. Update nama app

7. Connect firebase project ke apps
