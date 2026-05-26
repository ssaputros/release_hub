# 🚀 Setup Google Play Store Listing via Fastlane

Skrip pembaruan *Store Listing* otomatis menggunakan **Fastlane Supply** adalah cara tercepat dan paling andal untuk memperbarui nama aplikasi, deskripsi singkat, deskripsi lengkap, ikon, gambar fitur, dan *screenshots* langsung ke Google Play Store melalui API resmi Google, tanpa perlu membuka browser secara manual.

---

## 1. Struktur Folder Metadata

Metadata dan aset gambar dikelompokkan berdasarkan **Tipe Aplikasi** dan **Project Branch** di dalam direktori `store_listings/`. 

Struktur folder default untuk sebuah project (contoh: project `sst` tipe `HRM Apps`) terlihat seperti ini:

```text
store_listings/
└── Hrm Apps/                          # Tipe Aplikasi (Hrm Apps / Approval Apps)
    └── sst/                           # ID/Branch Project
        └── metadata/
            └── android/
                ├── en-US/             # Kode Bahasa (Locale) 1
                │   ├── title.txt
                │   ├── short_description.txt
                │   ├── full_description.txt
                │   └── images/
                │       ├── icon.png
                │       ├── featureGraphic.png
                │       ├── phoneScreenshots/
                │       │   ├── screen1.png
                │       │   └── screen2.png
                │       ├── sevenInchScreenshots/
                │       └── tenInchScreenshots/
                └── id/                # Kode Bahasa (Locale) 2
                    ├── title.txt
                    ├── short_description.txt
                    └── full_description.txt
```

> [!NOTE]
> Jika folder atau file di atas belum ada untuk project Anda, **skrip akan secara otomatis membuatkannya** sebagai template ketika pertama kali dijalankan!

---

## 2. Spesifikasi Pengisian Deskripsi (Teks)

Setiap file teks memiliki batasan karakter yang ketat dari Google. Skrip automasi akan memvalidasi panjang teks ini sebelum mengupload untuk mencegah kegagalan API.

| Nama File | Fungsi | Batas Karakter Google |
| :--- | :--- | :--- |
| `title.txt` | Nama aplikasi yang tampil di Play Store | **Maksimal 50 karakter** |
| `short_description.txt` | Deskripsi singkat (tampil sebelum diklik lebih lanjut) | **Maksimal 80 karakter** |
| `full_description.txt` | Deskripsi lengkap aplikasi | **Maksimal 4000 karakter** |

---

## 3. Spesifikasi Aset Gambar & Screenshots

Untuk memperbarui ikon atau gambar di Play Store, letakkan aset Anda di dalam folder `images/` pada locale yang sesuai dengan aturan berikut:

### A. Ikon Aplikasi (`icon.png`)
*   **Format**: 32-bit PNG (dengan alpha channel/transparansi)
*   **Dimensi**: `512 x 512` piksel
*   **Ukuran Maksimal**: 1 MB

### B. Gambar Unggulan (`featureGraphic.png`)
*   **Format**: 24-bit PNG atau JPEG (tanpa alpha channel)
*   **Dimensi**: `1024 x 500` piksel

### C. Screenshots (`phoneScreenshots/`, `sevenInchScreenshots/`, `tenInchScreenshots/`)
*   **Format**: PNG atau JPEG
*   **Rasio Aspek**: `16:9` atau `9:16`
*   **Dimensi Sisi**: Antara `320px` hingga `3840px`
*   **Jumlah**: Minimal 2 screenshots per tipe layar (Maksimal 8).

---

## 4. Cara Menjalankan Automasi

Anda memiliki dua opsi mudah untuk menjalankan pembaruan *Store Listing*:

### Opsi A: Lewat Menu Utama `release.sh` (Sangat Direkomendasikan)
1.  Jalankan `./release.sh` di terminal Anda.
2.  Pilih project yang ingin Anda eksekusi.
3.  Pilih menu aksi **`10) Setup Store Listing`**.
4.  Pilih metode **`1) Fastlane API`** ketika ditanya.
5.  Skrip akan memvalidasi metadata lokal Anda dan langsung mengunggahnya ke Play Store!

### Opsi B: Jalankan Skrip Ruby Mandiri
Anda juga bisa memanggil skrip pembaruan secara mandiri dari terminal:

```bash
# Menjalankan secara interaktif (menampilkan daftar pilihan project & tipe)
ruby scripts/update_store_listing.rb

# Menjalankan langsung dengan argumen
ruby scripts/update_store_listing.rb <project_id> [app_type]

# Contoh:
ruby scripts/update_store_listing.rb sst "HRM Apps"
```

---

## 5. Fitur Deteksi & Auto-Template

Jika Anda baru pertama kali menyiapkan metadata untuk project tersebut:
1.  Jalankan skrip `ruby scripts/update_store_listing.rb <project_id>`.
2.  Skrip akan mendeteksi folder kosong dan **secara otomatis membuat seluruh struktur folder serta template teks `.txt`**.
3.  Proses dihentikan sementara agar Anda bisa melengkapi teks deskripsi di editor Anda.
4.  Jalankan skrip kembali untuk memproses validasi karakter dan melakukan proses pengunggahan API!
