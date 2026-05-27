import csv
import json
import re

def generate_id(name):
    if not name:
        return ""
    s = name.lower()
    s = re.sub(r'[^a-z0-9 ]', '', s)
    s = re.sub(r'\s+', '-', s.strip())
    return s

projects = {}

with open('Form Request Apps - Form Responses 1.csv', mode='r', encoding='utf-8') as f:
    reader = csv.reader(f)
    headers = next(reader)
    for row in reader:
        if len(row) < 19:
            continue
            
        app_types_raw = row[3]
        if "HRM Apps" not in app_types_raw and "Approval Apps" not in app_types_raw:
            continue
            
        # Parse app types
        types_list = [t.strip() for t in app_types_raw.split(',') if "HRM Apps" in t or "Approval Apps" in t]
        if not types_list:
            continue
            
        project_name = row[2]
        slug = generate_id(project_name)
        if not slug:
            continue
            
        base_url = row[5].strip()
        if base_url and not base_url.startswith('http'):
            base_url = 'https://' + base_url
            
        database = row[6].strip()
        icon = row[11].strip()
        region = row[13].strip()
        app_name_raw = row[14].strip()
        notes = row[18].strip()
        
        # Bersihkan slug untuk package id (tanpa strip)
        clean_package_slug = slug.replace('-', '')
        package_id = f"com.hashmicro.eva.{clean_package_slug}"
        
        branch_obj = {}
        package_id_obj = {}
        bundle_id_obj = {}
        app_name_obj = {}
        
        for t in types_list:
            branch_obj[t] = slug
            # Default fallback package ID. User can edit later in payload-editor
            package_id_obj[t] = package_id
            bundle_id_obj[t] = package_id
            app_name_obj[t] = app_name_raw if app_name_raw else project_name
            
        projects[slug] = {
            "Branch": branch_obj,
            "Play Console Dashboard": { t: "" for t in types_list },
            "Firebase Project": "",
            "Project": {
                "Project Name": project_name,
                "Region": region,
                "App Name": app_name_obj,
                "Type": ", ".join(types_list),
                "Base URL": base_url,
                "Database": database,
                "Icon": icon,
                "Notes": notes
            },
            "Package ID": package_id_obj,
            "Bundle ID": bundle_id_obj
        }

with open('payload-editor.txt', 'w', encoding='utf-8') as f:
    # Hapus array tanda kurung kurawal terluar, tampilkan bagian dalamnya saja
    # agar user mudah memindahkannya ke projects.json
    json.dump(projects, f, indent=2)

print(f"Extracted {len(projects)} projects.")
