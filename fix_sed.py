import os

with open('release.sh', 'r') as f:
    content = f.read()

lines_to_remove = [
    'echo " 4) Record Playwright UI"',
    'echo "11) Download Play Store Metadata"',
    'echo "18) Download App Store Metadata"'
]
for line in lines_to_remove:
    content = content.replace(line + '\n', '')

content = content.replace('[[ " ${ACTION_ARRAY[*]} " =~ " 4 " ]] || ', '')

# remove case 4
case_4 = """            4) 
                echo "🎥 Membuka Playwright Inspector..."
                npm run record
                continue
                ;;
"""
content = content.replace(case_4, '')

# remove case 11
case_11 = """                11) ruby "${SCRIPT_DIR}/scripts/download_playstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ download_playstore_metadata.rb gagal dijalankan." ;;
"""
content = content.replace(case_11, '')

# remove case 18
case_18 = """                18) ruby "${SCRIPT_DIR}/scripts/download_appstore_metadata.rb" "$TARGET_ID" "$type_clean" || echo "❌ download_appstore_metadata.rb gagal dijalankan." ;;
"""
content = content.replace(case_18, '')

with open('release.sh', 'w') as f:
    f.write(content)
