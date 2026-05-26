const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// 1. Ambil Argumen ID Project dari Command Line
const runId = process.argv[2];
if (!runId) {
  console.error("Usage: node runner_app_info.js <project_id>");
  process.exit(1);
}

// 2. Baca Data dari projects.json
const projectsPath = path.join(__dirname, '../projects.json');
if (!fs.existsSync(projectsPath)) {
  console.error("❌ Error: projects.json tidak ditemukan.");
  process.exit(1);
}
const projects = JSON.parse(fs.readFileSync(projectsPath, 'utf8'));
const appData = projects[runId];

if (!appData) {
  console.error(`❌ Error: Project dengan ID '${runId}' tidak ditemukan di projects.json.`);
  process.exit(1);
}

const rawAppName = appData.Project['App Name'];
const rawAppType = process.env.FILTERED_TYPE || appData.Project['Type'];
const configPath = path.join(__dirname, '../config.json');

const { getAppMeta } = require('../scripts/app_meta.js');
const meta = getAppMeta(runId, rawAppName, rawAppType, configPath);
const packageName = meta.packageName;

const steps = [
    { name: 'privacy_policy.js', path: path.join(__dirname, 'steps/privacy_policy.js') },
    { name: 'app_access.js', path: path.join(__dirname, 'steps/app_access.js') },
    { name: 'ads.js', path: path.join(__dirname, 'steps/ads.js') },
    { name: 'content_rating.js', path: path.join(__dirname, 'steps/content_rating.js') },
    { name: 'target_audience.js', path: path.join(__dirname, 'steps/target_audience.js') },
    { name: 'data_safety.js', path: path.join(__dirname, 'steps/data_safety.js') },
    { name: 'government_apps.js', path: path.join(__dirname, 'steps/government_apps.js') },
    { name: 'financial_features.js', path: path.join(__dirname, 'steps/financial_features.js') },
    { name: 'health.js', path: path.join(__dirname, 'steps/health.js') }
];

(async () => {
  const profileDir = path.join(__dirname, '../credentials/.chrome_profile');

  if (!fs.existsSync(profileDir)) {
    console.error("❌ Profil Chrome tidak ditemukan. Harap login terlebih dahulu.");
    process.exit(1);
  }

  console.log("============================================================");
  console.log(`🚀 SETUP PLAYSTORE APP INFORMATION: ${appData.Project['App Name']}`);
  console.log("============================================================");

  let browser;
  try {
    browser = await chromium.launchPersistentContext(profileDir, {
      headless: false,
      channel: 'chrome',
      args: ['--disable-blink-features=AutomationControlled'],
      ignoreDefaultArgs: ['--enable-automation']
    });

    await browser.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    });

    const page = browser.pages().length > 0 ? browser.pages()[0] : await browser.newPage();
    
    const credentialsDir = path.join(__dirname, '../credentials');
    const devIdFile = path.join(credentialsDir, 'playstore_dev_id.txt');
    let devId = "";

    if (fs.existsSync(devIdFile)) {
        devId = fs.readFileSync(devIdFile, 'utf8').trim();
    } else {
        await page.goto('https://play.google.com/console');
        await page.waitForURL('**/developers/**');
        const url = page.url();
        const match = url.match(/(?:u\/\d+\/)?developers\/\d+/);
        if (!match) {
            throw new Error("Gagal mendapatkan Developer ID dari URL Dashboard.");
        }
        devId = match[0];
        fs.writeFileSync(devIdFile, devId);
    }

    // Navigasi langsung ke halaman App Content (Setup App Information)
    const appContentUrl = `https://play.google.com/console/${devId}/app/${packageName}/app-content`;
    console.log(`🔗 Membuka halaman App Content: ${appContentUrl}`);
    await page.goto(appContentUrl);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(3000); // Tunggu rendering awal

    for (let i = 0; i < steps.length; i++) {
        console.log(`\n⏳ Mengeksekusi Langkah ${i + 1}/${steps.length} (${steps[i].name})...`);
        
        // Deteksi apakah file fisik skrip ada
        if (!fs.existsSync(steps[i].path)) {
            throw new Error(`File skrip [${steps[i].name}] tidak ditemukan! Anda harus membuat file ini atau melakukan setup/Record UI terlebih dahulu.`);
        }

        // Deteksi apakah skrip masih kosong (belum di-paste hasil record)
        const fileContent = fs.readFileSync(steps[i].path, 'utf8');
        if (!fileContent.includes('await page.')) {
            throw new Error(`Skrip [${steps[i].name}] masih kosong! Anda harus melakukan Record UI untuk langkah ini terlebih dahulu.`);
        }

        const stepFunc = require(steps[i].path);
        await stepFunc(page, appData);
        // Jeda sebentar antar langkah agar UI Google sempat merender
        await page.waitForTimeout(2000); 
    }

    console.log("\n✅ Semua langkah App Information selesai!");
  } catch (error) {
    console.error("❌ Terjadi kesalahan saat eksekusi:", error.message);
    process.exit(1);
  } finally {
    if (browser) await browser.close();
  }
})();
