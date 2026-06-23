Goals:
1. Bisa build apk & otomatis upload ke google drive
2. Bisa build ipa & otomatis buat testflight external
3. Bisa create new app di playstore console
4. Bisa release ipa to appstore
5. Push new metadata to playstore and appstore
6. Pull metadata template dari playstore dan appstore

## CLI non-interactive

`release.sh` masih bisa dibuka sebagai menu interaktif jika dipanggil tanpa argumen.
Untuk automation/cron/CI, jalankan langsung dengan project id dan nomor aksi:

```bash
./release.sh <project_id> --action "20 22" --app-type "HRM Apps"
```

Opsi penting:

- `-a, --action "20 22"`: daftar nomor aksi, dipisah spasi atau koma.
- `--app-type "HRM Apps"`: filter tipe app untuk project yang punya beberapa tipe.
- `--dry-run`: tampilkan target dan aksi tanpa build/upload/release.
- `--non-interactive`: gagal cepat kalau argumen wajib kurang; tidak menunggu input.
- `-h, --help`: tampilkan bantuan CLI.

Contoh aman untuk validasi command:

```bash
./release.sh smkgemanusantara -a "20,22" --app-type "HRM Apps" --dry-run
```

Contoh build Android tanpa prompt:

```bash
./release.sh smkgemanusantara -a "20 22" --app-type "HRM Apps"
```

Contoh upload-only tanpa prompt:

```bash
./release.sh -u smkgemanusantara
./release.sh -t smkgemanusantara
```
