# 🚀 Setup Google Play Store untuk Automasi

> [!WARNING]
> **Penting**: Berdasarkan kebijakan dan batasan Google Play Developer API, **kita TIDAK BISA membuat aplikasi yang benar-benar baru (Create App) melalui skrip/API**. Aplikasi baru harus dibuat secara manual terlebih dahulu di dashboard Play Console. Skrip hanya bisa mengunggah App Bundle (AAB), mengupdate versi, dan mengubah deskripsi/metadata setelah aplikasi dibuat.

Berikut adalah langkah-langkah yang harus dilakukan secara manual untuk setiap project baru sebelum automasi bisa berjalan.

## 1. Buat Aplikasi di Google Play Console (Manual)
1. Buka [Google Play Console](https://play.google.com/console).
2. Klik tombol **Create app** (Buat aplikasi) di pojok kanan atas.
3. Masukkan **App name**, pilih bahasa default, pilih tipe **App**, dan status **Free/Paid**.
4. Setujui *Developer Program Policies* dan *US export laws*, lalu klik **Create app**.

## 2. Setup Awal Aplikasi (Wajib)
Google Play mewajibkan Anda untuk mengisi formulir berikut sebelum bisa mengunggah file AAB apa pun (walaupun untuk testing):
- **Set up your app**: Selesaikan semua *task* di dashboard, termasuk:
  - App Access (Akses Aplikasi)
  - Ads (Iklan)
  - Content rating (Rating Konten)
  - Target audience (Target Audiens)
  - News apps (Aplikasi Berita)
  - Data safety (Keamanan Data)

## 3. Upload AAB Pertama Kali (Manual)
Untuk menghubungkan Package Name (`com.example.app`) dengan API, Anda harus mengunggah file `.aab` pertama kali secara manual:
1. Masuk ke menu **Internal Testing** atau **Closed Testing**.
2. Buat rilis baru (Create new release).
3. Unggah file `.aab` hasil build (`flutter build appbundle`).
4. Simpan (Save). Anda tidak perlu meluncurkan (Rollout) rilis ini jika belum mau.

> [!TIP]
> Setelah 3 langkah di atas selesai, aplikasi Anda sudah "terdaftar" dengan Package Name yang benar di Google Play, dan **seluruh proses update selanjutnya bisa dilakukan secara otomatis menggunakan skrip automasi**.

---

## 4. Konfigurasi Kredensial Automasi (Satu Kali Saja)
Agar skrip *Release Hub* bisa mengakses akun Google Play Anda, Anda butuh file **Google Cloud Service Account JSON**.

1. Masuk ke **Google Play Console** -> **Setup** -> **API Access**.
2. Hubungkan project Google Cloud jika belum.
3. Klik **Create new service account** di Google Cloud Console.
4. Beri nama service account, dan berikan *Role* **Service Account User**.
5. Buka tab *Keys* -> **Add Key** -> **Create new key** -> **JSON**. File JSON akan terunduh.
6. Kembali ke Google Play Console (API Access), klik **Grant Access** pada Service Account yang baru dibuat.
7. Beri *Role* **Release manager** atau **Admin** agar bisa mengunggah build.
8. Ganti nama file JSON yang terunduh menjadi `playstore_service_account.json` dan letakkan di dalam folder `credentials/` pada project *Release Hub*.

## 5. Menjalankan Skrip Automasi
Setelah setup di atas selesai, Anda bisa mengunggah pembaruan aplikasi langsung dengan menjalankan skrip upload yang telah disiapkan di Release Hub:

```bash
ruby scripts/upload_to_playstore.rb <path_to_aab> <package_name> <track>
```
