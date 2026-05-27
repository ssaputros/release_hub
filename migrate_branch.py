import json

with open("projects.json", "r") as f:
    projects = json.load(f)

for project_id, data in projects.items():
    if "Branch" in data and isinstance(data["Branch"], str):
        branch_str = data["Branch"]
        
        # Determine the app types
        types_str = data.get("Project", {}).get("Type", "")
        if types_str:
            types = [t.strip() for t in types_str.split(",")]
        else:
            # If no type is defined, fallback to HRM Apps or just what we have
            types = ["HRM Apps"]
            
        new_branch = {}
        for t in types:
            new_branch[t] = branch_str
            
        data["Branch"] = new_branch

with open("projects.json", "w") as f:
    json.dump(projects, f, indent=2)

print("Migration completed successfully.")
