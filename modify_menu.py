import os

with open('release.sh', 'r') as f:
    content = f.read()

# 1. Tambahkan menu utilities di menu pertama
old_menu_1 = """        echo "============================================================"
        echo "📋 DAFTAR PROJECT"
        echo "============================================================"
"""
new_menu_1 = """        echo "============================================================"
        echo "🔧 UTILITIES (GLOBAL)"
        echo "============================================================"
        echo "A) Record Playwright UI"
        echo "B) Download Play Store Metadata"
        echo "C) Download App Store Metadata"
        echo "============================================================"
        echo "📋 DAFTAR PROJECT"
        echo "============================================================"
"""
content = content.replace(old_menu_1, new_menu_1)

# 2. Ganti prompt menu pertama
old_prompt_1 = "Masukkan nomor project (pisahkan dengan spasi/koma, misal: 2 4 5) atau 'all':"
new_prompt_1 = "Masukkan nomor project (misal: 2 4 5), 'all', atau opsi utilities (A/B/C):"
content = content.replace(old_prompt_1, new_prompt_1)

# 3. Tambahkan handling A, B, C setelah read -r project_input
# Kita cari read -r project_input
target_read = "read -r project_input"
handler_logic = """
        if [[ "$project_input" =~ ^[Aa]$ ]]; then
            echo "============================================================"
            echo "📦 MENYIAPKAN DEPENDENSI AUTOMASI (Playwright)"
            echo "============================================================"
            cd "${SCRIPT_DIR}/automation" || exit 1
            if [ ! -d "node_modules" ]; then
                echo "📦 Menginstal dependensi automation (Playwright)..."
                npm install
                npx playwright install chromium
            fi
            echo "🎥 Membuka Playwright Inspector..."
            npm run record
            exit 0
        elif [[ "$project_input" =~ ^[Bb]$ ]]; then
            ruby "${SCRIPT_DIR}/scripts/download_playstore_metadata.rb"
            exit 0
        elif [[ "$project_input" =~ ^[Cc]$ ]]; then
            ruby "${SCRIPT_DIR}/scripts/download_appstore_metadata.rb"
            exit 0
        fi
"""
content = content.replace(target_read, target_read + handler_logic)

# 4. Hapus dari menu kedua (opsi 4, 11, 18)
# We will just remove the lines that print them
lines_to_remove = [
    'echo " 4) Record Playwright UI"',
    'echo "11) Download Play Store Metadata"',
    'echo "18) Download App Store Metadata"'
]
for line in lines_to_remove:
    content = content.replace(line + '\n', '')

# We also should probably remove them from the execute_action function, but leaving them there is harmless as they won't be called.
# To be clean, let's remove them from the "📦 MENYIAPKAN DEPENDENSI AUTOMASI (Playwright)" check
content = content.replace('[[ " ${ACTION_ARRAY[*]} " =~ " 4 " ]] || ', '')

with open('release.sh', 'w') as f:
    f.write(content)

