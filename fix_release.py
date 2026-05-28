import sys

with open("release.sh", "r") as f:
    lines = f.readlines()

new_lines = []
in_old_for = False
old_for_content = []
old_else_content = []
state = 0 # 0: normal, 1: reading for loop (TARGET_ID), 2: reading else (new project)

for i, line in enumerate(lines):
    if line.startswith('for TARGET_ID in "${SELECTED_TARGETS[@]}"; do') and state == 0:
        state = 1
        continue
        
    if state == 1:
        if line.strip() == "else":
            state = 2
        else:
            old_for_content.append(line)
        continue
        
    if state == 2:
        if line.strip() == "fi" and "TARGET_ID=\"$ID\"" in lines[i-1]:
            # This is the end of the new project block
            state = 0
        else:
            old_else_content.append(line)
        continue
        
    if state == 0:
        new_lines.append(line)

# Now we rebuild the structure correctly
fixed_logic = []
fixed_logic.append('if [ -n "$PROJECT" ] && [ ${#SELECTED_TARGETS[@]} -eq 0 ]; then\n')
for line in old_else_content:
    if 'TARGET_ID="$ID"' not in line:
        fixed_logic.append(line)
fixed_logic.append('    SELECTED_TARGETS=("$ID")\n')
fixed_logic.append('fi\n\n')

fixed_logic.append('for TARGET_ID in "${SELECTED_TARGETS[@]}"; do\n')
for line in old_for_content:
    fixed_logic.append(line)

# Insert the fixed logic exactly where the old loop started
insertion_point = 0
for i, line in enumerate(new_lines):
    if line.strip() == "fi" and "if [ \"$OPT_SETUP\" = false ] && [ \"$OPT_BUILD\" = false ]" in "".join(new_lines[i-10:i]):
        insertion_point = i + 1
        break

final_lines = new_lines[:insertion_point] + fixed_logic + new_lines[insertion_point:]

with open("release.sh", "w") as f:
    f.writelines(final_lines)

print("Berhasil merapikan struktur script release.sh!")
