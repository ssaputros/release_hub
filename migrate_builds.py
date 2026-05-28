import json
import os
import shutil

# Load projects.json
with open('projects.json', 'r') as f:
    projects_data = json.load(f)

# Create a mapping from Project Name to its App Types and App Names
project_map = {}
for pid, pdata in projects_data.items():
    proj_name = pdata.get('Project', {}).get('Project Name')
    app_names = pdata.get('Project', {}).get('App Name')
    
    if proj_name not in project_map:
        project_map[proj_name] = {}
        
    if isinstance(app_names, dict):
        for app_type, app_name in app_names.items():
            project_map[proj_name][app_name] = app_type
    else:
        # If it's a string, we need to know the type
        app_type = pdata.get('Project', {}).get('Type')
        if app_type:
            # Type might be a comma-separated string, but if app_name is string, usually it's single type or we just use the first type
            primary_type = [t.strip() for t in app_type.split(',')][0]
            project_map[proj_name][app_names] = primary_type

build_dir = 'build_result'

for root, dirs, files in os.walk(build_dir):
    for file in files:
        if file.endswith('.aab') or file.endswith('.apk') or file.endswith('.ipa'):
            # root is like 'build_result/Mitra Swalayan'
            # file is like '28-05-2026 01.20 Mitra Swalayan - HRIS 1.12.1+5.aab'
            
            # Extract project name from the path
            rel_path = os.path.relpath(root, build_dir)
            if rel_path == '.': continue
            
            project_name = rel_path.split('/')[0]
            
            if project_name in project_map:
                # Try to find which app_name matches the file name
                matched_type = None
                for app_name, app_type in project_map[project_name].items():
                    if app_name and app_name.lower() in file.lower():
                        matched_type = app_type
                        break
                        
                # If we couldn't match exactly by app_name, use heuristic
                if not matched_type:
                    if 'approval' in file.lower():
                        matched_type = 'Approval Apps'
                    elif 'hris' in file.lower() or 'hrm' in file.lower():
                        matched_type = 'HRM Apps'
                    elif len(project_map[project_name]) == 1:
                        # Only one type registered
                        matched_type = list(project_map[project_name].values())[0]
                        
                if matched_type:
                    src_file = os.path.join(root, file)
                    dest_dir = os.path.join(build_dir, project_name, matched_type)
                    os.makedirs(dest_dir, exist_ok=True)
                    dest_file = os.path.join(dest_dir, file)
                    
                    if src_file != dest_file:
                        print(f"Memindahkan: {file}")
                        print(f"  -> {project_name}/{matched_type}/")
                        shutil.move(src_file, dest_file)
                else:
                    print(f"⚠️ Tidak dapat menentukan tipe untuk file: {file}")

print("Migrasi selesai!")
