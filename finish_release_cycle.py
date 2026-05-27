import re

with open("release.sh", "r") as f:
    content = f.read()

# We need to find the STAGE 2 and STAGE 3 blocks and move them into the `for type_item in "${ADDR[@]}"; do` loop.
# Currently they are below:
#         if [ -f "$script_file" ]; then
#             echo "============================================================"
#             echo "⚙️ SETUP PROJECT: $type_clean"
#             echo "============================================================"
#             bash "$script_file" "$ID" "$REGION" "$APP_NAME" "$type_clean" "$BASE_URL" "$DATABASE" "$APP_PACKAGE_NAME" || { echo "❌ Proses setup $type_clean gagal!"; exit 1; }
#             echo "============================================================"
#         fi
#     done
#
#     if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then
#         bash "${SCRIPT_DIR}/init_appstore.sh" "$ID" || { echo "❌ Proses init appstore gagal!"; exit 1; }
#     fi
# fi
# 
# # STAGE 2: BUILD
# ...
# # STAGE 3: UPLOAD
# ...
# done (end of TARGET_ID loop)

# Let's extract the STAGE 2 and STAGE 3 block.
stage2_start = content.find("# STAGE 2: BUILD")
stage3_end = content.rfind("done\n") # The last done

if stage2_start != -1 and stage3_end != -1:
    build_and_upload_block = content[stage2_start:stage3_end]
    
    # We need to insert this block BEFORE the `done` of `for type_item in "${ADDR[@]}"; do`.
    # Let's find the `done` of `type_item` loop.
    # It is right before `if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then`
    init_appstore_start = content.find('if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then')
    if init_appstore_start != -1:
        # Find the `done` right before it
        type_loop_done = content.rfind("done", 0, init_appstore_start)
        
        if type_loop_done != -1:
            # We will move the build_and_upload_block to replace the `done` of `type_item` loop,
            # and append `done` at the end of the build_and_upload_block.
            
            # Note: build_app.sh takes "$TARGET_ID" now. We should change it to "$TARGET_ID" "$type_clean".
            # Also, APP_NAME and TYPE variables might be needed in STAGE 3, but upload_to_gdrive takes "$PROJECT" "$APP_NAME".
            # Where is APP_NAME defined? Earlier in release.sh, it is jq parsed. But wait, in the loop, we need the TYPE SPECIFIC APP NAME!
            # It's better to let build_app.sh handle it, or we just pass type_clean.
            
            build_and_upload_block = build_and_upload_block.replace(
                'SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID"',
                'SKIP_UPLOAD=true bash "${SCRIPT_DIR}/build_app.sh" "$TARGET_ID" "$type_clean"'
            )
            
            # In STAGE 3, find APK:
            # TARGET_DIR="${SCRIPT_DIR}/build_result/${PROJECT}"
            # LATEST_APK=$(find "$TARGET_DIR" -name "*.apk" -type f -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
            # This is fine. But wait, there are multiple APKs for multiple types!
            # The APK name contains APP_NAME. We should find the APK that contains the specific APP_NAME!
            # Since APP_NAME can be complex, let's just find the newest APK because build_app.sh was just executed.
            # Yes, `ls -t | head -n 1` gets the NEWEST apk/aab, which is exactly the one just built in this loop iteration!
            
            # Construct the new content
            new_content = content[:type_loop_done] + "\n" + build_and_upload_block + "\n    done\n" + content[type_loop_done+4:stage2_start] + "\ndone\n"
            
            with open("release.sh", "w") as f:
                f.write(new_content)
            
            print("Successfully refactored build and upload loops.")
        else:
            print("Could not find type loop done.")
    else:
        print("Could not find init_appstore.sh.")
else:
    print("Could not find STAGE 2 or STAGE 3.")
