const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const readline = require('readline');

// 1. Ambil Argumen ID Project dari Command Line
const runId = process.argv[2];
if (!runId) {
  console.error("Usage: node submit_playstore.js <project_id>");
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

(async () => {
  const profileDir = path.join(__dirname, '../credentials/.chrome_profile');

  if (!fs.existsSync(profileDir)) {
    console.error("❌ Profil Chrome tidak ditemukan. Harap login terlebih dahulu (npm run auth).");
    process.exit(1);
  }

  console.log("============================================================");
  console.log(`🚀 MEMBUKA DASHBOARD PLAY STORE: ${appData.Project['App Name']}`);
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

    let devIdPath = devId;
    if (/^\d+$/.test(devId)) {
        devIdPath = `developers/${devId}`;
    }

    // Navigasi langsung ke halaman Production Track
    const targetUrl = `https://play.google.com/console/${devIdPath}/app/${dashboardId}/tracks/production`;
    console.log(`🔗 Membuka halaman Play Store Production Track: ${targetUrl}`);
    await page.goto(targetUrl);
    
    console.log("\n============================================================");
    console.log("✅ Halaman berhasil dibuka!");
    console.log("Silakan lanjutkan proses Submit Play Store secara manual di browser.");
    console.log("Tutup jendela browser ini atau tekan CTRL+C pada terminal jika sudah selesai.");
    console.log("============================================================\n");
    
    // Tunggu sampai jendela browser (atau tab) ditutup secara manual oleh user
    await page.waitForEvent('close', { timeout: 0 });
  } catch (error) {
    console.error("❌ Terjadi kesalahan saat eksekusi:", error.message);
    process.exit(1);
  } finally {
    if (browser) await browser.close();
  }
})();
