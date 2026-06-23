# Panduan Manual Release HRM Apps dan Approval Apps

Panduan ini dibuat untuk orang yang tidak terlalu teknis. Tujuannya adalah menjelaskan alur dari awal sampai aplikasi bisa dibuat di Play Store, App Store Connect, TestFlight, dan siap direlease.

Panduan ini **tanpa menjalankan script otomatis**. Release Hub hanya dipakai sebagai tempat data project dan referensi nomor menu/flow, bukan untuk mengeksekusi release otomatis.

---

## 1. Gambaran Besar

Ada 2 jenis aplikasi:

1. **HRM Apps**
   - Aplikasi HRIS/HRM untuk employee, attendance, payroll, leave, reimbursement, dan fitur HR lain.
   - Package/Bundle ID biasanya memakai pola:
     - `com.hashmicro.eva.nama_project`

2. **Approval Apps**
   - Aplikasi untuk approval/request/approval workflow.
   - Package/Bundle ID biasanya memakai pola:
     - `com.hashmicro.approval.nama_project`

Setiap aplikasi yang akan direlease perlu punya 2 identitas penting:

- **Android Package ID**: dipakai oleh Google Play Console.
- **iOS Bundle ID**: dipakai oleh Apple Developer dan App Store Connect.

Biasanya Android Package ID dan iOS Bundle ID dibuat sama agar mudah dikelola.

Contoh:

- HRM Apps:
  - App name: `Bumi Aki HRIS`
  - Package/Bundle ID: `com.hashmicro.eva.bumiaki`

- Approval Apps:
  - App name: `Bumi Aki Approval`
  - Package/Bundle ID: `com.hashmicro.approval.bumiaki`

---

## 2. Akun dan Akses yang Harus Disiapkan

Sebelum mulai, pastikan punya akses berikut:

### 2.1 Akses Google

Dibutuhkan untuk Android release.

- Akun Google yang punya akses ke **Google Play Console**.
- Akses ke project/app client di Play Console.
- Akses untuk membuat aplikasi baru.
- Akses untuk upload AAB ke release track.

Link:

- Google Play Console: https://play.google.com/console

### 2.2 Akses Apple

Dibutuhkan untuk iOS release.

- Apple ID yang masuk ke **Apple Developer Program**.
- Akses ke **Certificates, Identifiers & Profiles**.
- Akses ke **App Store Connect**.
- Role yang cukup untuk membuat app, upload build, TestFlight, dan submit review.

Link:

- Apple Developer: https://developer.apple.com/account
- App Store Connect: https://appstoreconnect.apple.com

### 2.3 Akses Repository

Pastikan punya akses ke repo aplikasi:

- HRM Apps:
  - Lokasi umum: `~/Projects/HashMicro/HrmApp`

- Approval Apps:
  - Lokasi umum: `~/Projects/HashMicro/ApprovalApp`

- Release Hub:
  - Lokasi umum: `~/Projects/+Lab/release_hub`

---

## 3. Setup Awal Laptop

Bagian ini dilakukan sekali di laptop baru atau laptop yang belum pernah dipakai release.

### 3.1 Install Xcode

Xcode diperlukan untuk build iOS dan upload ke TestFlight/App Store.

Langkah:

1. Buka **App Store** di Mac.
2. Cari **Xcode**.
3. Install Xcode.
4. Setelah selesai, buka Xcode sekali.
5. Kalau muncul license agreement atau install additional components, klik setuju/install.

Cek dari Terminal:

```bash
xcodebuild -version
```

Kalau muncul versi Xcode, berarti Xcode sudah terbaca.

Jika diminta memilih command line tools:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Lalu cek lagi:

```bash
xcodebuild -version
```

### 3.2 Install Android Studio

Android Studio diperlukan untuk SDK Android, emulator, dan signing/build Android.

Langkah:

1. Download Android Studio dari:
   - https://developer.android.com/studio
2. Install seperti aplikasi Mac biasa.
3. Buka Android Studio.
4. Ikuti setup wizard.
5. Pastikan Android SDK terinstall.
6. Buka menu:
   - Android Studio → Settings/Preferences → Languages & Frameworks → Android SDK
7. Pastikan minimal ada:
   - Android SDK Platform terbaru.
   - Android SDK Build-Tools.
   - Android SDK Command-line Tools.

Cek dari Terminal:

```bash
flutter doctor --android-licenses
```

Kalau diminta accept license, jawab `y` sampai selesai.

### 3.3 Install Flutter

Flutter diperlukan untuk build aplikasi Android dan iOS.

Langkah umum:

1. Download Flutter dari:
   - https://docs.flutter.dev/get-started/install/macos
2. Extract ke folder yang mudah, contoh:
   - `~/development/flutter`
3. Tambahkan Flutter ke PATH.

Contoh jika memakai zsh:

```bash
nano ~/.zshrc
```

Tambahkan:

```bash
export PATH="$PATH:$HOME/development/flutter/bin"
```

Simpan, lalu jalankan:

```bash
source ~/.zshrc
flutter --version
```

### 3.4 Jalankan Flutter Doctor

Flutter Doctor membantu mengecek apakah setup sudah lengkap.

```bash
flutter doctor
```

Yang ideal:

- Flutter OK.
- Android toolchain OK.
- Xcode OK.
- Android Studio OK.
- Connected device boleh kosong, tidak masalah untuk build release.

Kalau ada error, selesaikan satu per satu sesuai instruksi dari `flutter doctor`.

### 3.5 Install CocoaPods

CocoaPods dibutuhkan untuk dependency iOS.

```bash
sudo gem install cocoapods
pod --version
```

Kalau memakai Ruby environment tertentu, bisa jadi instalasi CocoaPods mengikuti setup internal tim.

### 3.6 Install Tools Tambahan

Beberapa tools yang sering diperlukan:

```bash
brew install jq
brew install fastlane
npm install -g firebase-tools
```

Install FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Pastikan path Dart global aktif. Biasanya perlu menambahkan ini ke `~/.zshrc`:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Cek:

```bash
firebase --version
flutterfire --version
fastlane --version
jq --version
```

### 3.7 Login ke Firebase Jika Dibutuhkan

```bash
firebase login
```

Login memakai akun Google yang punya akses ke Firebase project HashMicro/client.

---

## 4. Persiapan Data Client Sebelum Membuat Project

Sebelum membuat app baru, kumpulkan data ini:

1. **Nama client/project**
   - Contoh: `Bumi Aki Group`

2. **Project key**
   - Nama pendek tanpa spasi, huruf kecil.
   - Contoh: `bumiaki`

3. **Region**
   - Contoh: `Indonesia`, `Singapore`, `Philippines`, `Malaysia`.

4. **Jenis aplikasi yang dibuat**
   - `HRM Apps`
   - `Approval Apps`
   - atau keduanya.

5. **Nama app**
   - HRM: biasanya `[Nama Client] HRIS`.
   - Approval: biasanya `[Nama Client] Approval`.

6. **Base URL**
   - URL API/client.
   - Contoh: `https://client.hashmicro.co`

7. **Database name**
   - Nama database client.

8. **Icon aplikasi**
   - File PNG/JPG resolusi bagus.
   - Idealnya 1024 x 1024 px.
   - Jangan pakai gambar buram atau terlalu banyak detail kecil.

9. **Firebase Project** jika ada
   - Jika belum ada, tanyakan ke PIC/lead apakah memakai default Firebase atau project khusus client.

---

## 5. Membuat Project Baru di Release Hub

Release Hub menyimpan daftar client di file `projects.json`. File ini dipakai sebagai data pusat agar nama app, package ID, bundle ID, base URL, database, dan tipe aplikasi konsisten.

Lokasi Release Hub:

```bash
cd ~/Projects/+Lab/release_hub
```

File penting:

- `projects.json`: daftar project/client.
- `config.json`: konfigurasi umum tipe aplikasi dan lokasi repo.

### 5.1 Bentuk Data Project

Contoh data project yang punya HRM Apps dan Approval Apps:

```json
"nama_project": {
  "Branch": {
    "Approval Apps": "nama_project",
    "HRM Apps": "nama_project"
  },
  "Play Console Dashboard": {
    "Approval Apps": "",
    "HRM Apps": ""
  },
  "Firebase Project": "",
  "Project": {
    "Project Name": "Nama Client",
    "Region": "Indonesia",
    "App Name": {
      "Approval Apps": "Nama Client Approval",
      "HRM Apps": "Nama Client HRIS"
    },
    "Type": "Approval Apps, HRM Apps",
    "Base URL": "https://client.hashmicro.co",
    "Database": "nama_database",
    "Icon": ""
  },
  "Package ID": {
    "Approval Apps": "com.hashmicro.approval.nama_project",
    "HRM Apps": "com.hashmicro.eva.nama_project"
  },
  "Bundle ID": {
    "Approval Apps": "com.hashmicro.approval.nama_project",
    "HRM Apps": "com.hashmicro.eva.nama_project"
  }
}
```

Penjelasan sederhana:

- `nama_project`: kode pendek client.
- `Branch`: nama branch Git untuk app tersebut.
- `Play Console Dashboard`: ID dashboard Google Play setelah app dibuat.
- `Firebase Project`: nama Firebase project jika ada.
- `Project Name`: nama resmi client.
- `Region`: negara/region client.
- `App Name`: nama aplikasi yang tampil di HP.
- `Type`: jenis aplikasi yang dimiliki client.
- `Base URL`: alamat server API.
- `Database`: database client.
- `Icon`: link/path icon.
- `Package ID`: identitas Android.
- `Bundle ID`: identitas iOS.

### 5.2 Jika Hanya Membuat HRM Apps

Isi `Type` cukup:

```json
"Type": "HRM Apps"
```

Gunakan pola:

```text
com.hashmicro.eva.nama_project
```

Contoh:

```text
com.hashmicro.eva.clientbaru
```

### 5.3 Jika Hanya Membuat Approval Apps

Isi `Type` cukup:

```json
"Type": "Approval Apps"
```

Gunakan pola:

```text
com.hashmicro.approval.nama_project
```

Contoh:

```text
com.hashmicro.approval.clientbaru
```

### 5.4 Jika Membuat HRM Apps dan Approval Apps

Isi `Type`:

```json
"Type": "Approval Apps, HRM Apps"
```

Buat 2 app name:

- `Client Baru HRIS`
- `Client Baru Approval`

Buat 2 package/bundle ID:

- `com.hashmicro.eva.clientbaru`
- `com.hashmicro.approval.clientbaru`

### 5.5 Cek JSON Setelah Edit

Setelah edit `projects.json`, cek apakah JSON valid:

```bash
jq empty projects.json
```

Kalau tidak ada output error, berarti format JSON aman.

---

## 6. Setup Project HRM Apps Secara Manual

Lokasi app:

```bash
cd ~/Projects/HashMicro/HrmApp
```

### 6.1 Pastikan Tidak Ada Perubahan yang Belum Disimpan

```bash
git status
```

Kalau ada file berubah, jangan lanjut sebelum dipastikan boleh commit/stash.

### 6.2 Pilih Branch Dasar Berdasarkan Region

Umumnya:

- Indonesia: `Stable-Version`
- Singapore: `Stable-SG`
- Philippines: `Stable-PH`
- Malaysia: `Stable-MY`

Contoh untuk Indonesia:

```bash
git checkout Stable-Version
git pull origin Stable-Version
```

### 6.3 Buat Branch Client Baru

Contoh project key `clientbaru`:

```bash
git checkout -b clientbaru
```

Kalau branch sudah ada:

```bash
git checkout clientbaru
git pull origin clientbaru
```

### 6.4 Update File `.env`

Buka file `.env`. Jika belum ada, copy dari `.env.example` jika tersedia.

Isi/update data seperti ini:

```env
APP_NAME="Client Baru HRIS"
ANDROID_ID="com.hashmicro.eva.clientbaru"
IOS_ID="com.hashmicro.eva.clientbaru"
FIREBASE_PROJECT_ID="nama-firebase-project"
BASE_URL="https://client.hashmicro.co"
DEFAULT_DB="nama_database"
```

Catatan:

- Jangan asal mengganti Firebase Project jika belum jelas.
- Pastikan Base URL bisa dibuka/dipakai.
- Pastikan database benar.

### 6.5 Update Android Package ID

Cari di file Android, biasanya:

- `android/app/build.gradle`
- atau `android/app/build.gradle.kts`

Ganti `applicationId` menjadi:

```text
com.hashmicro.eva.clientbaru
```

Jika ada `namespace`, samakan juga.

Cek juga MainActivity:

- `android/app/src/main/.../MainActivity.kt`
- atau `MainActivity.java`

Pastikan baris `package ...` mengikuti package ID baru.

### 6.6 Update iOS Bundle ID

Buka Xcode:

```bash
open ios/Runner.xcworkspace
```

Di Xcode:

1. Klik project `Runner`.
2. Pilih target `Runner`.
3. Buka tab **Signing & Capabilities**.
4. Ubah **Bundle Identifier** menjadi:
   - `com.hashmicro.eva.clientbaru`
5. Pilih Team Apple Developer yang benar.
6. Pastikan signing tidak error.

### 6.7 Update Nama Aplikasi

Android:

- Cek `android/app/src/main/AndroidManifest.xml`.
- Ubah `android:label` menjadi nama app, contoh:
  - `Client Baru HRIS`

IOS:

- Cek `ios/Runner/Info.plist`.
- Ubah:
  - `CFBundleDisplayName`
  - `CFBundleName`

Menjadi nama app yang benar.

### 6.8 Setup Firebase

Jika memakai Firebase:

```bash
flutterfire configure
```

Pilih Firebase project yang benar.

Pastikan output membuat/mengupdate:

```text
lib/firebase_options.dart
```

### 6.9 Install Dependency

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

### 6.10 Cek Build Dasar

Android:

```bash
flutter build apk --release
```

IOS:

```bash
flutter build ipa --release
```

Jika build berhasil, lanjut ke pembuatan app di Play Console dan App Store Connect.

---

## 7. Setup Project Approval Apps Secara Manual

Lokasi app:

```bash
cd ~/Projects/HashMicro/ApprovalApp
```

### 7.1 Pastikan Tidak Ada Perubahan yang Belum Disimpan

```bash
git status
```

Kalau ada file berubah, jangan lanjut sebelum dipastikan boleh commit/stash.

### 7.2 Gunakan Branch Dasar

Untuk Approval Apps, branch dasar umumnya:

```bash
development
```

Jalankan:

```bash
git checkout development
git pull origin development
```

### 7.3 Buat Branch Client Baru

Contoh project key `clientbaru`:

```bash
git checkout -b clientbaru
```

Kalau branch sudah ada:

```bash
git checkout clientbaru
git pull origin clientbaru
```

### 7.4 Update File `.env`

Isi/update data:

```env
APP_NAME="Client Baru Approval"
ANDROID_ID="com.hashmicro.approval.clientbaru"
IOS_ID="com.hashmicro.approval.clientbaru"
FIREBASE_PROJECT_ID="nama-firebase-project"
BASE_URL="https://client.hashmicro.co"
DEFAULT_DB="nama_database"
```

Jika ada field lain seperti `PORT` atau `TARGET_RELEASE_DATE`, ikuti kebutuhan project.

### 7.5 Update Android Package ID

Di file Android:

- `android/app/build.gradle`
- atau `android/app/build.gradle.kts`

Ubah:

```text
applicationId
namespace
```

Menjadi:

```text
com.hashmicro.approval.clientbaru
```

Update juga package di MainActivity jika ada.

### 7.6 Update iOS Bundle ID

Buka Xcode:

```bash
open ios/Runner.xcworkspace
```

Di Xcode:

1. Klik project `Runner`.
2. Pilih target `Runner`.
3. Buka **Signing & Capabilities**.
4. Ubah **Bundle Identifier** menjadi:
   - `com.hashmicro.approval.clientbaru`
5. Pilih Team Apple Developer yang benar.
6. Pastikan signing tidak error.

### 7.7 Update Nama Aplikasi

Android:

- Update `android:label` di `AndroidManifest.xml`.

IOS:

- Update `CFBundleDisplayName` dan `CFBundleName` di `Info.plist`.

Contoh nama:

```text
Client Baru Approval
```

### 7.8 Setup Firebase

```bash
flutterfire configure
```

Pilih Firebase project yang benar.

### 7.9 Install Dependency

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

### 7.10 Cek Build Dasar

Android:

```bash
flutter build apk --release
```

IOS:

```bash
flutter build ipa --release
```

---

## 8. Membuat App Baru di Google Play Console

Bagian ini untuk Android.

### 8.1 Masuk ke Play Console

1. Buka https://play.google.com/console
2. Login dengan akun Google yang punya akses.
3. Klik **Create app**.

### 8.2 Isi Detail App

Isi form:

- **App name**:
  - HRM: `Client Baru HRIS`
  - Approval: `Client Baru Approval`

- **Default language**:
  - Biasanya `English (United States)` atau sesuai kebutuhan.

- **App or game**:
  - Pilih `App`.

- **Free or paid**:
  - Biasanya `Free`.

- Centang declaration yang diminta.

Klik **Create app**.

### 8.3 Lengkapi App Content

Di sidebar Play Console, lengkapi bagian-bagian yang wajib. Nama menu bisa berubah mengikuti tampilan Google, tapi umumnya meliputi:

1. **Privacy Policy**
   - Isi URL privacy policy.

2. **App access**
   - Jelaskan apakah app butuh login.
   - Jika butuh login, sediakan credential demo/reviewer sesuai kebijakan internal.

3. **Ads**
   - Biasanya pilih tidak ada ads jika memang tidak ada.

4. **Content rating**
   - Isi questionnaire.

5. **Target audience and content**
   - Pilih target audience sesuai app business/internal.

6. **Data safety**
   - Isi data yang dikumpulkan/diproses app.

7. **Government apps** jika muncul
   - Pilih sesuai kondisi app.

8. **Financial features** jika muncul
   - Pilih sesuai kondisi app.

9. **Health apps** jika muncul
   - Pilih sesuai kondisi app.

Penting:

- Jangan asal centang.
- Jika ragu, tanya PIC/lead karena jawaban mempengaruhi review Google.

### 8.4 Lengkapi Store Listing

Masuk ke menu **Store presence** atau **Main store listing**.

Isi:

- App name.
- Short description.
- Full description.
- App icon.
- Feature graphic.
- Phone screenshots.
- Tablet screenshots jika wajib.
- Category.
- Contact email.
- Privacy policy URL.

Untuk HRM Apps, deskripsi harus menjelaskan aplikasi HR/internal company.

Untuk Approval Apps, deskripsi harus menjelaskan aplikasi approval/request internal company.

### 8.5 Upload AAB Pertama

Sebelum upload, build AAB dari project Flutter:

```bash
flutter build appbundle --release
```

File biasanya berada di:

```text
build/app/outputs/bundle/release/app-release.aab
```

Di Play Console:

1. Masuk ke **Testing** atau **Production** sesuai kebutuhan.
2. Pilih track, misalnya:
   - Internal testing untuk test awal.
   - Closed testing jika butuh tester tertentu.
   - Production jika sudah siap release publik/terbatas.
3. Klik **Create new release**.
4. Upload file `.aab`.
5. Isi release notes.
6. Save.
7. Review release.
8. Submit/send for review jika sudah yakin.

### 8.6 Simpan Dashboard/App ID ke Release Hub

Setelah app dibuat, ambil ID Play Console dari URL dashboard.

Contoh URL biasanya mengandung angka panjang seperti:

```text
497xxxxxxxxxxxxxxx
```

Masukkan ke `projects.json` bagian:

```json
"Play Console Dashboard": {
  "HRM Apps": "ID_DARI_PLAY_CONSOLE",
  "Approval Apps": "ID_DARI_PLAY_CONSOLE"
}
```

Jika hanya HRM, isi HRM saja. Jika hanya Approval, isi Approval saja.

---

## 9. Membuat App Baru di Apple Developer dan App Store Connect

Bagian ini untuk iOS.

Ada 2 tempat yang perlu dipahami:

1. **Apple Developer**
   - Untuk membuat Bundle ID / Identifier.

2. **App Store Connect**
   - Untuk membuat halaman app, TestFlight, dan submit review.

### 9.1 Buat Bundle ID di Apple Developer

1. Buka https://developer.apple.com/account
2. Masuk ke **Certificates, Identifiers & Profiles**.
3. Pilih **Identifiers**.
4. Klik tombol `+`.
5. Pilih **App IDs**.
6. Pilih **App**.
7. Isi:
   - Description: nama app, contoh `Client Baru HRIS`.
   - Bundle ID: pilih **Explicit**.
   - Bundle ID value:
     - HRM: `com.hashmicro.eva.clientbaru`
     - Approval: `com.hashmicro.approval.clientbaru`
8. Pilih capability yang dibutuhkan app.
9. Klik Continue/Register.

Capability umum tergantung app, misalnya:

- Push Notifications jika app memakai notification.
- Associated Domains jika app memakai universal link.
- Sign in with Apple jika app memakai fitur tersebut.

Jangan aktifkan capability yang tidak dipakai.

### 9.2 Buat App Baru di App Store Connect

1. Buka https://appstoreconnect.apple.com
2. Masuk ke **My Apps**.
3. Klik tombol `+`.
4. Pilih **New App**.
5. Isi:
   - Platform: `iOS`
   - Name:
     - HRM: `Client Baru HRIS`
     - Approval: `Client Baru Approval`
   - Primary language: sesuai kebutuhan, biasanya English.
   - Bundle ID: pilih Bundle ID yang sudah dibuat.
   - SKU: isi kode unik, biasanya sama dengan project key atau bundle id.
   - User Access: Full Access atau sesuai kebutuhan.
6. Klik **Create**.

### 9.3 Lengkapi Informasi App Store

Di App Store Connect, lengkapi:

1. **App Information**
   - Name.
   - Subtitle jika diperlukan.
   - Category.
   - Content Rights.
   - Age Rating.

2. **Pricing and Availability**
   - Pilih harga/free.
   - Pilih negara availability.

3. **App Privacy**
   - Isi data privacy sesuai data yang dikumpulkan app.

4. **Version Information**
   - Screenshots.
   - Description.
   - Keywords.
   - Support URL.
   - Marketing URL jika ada.
   - Copyright.

5. **App Review Information**
   - Contact information.
   - Notes untuk reviewer.
   - Credential demo jika app butuh login.

Penting:

- Untuk aplikasi internal/client, jelaskan bahwa app digunakan oleh company/client untuk kebutuhan internal.
- Pastikan reviewer bisa login atau memahami cara akses app.

---

## 10. Upload Build ke TestFlight

TestFlight dipakai untuk testing iOS sebelum masuk App Store review.

### 10.1 Pastikan Version dan Build Number Naik

Di Flutter, version ada di `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

Format:

```text
version_name+build_number
```

Contoh:

```text
1.0.1+2
```

Setiap upload ke TestFlight harus punya build number yang lebih tinggi dari sebelumnya.

### 10.2 Build IPA

Dari folder app:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ipa --release
```

File IPA biasanya ada di:

```text
build/ios/ipa/*.ipa
```

### 10.3 Upload IPA ke App Store Connect

Ada beberapa cara upload:

#### Cara A: Transporter App

Ini paling mudah untuk non-teknis.

1. Install **Transporter** dari Mac App Store.
2. Buka Transporter.
3. Login memakai Apple ID developer.
4. Drag file `.ipa` ke Transporter.
5. Klik **Deliver**.
6. Tunggu sampai upload selesai.

#### Cara B: Xcode Organizer

1. Buka Xcode.
2. Menu **Window → Organizer**.
3. Pilih archive terbaru.
4. Klik **Distribute App**.
5. Pilih **App Store Connect**.
6. Ikuti langkah upload.

### 10.4 Tunggu Processing Build

Setelah upload:

1. Buka App Store Connect.
2. Pilih app.
3. Masuk ke tab **TestFlight**.
4. Tunggu build muncul.
5. Status awal biasanya `Processing`.
6. Tunggu sampai build siap dipilih.

Processing bisa memakan waktu beberapa menit sampai lebih lama.

### 10.5 Isi Compliance Jika Diminta

Kadang Apple meminta informasi export compliance/encryption.

Jika muncul pertanyaan:

- Jawab sesuai kondisi app.
- Jika app hanya memakai HTTPS standar dan tidak memakai encryption custom, biasanya mengikuti pilihan standar internal tim.
- Jika ragu, tanyakan ke PIC/lead sebelum submit.

### 10.6 Tambah Tester Internal

1. Buka tab **TestFlight**.
2. Pilih build.
3. Tambahkan internal tester/group.
4. Klik notify tester jika diperlukan.

### 10.7 External Testing / Public Link

Jika butuh tester eksternal:

1. Masuk ke **TestFlight**.
2. Buat atau pilih group external tester.
3. Tambahkan build ke group tersebut.
4. Isi informasi beta review jika diminta.
5. Submit untuk Beta App Review.
6. Setelah approved, aktifkan public link jika dibutuhkan.

Catatan:

- External TestFlight biasanya perlu review Apple terlebih dahulu.
- Public link baru bisa dipakai setelah external testing aktif/approved.

---

## 11. Submit ke App Store Review

Setelah build sudah ada dan app metadata lengkap:

1. Buka App Store Connect.
2. Pilih app.
3. Buka versi app yang akan direlease.
4. Pilih build dari TestFlight/build list.
5. Pastikan semua metadata lengkap:
   - Screenshot.
   - Description.
   - Privacy.
   - Age rating.
   - Review information.
6. Klik **Add for Review** atau **Submit for Review**.
7. Ikuti checklist Apple sampai submit berhasil.

Jika rejected:

1. Baca alasan reject di Resolution Center.
2. Perbaiki app atau metadata.
3. Upload build baru jika perlu.
4. Submit ulang.

---

## 12. Submit ke Google Play Review

Setelah AAB diupload dan semua form Play Console lengkap:

1. Buka app di Play Console.
2. Masuk ke track release yang dipakai.
3. Pastikan release sudah berisi AAB.
4. Isi release notes.
5. Klik **Review release**.
6. Jika tidak ada error, klik submit/send for review.

Jika rejected:

1. Buka Policy Status atau Inbox Play Console.
2. Baca alasan reject.
3. Perbaiki app atau metadata.
4. Upload AAB baru jika perlu.
5. Submit ulang.

---

## 13. Checklist Manual Release

Gunakan checklist ini agar tidak ada yang terlewat.

### Data Project

- [ ] Nama client sudah benar.
- [ ] Project key sudah benar.
- [ ] Region sudah benar.
- [ ] Base URL sudah benar.
- [ ] Database sudah benar.
- [ ] Icon sudah siap.
- [ ] Firebase project sudah jelas.

### Release Hub

- [ ] Project sudah ditambahkan ke `projects.json`.
- [ ] `Type` sudah benar: HRM, Approval, atau keduanya.
- [ ] App name HRM sudah benar.
- [ ] App name Approval sudah benar.
- [ ] Package ID sudah benar.
- [ ] Bundle ID sudah benar.
- [ ] `jq empty projects.json` tidak error.

### HRM Apps

- [ ] Branch client sudah dibuat.
- [ ] `.env` sudah diupdate.
- [ ] Android Package ID sudah diganti.
- [ ] iOS Bundle ID sudah diganti.
- [ ] Nama app sudah diganti.
- [ ] Firebase sudah dikonfigurasi jika diperlukan.
- [ ] `flutter pub get` berhasil.
- [ ] `pod install` berhasil.
- [ ] APK/AAB berhasil dibuild.
- [ ] IPA berhasil dibuild.

### Approval Apps

- [ ] Branch client sudah dibuat.
- [ ] `.env` sudah diupdate.
- [ ] Android Package ID sudah diganti.
- [ ] iOS Bundle ID sudah diganti.
- [ ] Nama app sudah diganti.
- [ ] Firebase sudah dikonfigurasi jika diperlukan.
- [ ] `flutter pub get` berhasil.
- [ ] `pod install` berhasil.
- [ ] APK/AAB berhasil dibuild.
- [ ] IPA berhasil dibuild.

### Google Play Console

- [ ] App baru sudah dibuat.
- [ ] App name benar.
- [ ] Package ID benar.
- [ ] App content lengkap.
- [ ] Store listing lengkap.
- [ ] Privacy policy benar.
- [ ] AAB berhasil diupload.
- [ ] Release notes diisi.
- [ ] Submit review berhasil.
- [ ] Dashboard ID disimpan ke `projects.json`.

### Apple Developer / App Store Connect

- [ ] Bundle ID dibuat di Apple Developer.
- [ ] Capability sesuai kebutuhan.
- [ ] App baru dibuat di App Store Connect.
- [ ] Bundle ID yang dipilih benar.
- [ ] SKU unik.
- [ ] App information lengkap.
- [ ] Pricing and availability lengkap.
- [ ] App privacy lengkap.
- [ ] Screenshot dan metadata lengkap.
- [ ] Build IPA berhasil diupload.
- [ ] Build muncul di TestFlight.
- [ ] Internal tester ditambahkan jika perlu.
- [ ] External testing/public link dibuat jika perlu.
- [ ] Submit App Store Review berhasil.

---

## 14. Urutan Kerja yang Disarankan

Untuk project baru yang punya HRM Apps dan Approval Apps, urutan paling aman:

1. Kumpulkan data client.
2. Tambahkan data ke `projects.json` di Release Hub.
3. Buat/setup branch HRM Apps.
4. Build HRM APK/AAB dan IPA untuk memastikan tidak error.
5. Buat/setup branch Approval Apps.
6. Build Approval APK/AAB dan IPA untuk memastikan tidak error.
7. Buat app HRM di Google Play Console.
8. Buat app Approval di Google Play Console.
9. Buat Bundle ID HRM di Apple Developer.
10. Buat Bundle ID Approval di Apple Developer.
11. Buat app HRM di App Store Connect.
12. Buat app Approval di App Store Connect.
13. Upload AAB HRM ke Play Console.
14. Upload AAB Approval ke Play Console.
15. Upload IPA HRM ke TestFlight.
16. Upload IPA Approval ke TestFlight.
17. Lengkapi metadata Google dan Apple.
18. Submit review Google Play.
19. Submit Beta App Review/TestFlight external jika perlu.
20. Submit App Store Review jika app siap production.

---

## 15. Kesalahan yang Sering Terjadi

### 15.1 Package ID atau Bundle ID Salah

Dampak:

- Play Console menolak AAB.
- App Store Connect tidak menemukan app yang cocok.
- Firebase config salah.

Solusi:

- Cocokkan ID di `projects.json`, Android, Xcode, Firebase, Play Console, dan Apple Developer.

### 15.2 Build Number Tidak Naik

Dampak:

- TestFlight menolak upload.
- Play Console menolak artifact.

Solusi:

- Naikkan build number di `pubspec.yaml`.

Contoh:

```yaml
version: 1.0.1+3
```

### 15.3 Signing iOS Error

Dampak:

- IPA gagal build.

Solusi:

- Cek Xcode Signing & Capabilities.
- Pastikan Team benar.
- Pastikan Bundle ID sudah dibuat.
- Pastikan certificate/provisioning profile tersedia.

### 15.4 App Content Google Belum Lengkap

Dampak:

- Tidak bisa submit review di Play Console.

Solusi:

- Selesaikan semua menu wajib di Play Console sampai tidak ada warning blocking.

### 15.5 Metadata Kurang Lengkap di App Store Connect

Dampak:

- Tidak bisa submit App Store Review.

Solusi:

- Lengkapi screenshot, privacy, age rating, review info, dan build.

---

## 16. Catatan Penting untuk Non-Teknis

- Jangan mengubah Package ID/Bundle ID setelah app sudah dibuat, kecuali benar-benar tahu dampaknya.
- Satu Package ID/Bundle ID hanya untuk satu app.
- Nama app boleh mirip, tapi Package ID/Bundle ID harus unik.
- Untuk setiap upload baru, build number harus naik.
- Jika ada error saat submit, baca pesan error pelan-pelan. Biasanya pesan error menunjukkan field mana yang belum lengkap.
- Jika diminta credential reviewer, jangan kirim password sembarangan di dokumen publik. Ikuti prosedur internal tim.
- Jangan submit production jika belum ada approval dari PIC/lead.

---

## 17. Kapan Perlu Minta Bantuan Teknis

Minta bantuan developer/lead jika:

- `flutter doctor` masih error.
- Android build gagal.
- iOS build gagal.
- Pod install gagal.
- Signing Xcode error.
- Firebase project tidak ditemukan.
- Play Console menolak package name.
- App Store Connect tidak menemukan Bundle ID.
- App review ditolak dan alasannya butuh perubahan kode.

---

## 18. Ringkasan Super Singkat

Jika disingkat, flow manualnya adalah:

1. Setup laptop: Flutter, Xcode, Android Studio, CocoaPods.
2. Siapkan data client.
3. Tambahkan data client ke `projects.json` di Release Hub.
4. Setup branch HRM/Approval Apps.
5. Ganti app name, package ID, bundle ID, base URL, database, Firebase.
6. Build APK/AAB untuk Android.
7. Build IPA untuk iOS.
8. Buat app baru di Play Console.
9. Buat Bundle ID dan app baru di App Store Connect.
10. Upload AAB ke Play Console.
11. Upload IPA ke TestFlight.
12. Lengkapi metadata.
13. Submit review Google dan Apple.
