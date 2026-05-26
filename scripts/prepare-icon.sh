#!/bin/bash

# Inisialisasi variabel
ICON_URL="$1"
SIZE="${2:-1024}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
ICON_DIR="${ROOT_DIR}/icon"
RAW_ICON="${ICON_DIR}/icon_raw"
OPTIMIZED_ICON="${ICON_DIR}/icon.png"

# Pastikan folder icon ada
mkdir -p "$ICON_DIR"
rm -f "$OPTIMIZED_ICON"

if [ -z "$ICON_URL" ]; then
    echo "⚠️ Peringatan: URL icon tidak diberikan."
    exit 0
fi

echo "⬇️ Mengunduh icon dari: $ICON_URL"

# Cek apakah ini URL Google Drive
if [[ "$ICON_URL" == *"drive.google.com"* ]]; then
    # Ekstrak ID dari URL Google Drive
    FILE_ID=$(echo "$ICON_URL" | sed -E 's/.*(id=|d\/)([a-zA-Z0-9_-]+).*/\2/')
    DOWNLOAD_URL="https://drive.google.com/uc?export=download&id=${FILE_ID}"
    curl -sL -o "$RAW_ICON" "$DOWNLOAD_URL"
else
    curl -sL -o "$RAW_ICON" "$ICON_URL"
fi

if [ ! -s "$RAW_ICON" ]; then
    echo "❌ Gagal mengunduh icon."
    rm -f "$RAW_ICON"
    exit 1
fi

# Deteksi apakah gambar adalah icon default berdasarkan MD5 hash
MD5_HASH=""
if command -v md5 >/dev/null 2>&1; then
    MD5_HASH=$(md5 -q "$RAW_ICON")
elif command -v md5sum >/dev/null 2>&1; then
    MD5_HASH=$(md5sum "$RAW_ICON" | awk '{print $1}')
fi

if [ "$MD5_HASH" == "d07b84363bb9d56771e6cea4f327d285" ]; then
    echo "ℹ️  Gambar terdeteksi sebagai Default Icon. Menggunakan icon bawaan project."
    rm -f "$RAW_ICON"
    exit 0
fi

echo "⚙️ Mengoptimalkan icon (Safe Zone 15% padding, background putih)..."

# Gunakan script Python untuk optimasi icon
if command -v python3 >/dev/null 2>&1; then
    python3 "${SCRIPT_DIR}/optimize_icon.py" "$RAW_ICON" "$OPTIMIZED_ICON" "$SIZE"
else
    echo "⚠️ Command 'python3' tidak ditemukan. Menyimpan as is..."
    cp "$RAW_ICON" "$OPTIMIZED_ICON"
fi

# Bersihkan file raw
rm -f "$RAW_ICON"
