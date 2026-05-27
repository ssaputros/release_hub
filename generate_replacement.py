old_content = """                echo "============================================================"
                echo "🛠️ PILIH AKSI UNTUK: $local_input"
                echo "============================================================"
                echo " 1) Full (Semua proses)"
                echo " 2) Setup Konfigurasi"
                echo " 3) Build APK & AAB"
                echo " 4) Build IPA"
                echo " 5) Upload Drive"
                echo " 6) Upload TestFlight"
                echo " 7) Submit TestFlight (Lewati Upload IPA)"
                echo " 8) Create Playstore App"
                echo " 9) Setup Playstore App Information"
                echo "10) Setup Store Listing"
                echo "11) Record Playwright UI"
                echo "12) Update Play Console Dashboard ID"
                echo "13) Bump Version"
                echo "14) Push Playstore Listing"
                echo "15) Download App Store Metadata"
                echo "16) Push App Store Metadata"
                echo "17) Download Play Store Metadata"
                echo "18) Setup App Store Info"
                echo "19) Request Unlisted App Distribution"
                echo "20) Submit for App Review"
                echo "------------------------------------------------------------"
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 3 5 12): "
                read -r action_choice

                # Ganti koma dengan spasi dan tambahkan spasi di awal/akhir agar pengecekan angka lebih aman (mencegah 10 terbaca sebagai 1)
                clean_choice=" $(echo "$action_choice" | tr ',' ' ') "

                if [[ "$clean_choice" == *" 1 "* ]]; then
                    OPT_SETUP=true
                    OPT_BUILD=true
                    export BUILD_TARGET_APK=true
                    export BUILD_TARGET_IPA=true
                    OPT_UPLOAD_DRIVE=true
                    OPT_UPLOAD_TESTFLIGHT=true
                else
                    if [[ "$clean_choice" == *" 2 "* ]]; then OPT_SETUP=true; fi
                    if [[ "$clean_choice" == *" 3 "* ]]; then OPT_BUILD=true; export BUILD_TARGET_APK=true; fi
                    if [[ "$clean_choice" == *" 4 "* ]]; then OPT_BUILD=true; export BUILD_TARGET_IPA=true; fi
                    if [[ "$clean_choice" == *" 5 "* ]]; then OPT_UPLOAD_DRIVE=true; fi
                    if [[ "$clean_choice" == *" 6 "* ]]; then OPT_UPLOAD_TESTFLIGHT=true; fi
                    if [[ "$clean_choice" == *" 7 "* ]]; then 
                        OPT_UPLOAD_TESTFLIGHT=true
                        export SKIP_UPLOAD=true
                    fi

                    if [[ "$clean_choice" == *" 8 "* ]] || [[ "$clean_choice" == *" 9 "* ]] || [[ "$clean_choice" == *" 10 "* ]] || [[ "$clean_choice" == *" 11 "* ]] || [[ "$clean_choice" == *" 12 "* ]] || [[ "$clean_choice" == *" 13 "* ]] || [[ "$clean_choice" == *" 14 "* ]] || [[ "$clean_choice" == *" 15 "* ]] || [[ "$clean_choice" == *" 16 "* ]] || [[ "$clean_choice" == *" 17 "* ]] || [[ "$clean_choice" == *" 18 "* ]] || [[ "$clean_choice" == *" 19 "* ]] || [[ "$clean_choice" == *" 20 "* ]]; then
                        echo "============================================================"
                        echo "🤖 MENYIAPKAN AUTOMASI / SETUP STORE"
                        echo "============================================================"
                        
                        # Hanya install dan masuk ke folder automation jika memilih opsi Playwright
                        if [[ "$clean_choice" == *" 8 "* ]] || [[ "$clean_choice" == *" 9 "* ]] || [[ "$clean_choice" == *" 10 "* ]] || [[ "$clean_choice" == *" 11 "* ]] || [[ "$clean_choice" == *" 12 "* ]]; then
                            cd "${SCRIPT_DIR}/automation" || exit 1
                            if [ ! -d "node_modules" ]; then
                                echo "📦 Menginstal dependensi automation (Playwright)..."
                                npm install
                                npx playwright install chromium
                            fi
                            
                            if [ ! -d "${SCRIPT_DIR}/credentials/.chrome_profile" ]; then
                                echo "⚠️ Profil Chrome (Login Play Console) belum ditemukan."
                                npm run auth
                            fi
                        fi
                        
                        if [[ "$clean_choice" == *" 12 "* ]]; then
                            node update_dashboard_id.js "$TARGET_ID" || echo "❌ update_dashboard_id.js gagal dijalankan."
                        fi
                        
                        if [[ "$clean_choice" == *" 8 "* ]]; then
                            if node create_app.js "$TARGET_ID"; then
                                if [[ "$clean_choice" != *" 9 "* ]]; then
                                    echo "🚀 Otomatis melanjutkan ke Setup Playstore App Information (Langkah 9)..."
                                    node runner_app_info.js "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                                fi
                            else
                                echo "❌ create_app.js gagal dijalankan."
                            fi
                        fi
                        
                        if [[ "$clean_choice" == *" 9 "* ]]; then
                            node runner_app_info.js "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                        fi

                        if [[ "$clean_choice" == *" 11 "* ]]; then
                            echo "🎥 Membuka Playwright Inspector..."
                            npm run record
                        fi
                        
                        # Kembali ke direktori utama
                        cd "${SCRIPT_DIR}" || exit 1
                        
                        if [ -z "$FILTERED_TYPE" ]; then
                            ACTIVE_TYPES=$(jq -r ".\"$TARGET_ID\".Project.Type // empty" "$PROJECT_FILE")
                        else
                            ACTIVE_TYPES="$FILTERED_TYPE"
                        fi
                        IFS=',' read -ra ACTIVE_TYPES_ARR <<< "$ACTIVE_TYPES"
                        
                        for current_type in "${ACTIVE_TYPES_ARR[@]}"; do
                            current_type=$(echo "$current_type" | xargs)
                            
                            if [[ "$clean_choice" == *" 13 "* ]] || [[ "$clean_choice" == *" 14 "* ]] || [[ "$clean_choice" == *" 15 "* ]] || [[ "$clean_choice" == *" 16 "* ]] || [[ "$clean_choice" == *" 17 "* ]] || [[ "$clean_choice" == *" 18 "* ]] || [[ "$clean_choice" == *" 19 "* ]] || [[ "$clean_choice" == *" 10 "* ]]; then
                                echo "============================================================"
                                echo "🚀 MENJALANKAN SETUP UNTUK: $current_type"
                                echo "============================================================"
                            fi

                            if [[ "$clean_choice" == *" 10 "* ]]; then
                                echo "============================================================"
                                echo "🛠️ PILIH METODE SETUP STORE LISTING"
                                echo "============================================================"
                                echo "1) Fastlane API (Direct upload, cepat & tanpa browser)"
                                echo "2) Playwright Browser (Semi-otomatis lewat UI browser)"
                                echo "------------------------------------------------------------"
                                echo -n "Pilihan Anda (default: 1): "
                                read -r method_choice
                                
                                if [[ "$method_choice" == "2" ]]; then
                                    node "${SCRIPT_DIR}/automation/runner_store_listing.js" "$TARGET_ID" || echo "❌ runner_store_listing.js gagal dijalankan."
                                else
                                    ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$current_type" || echo "❌ update_store_listing.rb gagal dijalankan."
                                fi
                            fi

                            if [[ "$clean_choice" == *" 13 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/bump_version.rb" "$TARGET_ID" "$current_type" || echo "❌ bump_version.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 14 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$current_type" || echo "❌ update_store_listing.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 15 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/download_appstore_metadata.rb" "$TARGET_ID" "$current_type" || echo "❌ download_appstore_metadata.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 16 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "$TARGET_ID" "$current_type" || echo "❌ push_appstore_metadata.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 17 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/download_playstore_metadata.rb" "$TARGET_ID" "$current_type" || echo "❌ download_playstore_metadata.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 18 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/setup_appstore_info.rb" "$TARGET_ID" "$current_type" || echo "❌ setup_appstore_info.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 19 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/request_unlisted_app.rb" "$TARGET_ID" "$current_type" || echo "❌ request_unlisted_app.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 20 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/submit_appstore_version.rb" "$TARGET_ID" "$current_type" || echo "❌ submit_appstore_version.rb gagal dijalankan."
                            fi
                        done
                        exit 0
                    fi
                fi"""

new_content = """                echo "============================================================"
                echo "🛠️ PILIH AKSI UNTUK: $local_input"
                echo "============================================================"
                echo "🤖 [ FASE UMUM & SETUP ]"
                echo " 1) Full (Semua proses)"
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
                echo -n "Pilihan Anda (pisahkan dengan spasi/koma, misal: 2 6 9 13): "
                read -r action_choice

                # Ganti koma dengan spasi dan tambahkan spasi di awal/akhir agar pengecekan angka lebih aman (mencegah 10 terbaca sebagai 1)
                clean_choice=" $(echo "$action_choice" | tr ',' ' ') "

                if [[ "$clean_choice" == *" 1 "* ]]; then
                    OPT_SETUP=true
                    OPT_BUILD=true
                    export BUILD_TARGET_APK=true
                    export BUILD_TARGET_IPA=true
                    OPT_UPLOAD_DRIVE=true
                    OPT_UPLOAD_TESTFLIGHT=true
                else
                    if [[ "$clean_choice" == *" 2 "* ]]; then OPT_SETUP=true; fi
                    if [[ "$clean_choice" == *" 6 "* ]]; then OPT_BUILD=true; export BUILD_TARGET_APK=true; fi
                    if [[ "$clean_choice" == *" 13 "* ]]; then OPT_BUILD=true; export BUILD_TARGET_IPA=true; fi
                    if [[ "$clean_choice" == *" 5 "* ]]; then OPT_UPLOAD_DRIVE=true; fi
                    if [[ "$clean_choice" == *" 14 "* ]]; then OPT_UPLOAD_TESTFLIGHT=true; fi
                    if [[ "$clean_choice" == *" 15 "* ]]; then 
                        OPT_UPLOAD_TESTFLIGHT=true
                        export SKIP_UPLOAD=true
                    fi

                    if [[ "$clean_choice" == *" 3 "* ]] || [[ "$clean_choice" == *" 4 "* ]] || [[ "$clean_choice" == *" 7 "* ]] || [[ "$clean_choice" == *" 8 "* ]] || [[ "$clean_choice" == *" 9 "* ]] || [[ "$clean_choice" == *" 10 "* ]] || [[ "$clean_choice" == *" 11 "* ]] || [[ "$clean_choice" == *" 12 "* ]] || [[ "$clean_choice" == *" 16 "* ]] || [[ "$clean_choice" == *" 17 "* ]] || [[ "$clean_choice" == *" 18 "* ]] || [[ "$clean_choice" == *" 19 "* ]] || [[ "$clean_choice" == *" 20 "* ]]; then
                        echo "============================================================"
                        echo "🤖 MENYIAPKAN AUTOMASI / SETUP STORE"
                        echo "============================================================"
                        
                        # Hanya install dan masuk ke folder automation jika memilih opsi Playwright
                        if [[ "$clean_choice" == *" 4 "* ]] || [[ "$clean_choice" == *" 7 "* ]] || [[ "$clean_choice" == *" 8 "* ]] || [[ "$clean_choice" == *" 9 "* ]] || [[ "$clean_choice" == *" 12 "* ]]; then
                            cd "${SCRIPT_DIR}/automation" || exit 1
                            if [ ! -d "node_modules" ]; then
                                echo "📦 Menginstal dependensi automation (Playwright)..."
                                npm install
                                npx playwright install chromium
                            fi
                            
                            if [ ! -d "${SCRIPT_DIR}/credentials/.chrome_profile" ]; then
                                echo "⚠️ Profil Chrome (Login Play Console) belum ditemukan."
                                npm run auth
                            fi
                        fi
                        
                        if [[ "$clean_choice" == *" 12 "* ]]; then
                            node update_dashboard_id.js "$TARGET_ID" || echo "❌ update_dashboard_id.js gagal dijalankan."
                        fi
                        
                        if [[ "$clean_choice" == *" 7 "* ]]; then
                            if node create_app.js "$TARGET_ID"; then
                                if [[ "$clean_choice" != *" 8 "* ]]; then
                                    echo "🚀 Otomatis melanjutkan ke Setup Playstore App Information (Langkah 8)..."
                                    node runner_app_info.js "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                                fi
                            else
                                echo "❌ create_app.js gagal dijalankan."
                            fi
                        fi
                        
                        if [[ "$clean_choice" == *" 8 "* ]]; then
                            node runner_app_info.js "$TARGET_ID" || echo "❌ runner_app_info.js gagal dijalankan."
                        fi

                        if [[ "$clean_choice" == *" 4 "* ]]; then
                            echo "🎥 Membuka Playwright Inspector..."
                            npm run record
                        fi
                        
                        # Kembali ke direktori utama
                        cd "${SCRIPT_DIR}" || exit 1
                        
                        if [ -z "$FILTERED_TYPE" ]; then
                            ACTIVE_TYPES=$(jq -r ".\"$TARGET_ID\".Project.Type // empty" "$PROJECT_FILE")
                        else
                            ACTIVE_TYPES="$FILTERED_TYPE"
                        fi
                        IFS=',' read -ra ACTIVE_TYPES_ARR <<< "$ACTIVE_TYPES"
                        
                        for current_type in "${ACTIVE_TYPES_ARR[@]}"; do
                            current_type=$(echo "$current_type" | xargs)
                            
                            if [[ "$clean_choice" == *" 3 "* ]] || [[ "$clean_choice" == *" 9 "* ]] || [[ "$clean_choice" == *" 10 "* ]] || [[ "$clean_choice" == *" 11 "* ]] || [[ "$clean_choice" == *" 16 "* ]] || [[ "$clean_choice" == *" 17 "* ]] || [[ "$clean_choice" == *" 18 "* ]] || [[ "$clean_choice" == *" 19 "* ]] || [[ "$clean_choice" == *" 20 "* ]]; then
                                echo "============================================================"
                                echo "🚀 MENJALANKAN SETUP UNTUK: $current_type"
                                echo "============================================================"
                            fi

                            if [[ "$clean_choice" == *" 9 "* ]]; then
                                echo "============================================================"
                                echo "🛠️ PILIH METODE SETUP STORE LISTING"
                                echo "============================================================"
                                echo "1) Fastlane API (Direct upload, cepat & tanpa browser)"
                                echo "2) Playwright Browser (Semi-otomatis lewat UI browser)"
                                echo "------------------------------------------------------------"
                                echo -n "Pilihan Anda (default: 1): "
                                read -r method_choice
                                
                                if [[ "$method_choice" == "2" ]]; then
                                    node "${SCRIPT_DIR}/automation/runner_store_listing.js" "$TARGET_ID" || echo "❌ runner_store_listing.js gagal dijalankan."
                                else
                                    ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$current_type" || echo "❌ update_store_listing.rb gagal dijalankan."
                                fi
                            fi

                            if [[ "$clean_choice" == *" 3 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/bump_version.rb" "$TARGET_ID" "$current_type" || echo "❌ bump_version.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 10 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/update_store_listing.rb" "$TARGET_ID" "$current_type" || echo "❌ update_store_listing.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 18 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/download_appstore_metadata.rb" "$TARGET_ID" "$current_type" || echo "❌ download_appstore_metadata.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 17 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/push_appstore_metadata.rb" "$TARGET_ID" "$current_type" || echo "❌ push_appstore_metadata.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 11 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/download_playstore_metadata.rb" "$TARGET_ID" "$current_type" || echo "❌ download_playstore_metadata.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 16 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/setup_appstore_info.rb" "$TARGET_ID" "$current_type" || echo "❌ setup_appstore_info.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 19 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/request_unlisted_app.rb" "$TARGET_ID" "$current_type" || echo "❌ request_unlisted_app.rb gagal dijalankan."
                            fi

                            if [[ "$clean_choice" == *" 20 "* ]]; then
                                ruby "${SCRIPT_DIR}/scripts/submit_appstore_version.rb" "$TARGET_ID" "$current_type" || echo "❌ submit_appstore_version.rb gagal dijalankan."
                            fi
                        done
                        exit 0
                    fi
                fi"""

import sys

with open("release.sh", "r") as f:
    content = f.read()

if old_content in content:
    content = content.replace(old_content, new_content)
    with open("release.sh", "w") as f:
        f.write(content)
    print("SUCCESS: Menu replaced successfully!")
else:
    print("FAILED: Old content not found.")

