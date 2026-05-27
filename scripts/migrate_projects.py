import json
import re
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
PROJECTS_JSON_PATH = os.path.join(PROJECT_ROOT, "projects.json")
CONFIG_JSON_PATH = os.path.join(PROJECT_ROOT, "config.json")

def migrate():
    with open(PROJECTS_JSON_PATH, 'r') as f:
        projects = json.load(f)
    with open(CONFIG_JSON_PATH, 'r') as f:
        config = json.load(f)

    for pid, pdata in projects.items():
        project_details = pdata.get("Project", {})
        types_str = project_details.get("Type", "")
        types = [t.strip() for t in types_str.split(",") if t.strip()]
        
        if not types:
            continue
        
        # Determine the base app name, handling cases where it might already be a dict
        app_name_val = project_details.get("App Name")
        if isinstance(app_name_val, dict):
            # Already migrated or partially migrated
            continue
        elif not isinstance(app_name_val, str):
            old_app_name = "My App"
        else:
            old_app_name = app_name_val
        
        package_ids = {}
        bundle_ids = {}
        app_names = {}
        
        for t in types:
            # Resolve prefix
            prefix = "com.example"
            if "types" in config and t in config["types"] and "prefix" in config["types"][t]:
                prefix = config["types"][t]["prefix"]
            
            # Package & Bundle IDs
            package_ids[t] = f"{prefix}.{pid}"
            bundle_ids[t] = f"{prefix}.{pid}"
            
            # Resolve App Name using the logic from scripts
            final_app_name = old_app_name
            if t == "Approval Apps":
                final_app_name = re.sub(r'\b(hris|hr|hrm)\b', '', final_app_name, flags=re.IGNORECASE).strip()
                final_app_name = re.sub(r'\s+', ' ', final_app_name)
                if 'approval' not in final_app_name.lower():
                    final_app_name = f"{final_app_name} Approval".strip()
            
            app_names[t] = final_app_name

        pdata["Package ID"] = package_ids
        pdata["Bundle ID"] = bundle_ids
        pdata["Project"]["App Name"] = app_names

    with open(PROJECTS_JSON_PATH, 'w') as f:
        json.dump(projects, f, indent=2)
        
    print("Migration successful! projects.json updated.")

if __name__ == "__main__":
    migrate()
