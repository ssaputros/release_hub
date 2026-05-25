# Panduan Setup Otentikasi TestFlight Auto-Upload

Agar skrip `release -t` dapat mengunggah file `.ipa` ke TestFlight, mendistribusikannya ke eksternal tester, dan mengambil *Public Link* secara otomatis, Anda memerlukan otentikasi. 

Terdapat **Dua Opsi Otentikasi**, silakan pilih salah satu sesuai dengan hak akses (Role) Anda di App Store Connect:

---

## OPSI A: Menggunakan Apple ID (Jika Anda BUKAN Account Holder)
Ini adalah opsi tercepat jika Anda hanya memiliki peran Developer / App Manager dan tidak bisa membuat API Key.

1. Buka browser dan login ke akun Apple ID Anda di [appleid.apple.com](https://appleid.apple.com/).
2. Buka menu **Sign-In and Security** (Masuk dan Keamanan), lalu pilih **App-Specific Passwords** (Kata Sandi Khusus Aplikasi).
3. Klik **Generate an app-specific password** (atau tombol tambah `+`).
4. Beri nama sandi tersebut, misalnya "Release Hub Upload".
5. Masukkan password Apple ID Anda jika diminta.
6. Salin (copy) kode sandi yang dihasilkan (formatnya biasanya `abcd-efgh-ijkl-mnop`).
7. Buka file `.env` di project ini, lalu isi variabel berikut:
   ```env
   # Email Apple ID Anda sudah harus terisi
   APPLE_ID_USERNAME="email_anda@domain.com"
   
   # Isi dengan App-Specific Password yang baru saja Anda buat
   FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="abcd-efgh-ijkl-mnop"
   ```
*(Catatan: Saat pertama kali menjalankan skrip dengan opsi ini, terminal akan meminta password utama dan kode 2FA Anda. Sesi tersebut akan disimpan selama 30 hari).*

---

## OPSI B: Menggunakan App Store Connect API Key (Khusus Account Holder / Admin)
Ini adalah opsi yang paling direkomendasikan untuk sistem otomasi CI/CD tingkat lanjut (tanpa hambatan 2FA sama sekali).

1. Buka browser dan login ke [App Store Connect](https://appstoreconnect.apple.com/).
2. Di halaman utama, cari dan klik menu **Users and Access** (Pengguna dan Akses).
3. Di panel atas (atau samping kiri), cari tab/menu **Integrations**, lalu pilih sub-menu **API** (atau **Keys** tergantung versi akun Anda).
4. Di bagian *App Store Connect API*, klik tombol **+** (Generate API Key) atau **Generate API Key** jika ini adalah key pertama Anda.
5. Masukkan nama kunci (misal: `ReleaseHub Key`).
6. Di bagian *Access*, pilih **App Manager** atau **Admin**.
7. Klik **Generate**.
8. Klik tombol **Download API Key** (file `.p8`), lalu simpan ke dalam folder `credentials/` di dalam project `release_hub`.
   *(Contoh: `credentials/AuthKey_A1B2C3D4E5.p8`)*
9. Buka file `.env` di project ini, lalu isi variabel berikut sesuai data yang ada di halaman tersebut:
   ```env
   ASC_ISSUER_ID="masukkan_issuer_id"
   ASC_KEY_ID="A1B2C3D4E5"
   ASC_KEY_FILE="credentials/AuthKey_A1B2C3D4E5.p8"
   ```

## Selesai! 🎉
Dengan salah satu pengaturan di atas, saat Anda menjalankan perintah `release -t`, skrip ruby (`upload_to_testflight.rb`) akan otomatis:
- Melakukan otentikasi.
- Mengunggah file `.ipa` secara senyap.
- Membuat grup eksternal (jika belum ada).
- Menghasilkan dan menampilkan Public Link TestFlight di terminal Anda.
