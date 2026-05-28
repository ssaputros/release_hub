import sys

with open("release.sh", "r") as f:
    content = f.read()

target = """                if [ "$OPT_SETUP" = false ] && [ "$OPT_BUILD" = false ] && [ "$OPT_UPLOAD_DRIVE" = false ] && [ "$OPT_UPLOAD_TESTFLIGHT" = false ]; then
                    echo "❌ Pilihan tidak valid."
                    exit 1
                fi
if [ -n "$PROJECT" ] && [ ${#SELECTED_TARGETS[@]} -eq 0 ]; then
        echo "❌ Error: Project dengan ID '$TARGET_ID' tidak ditemukan di projects.json, atau jq tidak terinstall."
        exit 1
    fi
else"""

replacement = """                if [ "$OPT_SETUP" = false ] && [ "$OPT_BUILD" = false ] && [ "$OPT_UPLOAD_DRIVE" = false ] && [ "$OPT_UPLOAD_TESTFLIGHT" = false ]; then
                    echo "❌ Pilihan tidak valid."
                    exit 1
                fi
    fi
fi

if [ -n "$PROJECT" ] && [ ${#SELECTED_TARGETS[@]} -eq 0 ]; then"""

if target in content:
    content = content.replace(target, replacement)
    with open("release.sh", "w") as f:
        f.write(content)
    print("Fixed the missing fi block!")
else:
    print("Target block not found, let's search it.")

