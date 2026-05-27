import re

with open("release.sh", "r") as f:
    lines = f.readlines()

def replace_lines(start_idx, end_idx, new_lines):
    return lines[:start_idx] + new_lines + lines[end_idx:]

# 1. Update Menu (Lines 368 to 389 - 0 indexed: 367 to 389)
# Finding the menu block exactly
start_menu = -1
end_menu = -1
for i, line in enumerate(lines):
    if "echo \" 1) Full (Semua proses)\"" in line:
        start_menu = i
    if "echo -n \"Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 3 5 12): \"" in line:
        end_menu = i
        break

menu_text = """                echo "🤖 [ FASE UMUM & SETUP ]"
                echo " 1) Full (Semua proses Utama)"
                echo " 2) Setup Konfigurasi"
                echo " 3) Bump Version"
                echo " 4) Record Playwright UI"
                echo " 5) Upload APK & IPA ke Google Drive"
                echo "------------------------------------------------------------"
                echo "🤖 [ FASE ANDROID / PLAY STORE ]"
                echo " 6) Build APK & AAB"
                echo " 7) Create Playstore App"
                echo " 8) Setup Playstore App Information"
                echo " 9) Setup Store Listing"
                echo "10) Push Playstore Listing"
                echo "11) Download Play Store Metadata"
                echo "12) Update Play Console Dashboard ID"
                echo "------------------------------------------------------------"
                echo "🤖 [ FASE IOS / APP STORE ]"
                echo "13) Build IPA"
                echo "14) Upload TestFlight"
                echo "15) Submit TestFlight (Lewati Upload IPA)"
                echo "16) Setup App Store Info"
                echo "17) Push App Store Metadata"
                echo "18) Download App Store Metadata"
                echo "19) Request Unlisted App Distribution"
                echo "20) Submit for App Review"
                echo "------------------------------------------------------------"
"""
lines = lines[:start_menu] + [menu_text] + lines[end_menu:]

# Now re-read lines array and fix the prompt
for i, line in enumerate(lines):
    if "echo -n \"Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 3 5 12): \"" in line:
        lines[i] = "                echo -n \"Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 6 9 13): \"\n"

# 2. Fix the initial if/else checks
for i, line in enumerate(lines):
    if "if [[ \"$clean_choice\" == *\" 2 \"* ]]; then OPT_SETUP=true; fi" in line:
        lines[i] = "                    if [[ \"$clean_choice\" == *\" 2 \"* ]]; then OPT_SETUP=true; fi\n"
    if "if [[ \"$clean_choice\" == *\" 3 \"* ]]; then OPT_BUILD=true; export BUILD_TARGET_APK=true; fi" in line:
        lines[i] = "                    if [[ \"$clean_choice\" == *\" 6 \"* ]]; then OPT_BUILD=true; export BUILD_TARGET_APK=true; fi\n"
    if "if [[ \"$clean_choice\" == *\" 4 \"* ]]; then OPT_BUILD=true; export BUILD_TARGET_IPA=true; fi" in line:
        lines[i] = "                    if [[ \"$clean_choice\" == *\" 13 \"* ]]; then OPT_BUILD=true; export BUILD_TARGET_IPA=true; fi\n"
    if "if [[ \"$clean_choice\" == *\" 5 \"* ]]; then OPT_UPLOAD_DRIVE=true; fi" in line:
        lines[i] = "                    if [[ \"$clean_choice\" == *\" 5 \"* ]]; then OPT_UPLOAD_DRIVE=true; fi\n"
    if "if [[ \"$clean_choice\" == *\" 6 \"* ]]; then OPT_UPLOAD_TESTFLIGHT=true; fi" in line:
        lines[i] = "                    if [[ \"$clean_choice\" == *\" 14 \"* ]]; then OPT_UPLOAD_TESTFLIGHT=true; fi\n"
    if "if [[ \"$clean_choice\" == *\" 7 \"* ]]; then " in line:
        lines[i] = "                    if [[ \"$clean_choice\" == *\" 15 \"* ]]; then \n"
        
    # Big if check:
    if "if [[ \"$clean_choice\" == *\" 8 \"* ]] || [[ \"$clean_choice\" == *\" 9 \"* ]]" in line:
        lines[i] = "                    if [[ \"$clean_choice\" == *\" 3 \"* ]] || [[ \"$clean_choice\" == *\" 4 \"* ]] || [[ \"$clean_choice\" == *\" 7 \"* ]] || [[ \"$clean_choice\" == *\" 8 \"* ]] || [[ \"$clean_choice\" == *\" 9 \"* ]] || [[ \"$clean_choice\" == *\" 10 \"* ]] || [[ \"$clean_choice\" == *\" 11 \"* ]] || [[ \"$clean_choice\" == *\" 12 \"* ]] || [[ \"$clean_choice\" == *\" 16 \"* ]] || [[ \"$clean_choice\" == *\" 17 \"* ]] || [[ \"$clean_choice\" == *\" 18 \"* ]] || [[ \"$clean_choice\" == *\" 19 \"* ]] || [[ \"$clean_choice\" == *\" 20 \"* ]]; then\n"

    # Playwright nodes
    if "if [[ \"$clean_choice\" == *\" 8 \"* ]] || [[ \"$clean_choice\" == *\" 9 \"* ]] || [[ \"$clean_choice\" == *\" 10 \"* ]] || [[ \"$clean_choice\" == *\" 11 \"* ]] || [[ \"$clean_choice\" == *\" 12 \"* ]]; then" in line:
        lines[i] = "                        if [[ \"$clean_choice\" == *\" 4 \"* ]] || [[ \"$clean_choice\" == *\" 7 \"* ]] || [[ \"$clean_choice\" == *\" 8 \"* ]] || [[ \"$clean_choice\" == *\" 9 \"* ]] || [[ \"$clean_choice\" == *\" 12 \"* ]]; then\n"
        
    if "if [[ \"$clean_choice\" == *\" 12 \"* ]]; then\n                            node update_dashboard_id.js" in "".join(lines[i:i+2]):
        pass # already 12
    elif "if [[ \"$clean_choice\" == *\" 8 \"* ]]; then\n                            if node create_app.js" in "".join(lines[i:i+2]):
        lines[i] = "                        if [[ \"$clean_choice\" == *\" 7 \"* ]]; then\n"
    elif "if [[ \"$clean_choice\" != *\" 9 \"* ]]; then" in line:
        lines[i] = "                                if [[ \"$clean_choice\" != *\" 8 \"* ]]; then\n"
    elif "echo \"🚀 Otomatis melanjutkan ke Setup Playstore App Information (Langkah 9)...\"" in line:
        lines[i] = "                                    echo \"🚀 Otomatis melanjutkan ke Setup Playstore App Information (Langkah 8)...\"\n"
    elif "if [[ \"$clean_choice\" == *\" 9 \"* ]]; then\n                            node runner_app_info.js" in "".join(lines[i:i+2]):
        lines[i] = "                        if [[ \"$clean_choice\" == *\" 8 \"* ]]; then\n"
    elif "if [[ \"$clean_choice\" == *\" 11 \"* ]]; then\n                            echo \"🎥 Membuka Playwright Inspector...\"" in "".join(lines[i:i+2]):
        lines[i] = "                        if [[ \"$clean_choice\" == *\" 4 \"* ]]; then\n"

    # Fastlane array loops
    if "if [[ \"$clean_choice\" == *\" 13 \"* ]] || [[ \"$clean_choice\" == *\" 14 \"* ]] || [[ \"$clean_choice\" == *\" 15 \"* ]] || [[ \"$clean_choice\" == *\" 16 \"* ]] || [[ \"$clean_choice\" == *\" 17 \"* ]] || [[ \"$clean_choice\" == *\" 18 \"* ]] || [[ \"$clean_choice\" == *\" 19 \"* ]] || [[ \"$clean_choice\" == *\" 10 \"* ]]; then" in line:
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 3 \"* ]] || [[ \"$clean_choice\" == *\" 9 \"* ]] || [[ \"$clean_choice\" == *\" 10 \"* ]] || [[ \"$clean_choice\" == *\" 11 \"* ]] || [[ \"$clean_choice\" == *\" 16 \"* ]] || [[ \"$clean_choice\" == *\" 17 \"* ]] || [[ \"$clean_choice\" == *\" 18 \"* ]] || [[ \"$clean_choice\" == *\" 19 \"* ]] || [[ \"$clean_choice\" == *\" 20 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 10 \"* ]]; then\n                                echo \"============================================================\"\n                                echo \"🛠️ PILIH METODE SETUP STORE LISTING\"" in "".join(lines[i:i+3]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 9 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 13 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/bump_version.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 3 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 14 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/update_store_listing.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 10 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 15 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/download_appstore_metadata.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 18 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 16 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/push_appstore_metadata.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 17 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 17 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/download_playstore_metadata.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 11 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 18 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/setup_appstore_info.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 16 \"* ]]; then\n"
        
    if "if [[ \"$clean_choice\" == *\" 19 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/request_unlisted_app.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 19 \"* ]]; then\n"

    if "if [[ \"$clean_choice\" == *\" 20 \"* ]]; then\n                                ruby \"${SCRIPT_DIR}/scripts/submit_appstore_version.rb\"" in "".join(lines[i:i+2]):
        lines[i] = "                            if [[ \"$clean_choice\" == *\" 20 \"* ]]; then\n"

with open("release.sh", "w") as f:
    f.writelines(lines)

print("Menu reordered and logic remapped successfully!")
