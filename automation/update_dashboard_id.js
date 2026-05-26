const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// 1. Ambil Argumen ID Project dari Command Line
const runId = process.argv[2];
if (!runId) {
  console.error("Usage: node update_dashboard_id.js <project_id>");
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
  const credentialsDir = path.join(__dirname, '../credentials');
  const profileDir = path.join(credentialsDir, '.chrome_profile');

  if (!fs.existsSync(profileDir)) {
    console.error("❌ Profil Chrome tidak ditemukan. Jalankan 'npm run auth' dulu.");
    process.exit(1);
  }

  console.log("============================================================");
  console.log(`🔗 UPDATE PLAY CONSOLE DASHBOARD ID UNTUK: ${appData.Project['App Name']}`);
  console.log("============================================================");

  try {
    const context = await chromium.launchPersistentContext(profileDir, {
      headless: false,
      channel: 'chrome',
      viewport: { width: 1280, height: 720 },
      args: ['--disable-blink-features=AutomationControlled'],
      ignoreDefaultArgs: ['--enable-automation']
    });

    await context.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    });

    const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();
    
    // Coba dapatkan Developer ID terlebih dahulu untuk navigasi awal
    const devIdFile = path.join(credentialsDir, 'playstore_dev_id.txt');
    let startUrl = 'https://play.google.com/console';
    
    if (fs.existsSync(devIdFile)) {
        let devId = fs.readFileSync(devIdFile, 'utf8').trim();
        if (/^\d+$/.test(devId)) {
            devId = `developers/${devId}`;
        }
        startUrl = `https://play.google.com/console/${devId}/app-list`;
    }

    console.log("🌐 Membuka Google Play Console...");
    await page.goto(startUrl);

    console.log("👉 Silakan klik/buka aplikasi target Anda secara manual di browser.");
    console.log("⏳ Skrip sedang mendengarkan URL... Begitu masuk halaman Dashboard, browser akan otomatis tertutup.");
    
    // Tunggu hingga user masuk ke halaman yang URL-nya memiliki format dashboard aplikasi
    let appId = null;
    while (true) {
        const currentUrl = page.url();
        const match = currentUrl.match(/\/app\/(\d+)/);
        if (match && match[1]) {
            appId = match[1];
            break;
        }
        await page.waitForTimeout(500);
    }
    
    if (appId) {
        console.log(`\n✅ Halaman terdeteksi!`);
        console.log(`✅ Mengekstrak Play Console Dashboard (App ID): ${appId}`);
        
        // Simpan ke projects.json
        const activeType = (process.env.FILTERED_TYPE || appData.Project['Type']).split(',')[0].trim();
        
        if (typeof projects[runId]['Play Console Dashboard'] !== 'object' || projects[runId]['Play Console Dashboard'] === null) {
            projects[runId]['Play Console Dashboard'] = {};
        }
        projects[runId]['Play Console Dashboard'][activeType] = appId;
        fs.writeFileSync(projectsPath, JSON.stringify(projects, null, 2));
        console.log(`✅ Berhasil menyimpan ID ke projects.json untuk project ${runId}!`);
    } else {
        console.log("⚠️ Gagal mengekstrak App ID dari URL:", finalUrl);
    }
    
    console.log("✅ Proses selesai, menutup browser...");
    await context.close();
  } catch (error) {
    console.error("❌ Terjadi kesalahan:", error.message);
    process.exit(1);
  }
})();
