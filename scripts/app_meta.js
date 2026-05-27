const fs = require('fs');
const path = require('path');

function getAppMeta(projectId, appName, appType, configPath) {
    let primaryType = appType;
    if (appType && appType.includes(',')) {
        primaryType = appType.split(',')[0].trim();
    }
    
    let finalPackageName = "";
    let finalAppName = appName || "";
    
    const projectsPath = path.join(__dirname, '../projects.json');
    if (fs.existsSync(projectsPath)) {
        const projects = JSON.parse(fs.readFileSync(projectsPath, 'utf8'));
        if (projects[projectId]) {
            const pData = projects[projectId];
            if (pData['Package ID'] && pData['Package ID'][primaryType]) {
                finalPackageName = pData['Package ID'][primaryType];
            }
            if (pData['Project'] && pData['Project']['App Name'] && pData['Project']['App Name'][primaryType]) {
                finalAppName = pData['Project']['App Name'][primaryType];
            }
        }
    }
    
    if (!finalPackageName) {
        let prefix = "com.example";
        if (fs.existsSync(configPath)) {
            const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
            if (config.types && config.types[primaryType] && config.types[primaryType].prefix) {
                prefix = config.types[primaryType].prefix;
            }
        }
        finalPackageName = `${prefix}.${projectId}`;
    }
    
    return {
        packageName: finalPackageName,
        appName: finalAppName,
        primaryType: primaryType
    };
}

// Jika dipanggil langsung dari terminal (oleh Bash script)
if (require.main === module) {
    const args = process.argv.slice(2);
    if (args.length < 3) {
        console.error("Usage: node app_meta.js <projectId> <appName> <appType> [configPath]");
        process.exit(1);
    }
    
    const projectId = args[0];
    const appName = args[1];
    const appType = args[2];
    const configPath = args[3] || path.join(__dirname, '../config.json');
    
    const meta = getAppMeta(projectId, appName, appType, configPath);
    console.log(JSON.stringify(meta));
}

module.exports = { getAppMeta };
