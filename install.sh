#!/bin/bash

# Dapatkan direktori absolut dari tempat script ini berada
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RELEASE_SCRIPT="${SCRIPT_DIR}/release.sh"
ZSHRC="$HOME/.zshrc"

echo "Mempersiapkan release.sh agar bisa dijalankan..."
chmod +x "$RELEASE_SCRIPT"

echo "Menambahkan alias ke ~/.zshrc..."
# Cek apakah alias sudah ada untuk menghindari duplikasi
if ! grep -q "alias release=" "$ZSHRC"; then
    echo -e "\n# release_hub scripts" >> "$ZSHRC"
    echo "alias release.sh='$RELEASE_SCRIPT'" >> "$ZSHRC"
    echo "alias release='$RELEASE_SCRIPT'" >> "$ZSHRC"
    echo "✓ Alias berhasil ditambahkan."
else
    echo "ℹ Alias sudah ada di ~/.zshrc, melewati penambahan alias."
fi

echo "================================================="
echo "Selesai! Agar bisa langsung digunakan, jalankan:"
echo "source ~/.zshrc"
echo "================================================="
