const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const readline = require('readline');

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

// Gampang mengubah urutan step cukup dengan menggeser baris nama file di bawah ini:
const stepNames = [
    'privacy_policy.js',
    'app_access.js',
    'ads.js',
    'content_rating.js',
    'target_audience.js',
    'data_safety.js',
    'government_apps.js',
    'financial_features.js',
    'health.js',
    'app_category_contact.js',
];

const steps = stepNames.map(name => ({
    name: name,
    path: path.join(__dirname, `steps/${name}`)
}));

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
      viewport: { width: 1280, height: 720 },
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

    const activeType = (process.env.FILTERED_TYPE || appData.Project['Type']).split(',')[0].trim();
    let dashboardId = "";
    if (appData['Play Console Dashboard'] && typeof appData['Play Console Dashboard'] === 'object') {
        dashboardId = appData['Play Console Dashboard'][activeType] || "";
    }
    
    if (!dashboardId) {
        console.log("\n⚠️ 'Play Console Dashboard' ID masih kosong di projects.json!");
        console.log("👉 Silakan BUKA APLIKASI target Anda secara manual di browser Playwright yang sedang terbuka.");
        console.log("⏳ Skrip sedang menunggu Anda masuk ke halaman Dashboard aplikasi...");
        
        // Buka halaman utama konsol sebagai titik awal jika belum berada di dalam app
        let startUrl = 'https://play.google.com/console';
        if (devId) {
            startUrl = `https://play.google.com/console/${/^\d+$/.test(devId) ? `developers/${devId}` : devId}/app-list`;
        }
        if (!page.url().includes('/app-list') && !page.url().includes('/app/')) {
            await page.goto(startUrl);
        }

        await page.waitForURL(/\/app\/(\d+)/, { timeout: 0 });
        const finalUrl = page.url();
        const match = finalUrl.match(/\/app\/(\d+)/);
        
        if (match && match[1]) {
            dashboardId = match[1];
            console.log(`✅ Halaman terdeteksi! Mengekstrak App ID: ${dashboardId}`);
            
            // Simpan ke projects.json (always as nested object)
            if (typeof projects[runId]['Play Console Dashboard'] !== 'object' || projects[runId]['Play Console Dashboard'] === null) {
                projects[runId]['Play Console Dashboard'] = {};
            }
            projects[runId]['Play Console Dashboard'][activeType] = dashboardId;
            fs.writeFileSync(projectsPath, JSON.stringify(projects, null, 2));
            console.log("✅ Berhasil menyimpan ID ke projects.json! Melanjutkan eksekusi...");
        } else {
            console.error("❌ Gagal mengekstrak App ID dari URL. Berhenti.");
            process.exit(1);
        }
    }

    // Pastikan devIdPath mengandung segment 'developers/'
    let devIdPath = devId;
    if (/^\d+$/.test(devId)) {
        devIdPath = `developers/${devId}`;
    }

    // Navigasi langsung ke halaman App Dashboard (jika belum berada di sana)
    const appContentUrl = `https://play.google.com/console/${devIdPath}/app/${dashboardId}/app-dashboard`;
    if (!page.url().includes(appContentUrl)) {
        console.log(`🔗 Membuka halaman Dashboard: ${appContentUrl}`);
        await page.goto(appContentUrl);
    }
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(3000); // Tunggu rendering awal

    // Scroll sedikit ke bawah untuk memicu lazy-loading jika ada
    await page.evaluate(() => window.scrollBy(0, 500)).catch(() => {});
    await page.waitForTimeout(1000);

    // Buka daftar tugas jika tombol 'View tasks' tersedia di dashboard
    const expandTasksBtn = page.getByRole('button', { name: 'View tasks for Provide', exact: false });
    if (await expandTasksBtn.count() > 0) {
        // Pastikan elemen discroll ke dalam layar sebelum dicek visibilitasnya
        await expandTasksBtn.first().scrollIntoViewIfNeeded().catch(() => {});
        if (await expandTasksBtn.first().isVisible().catch(() => false)) {
            console.log("📂 Membuka daftar tugas (View tasks for Provide)...");
            await expandTasksBtn.first().click({ force: true }).catch(e => console.log("⚠️ Gagal klik tombol tasks:", e.message));
            await page.waitForTimeout(1000);
        }
    }

    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
    const askQuestion = (query) => new Promise(resolve => rl.question(query, resolve));

    const executeStep = async (i) => {
        console.log(`\n⏳ Mengeksekusi Langkah ${i + 1}/${steps.length} (${steps[i].name})...`);
        
        if (!fs.existsSync(steps[i].path)) {
            throw new Error(`File skrip [${steps[i].name}] tidak ditemukan! Anda harus membuat file ini atau melakukan setup/Record UI terlebih dahulu.`);
        }
        const fileContent = fs.readFileSync(steps[i].path, 'utf8');
        if (!fileContent.includes('await page.')) {
            throw new Error(`Skrip [${steps[i].name}] masih kosong! Anda harus melakukan Record UI untuk langkah ini terlebih dahulu.`);
        }
        
        const stepFunc = require(steps[i].path);
        await stepFunc(page, appData);
        await page.waitForTimeout(2000);
        console.log(`✅ Langkah ${steps[i].name} selesai!`);
    };

    console.log("\n============================================================");
    console.log("🚀 MENGEKSEKUSI SEMUA LANGKAH SECARA OTOMATIS");
    console.log("============================================================");
    for (let i = 0; i < steps.length; i++) {
        await executeStep(i);
    }

    rl.close();
    console.log("\n✅ Selesai mengeksekusi App Information!");
  } catch (error) {
    console.error("❌ Terjadi kesalahan saat eksekusi:", error.message);
    process.exit(1);
  } finally {
    if (browser) await browser.close();
  }
})();
