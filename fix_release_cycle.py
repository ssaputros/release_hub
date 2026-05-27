import re

with open("release.sh", "r") as f:
    lines = f.readlines()

# Goal: Move STAGE 2 (BUILD) and STAGE 3 (UPLOAD) into the `current_type` loop.
# Currently they are right after the type loop finishes.
# Let's find where the type loop ends.

type_loop_start = -1
type_loop_end = -1

for i, line in enumerate(lines):
    if "for type_item in \"${ADDR[@]}\"; do" in line:
        type_loop_start = i
        
    if type_loop_start != -1 and i > type_loop_start and line.strip() == "done":
        # Check if this is the end of the type_item loop
        if "type_clean=" in "".join(lines[type_loop_start:i]):
            type_loop_end = i
            break

# Now find the end of the STAGE 3 (UPLOAD) block.
# STAGE 3 block ends before the `done` of `for TARGET_ID in "${SELECTED_TARGETS[@]}"; do` loop.
# Or before `exit 0`.
# Let's find the closing `done` of `SELECTED_TARGETS` loop.
selected_targets_done = -1
for i in range(len(lines)-1, -1, -1):
    if line.strip() == "done":
        if "done" in lines[i]:
             pass
    if lines[i].startswith("done"):
        selected_targets_done = i
        break

# The block to move is from `type_loop_end + 1` to `selected_targets_done - 1`.
# But wait, there is `if [ -f "${SCRIPT_DIR}/init_appstore.sh" ]; then ... fi` right after `done` of the type loop!
# Wait, let's look at the exact contents of lines around type_loop_end.
type_loop_end_idx = type_loop_end

# Instead of moving everything manually in python, it's safer to use a regex or string replacement.
with open("release.sh", "r") as f:
    content = f.read()

# I want to take:
# if [ "$OPT_BUILD" = true ]; then ...
# STAGE 3: UPLOAD ...
# and put them INSIDE the loop.

# Wait, `release.sh` has:
#         script_file="${SCRIPT_DIR}/scripts/project_types/setup_${type_slug}.sh"
#         
#         if [ -f "$script_file" ]; then
#             ...
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
# done

# We should move everything from # STAGE 2: BUILD down to just before the last `done` INTO the `type_item` loop.
# Since `build_app.sh` now requires `type_clean` as an argument, we need to pass `"$type_clean"` to it.
# AND we need to pass `"$type_clean"` to `upload_to_gdrive.py` maybe? Wait, `upload_to_gdrive` does not need `type_clean`, it just uploads the APK. But `APP_NAME` is type-specific!
