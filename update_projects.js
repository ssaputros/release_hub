const fs = require('fs');

let projects = JSON.parse(fs.readFileSync('projects.json', 'utf8'));

projects['hmx-master-demo'] = {
  "Branch": {
    "HMX App": "Master-Demo"
  },
  "Play Console Dashboard": {
    "HMX App": ""
  },
  "Firebase Project": "",
  "Project": {
    "Project Name": "HMX Master Demo",
    "Region": "Indonesia",
    "App Name": {
      "HMX App": "HMX Master Demo"
    },
    "Type": "HMX App",
    "Base URL": "https://masterdemo.hashmicro.com",
    "Database": "",
    "Icon": ""
  },
  "Package ID": {
    "HMX App": "com.hashmicro.hmx.masterdemo"
  },
  "Bundle ID": {
    "HMX App": "com.hashmicro.hmx.masterdemo"
  }
};

fs.writeFileSync('projects.json', JSON.stringify(projects, null, 2));
