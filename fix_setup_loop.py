import sys

with open("release.sh", "r") as f:
    content = f.read()

# We need to find the block:
#     bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }
# 
#     # Eksekusi script setup dinamis berdasarkan Type
#     IFS=',' read -ra ADDR <<< "$TYPE"

# And replace it to insert the fi for OPT_SETUP and the new if [ "$OPT_SETUP" = true ] inside the loop

target = """    bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }

    # Eksekusi script setup dinamis berdasarkan Type
    IFS=',' read -ra ADDR <<< "$TYPE"
    for type_item in "${ADDR[@]}"; do
        type_clean=$(echo "$type_item" | xargs)
        type_slug=$(echo "$type_clean" | tr 'A-Z' 'a-z' | tr ' ' '_')
        
        script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
        
        if [ -f "$script_file" ]; then"""

replacement = """    bash "${SCRIPT_DIR}/scripts/rebrand.sh" "$APP_PACKAGE_NAME" || { echo "❌ Proses rebrand gagal!"; exit 1; }
fi

# Eksekusi loop per-tipe untuk setup dinamis, build, dan upload
IFS=',' read -ra ADDR <<< "$TYPE"
for type_item in "${ADDR[@]}"; do
    type_clean=$(echo "$type_item" | xargs)
    type_slug=$(echo "$type_clean" | tr 'A-Z' 'a-z' | tr ' ' '_')
    
    if [ "$OPT_SETUP" = true ]; then
        script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
        
        if [ -f "$script_file" ]; then"""

if target in content:
    content = content.replace(target, replacement)
else:
    print("Error: Target block not found")
    sys.exit(1)

# Now we need to close the `if [ "$OPT_SETUP" = true ]; then` before STAGE 2
target2 = """            echo "============================================================"
        fi
    
# STAGE 2: BUILD"""

replacement2 = """            echo "============================================================"
        fi
    fi
    
# STAGE 2: BUILD"""

if target2 in content:
    content = content.replace(target2, replacement2)
else:
    print("Error: Target2 block not found")
    sys.exit(1)

with open("release.sh", "w") as f:
    f.write(content)

print("Berhasil memperbaiki struktur blok OPT_SETUP!")
