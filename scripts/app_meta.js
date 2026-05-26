const fs = require('fs');
const path = require('path');

function getAppMeta(projectId, appName, appType, configPath) {
    let primaryType = appType;
    if (appType && appType.includes(',')) {
        primaryType = appType.split(',')[0].trim();
    }
    
    let prefix = "com.example";
    if (fs.existsSync(configPath)) {
        const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        if (config.types && config.types[primaryType] && config.types[primaryType].prefix) {
            prefix = config.types[primaryType].prefix;
        }
    }
    
    let finalPackageName = `${prefix}.${projectId}`;
    let finalAppName = appName || "";
    
    if (primaryType === "Approval Apps") {
        // Hapus HR, HRIS, HRM (case insensitive)
        finalAppName = finalAppName.replace(/\b(hris|hr|hrm)\b/ig, '').trim();
        // Bersihkan spasi berlebih
        finalAppName = finalAppName.replace(/\s+/g, ' ');
        
        // Tambahkan imbuhan Approval jika belum ada
        if (!finalAppName.toLowerCase().includes('approval')) {
            finalAppName = `${finalAppName} Approval`.trim();
        }
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
