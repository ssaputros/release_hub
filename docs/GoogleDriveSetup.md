# Panduan Setup Google Drive Auto-Upload

Agar proses build (APK, IPA, AAB) bisa langsung ter-upload ke Google Drive secara aman (tanpa harus login browser berulang-ulang dari terminal), kita menggunakan metode **Google Service Account**.

Ikuti langkah-langkah di bawah ini untuk menyiapkannya.

---

## Tahap 1: Membuat Google Service Account

1. Buka [Google Cloud Console](https://console.cloud.google.com/).
2. Buat Project baru (atau gunakan yang sudah ada, misalnya `HRM Apps Release`).
3. Dari menu navigasi utama, buka **APIs & Services** > **Library**.
4. Cari **Google Drive API**, lalu klik **Enable**.
5. Buka menu **IAM & Admin** > **Service Accounts**.
6. Klik **+ CREATE SERVICE ACCOUNT**.
   - Beri nama (misal: `gdrive-uploader`).
   - Klik **Create and Continue**, lalu **Done** (Role tidak wajib diisi karena kita hanya butuh otorisasi per file/folder).
7. Anda akan melihat email baru yang dihasilkan, formatnya mirip seperti ini: 
   `gdrive-uploader@project-id.iam.gserviceaccount.com`. 
   **Catat atau salin email ini!**

## Tahap 2: Mengunduh Kredensial JSON

1. Di halaman **Service Accounts** yang sama, klik alamat email service account yang baru saja Anda buat.
2. Pindah ke tab **KEYS**.
3. Klik **ADD KEY** > **Create new key**.
4. Pilih format **JSON** dan klik **Create**.
5. File `.json` akan otomatis terunduh ke komputer Anda.
6. Pindahkan file tersebut ke dalam folder `credentials/` di dalam project `release_hub` ini.
7. Ganti nama file tersebut menjadi `gdrive_service_account.json` agar mudah dikenali oleh skrip.

> [!WARNING]
> Jangan pernah mem-commit/mengunggah file `gdrive_service_account.json` ke Git (file ini sudah saya amankan di `.gitignore`).

## Tahap 3: Menyiapkan Folder Tujuan di Google Drive

Karena Service Account adalah entitas (akun) yang sepenuhnya terpisah dari akun Google pribadi Anda, secara default ia tidak memiliki akses ke Drive Anda. Anda harus membagikan (*Share*) foldernya.

1. Buka akun Google Drive pribadi Anda di browser.
2. Buat folder baru (misal: `Release_Builds`) atau pilih folder yang sudah ada.
3. Klik kanan pada folder tersebut lalu pilih **Share** (Bagikan).
4. Pada kolom "*Add people and groups*", **paste email Service Account** yang Anda catat pada Tahap 1.
5. Beri izin sebagai **Editor**.
6. Klik **Send** (hilangkan centang "Notify people" agar tidak error).

## Tahap 4: Mengambil ID Folder

Agar skrip tahu ke mana harus mengunggah file:
1. Buka folder yang baru saja Anda bagikan di Google Drive.
2. Perhatikan URL di bagian atas browser Anda. Biasanya terlihat seperti ini:
   `https://drive.google.com/drive/folders/1aBcD2eF...GhiJ3kL?usp=sharing`
3. Ambil serangkaian teks aneh (alfanumerik) yang berada tepat setelah `/folders/`. Itulah **Folder ID** Anda.
   *(Contoh dari URL di atas: `1aBcD2eF...GhiJ3kL`)*

## Tahap 5: Konfigurasi File

1. Buka file `config.json` di dalam `release_hub`.
2. Temukan blok tipe project Anda (misal: `"HRM Apps"`), lalu tambahkan key `"gdrive_folder_id"`:
   ```json
   "types": {
       "HRM Apps": {
           "prefix": "com.hashmicro.eva",
           "location": "~/Projects/HashMicro/HrmApp",
           "gdrive_folder_id": "masukkan_folder_id_anda_di_sini"
       }
   }
   ```
3. Buka file `.env` dan pastikan Anda mencantumkan path kredensialnya:
   ```env
   GDRIVE_CREDENTIALS_PATH="credentials/gdrive_service_account.json"
   ```

## Tahap 6: Instalasi Pustaka Python

Pastikan Mac Anda sudah terinstal pustaka Python yang dibutuhkan oleh Google API. Buka terminal dan jalankan:

```bash
pip3 install google-api-python-client google-auth-httplib2 google-auth-oauthlib
```

---

Selesai! ✨ Sekarang, setiap kali proses `build_app.sh` selesai mem-build dan me-rename file, ia akan otomatis mengunggah hasilnya ke folder Google Drive Anda dan memberikan tautannya di terminal.
