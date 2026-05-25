const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// 1. Ambil Argumen ID Project dari Command Line
const runId = process.argv[2];
if (!runId) {
  console.error("Usage: node create_app.js <project_id>");
  process.exit(1);
}

// 2. Baca Data dari projects.json dan config.json
const projectsPath = path.join(__dirname, '../projects.json');
const configPath = path.join(__dirname, '../config.json');

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

const appName = appData.Project['App Name'];
const appType = appData.Project['Type'];

// Menghitung Package Name (Prefix + ID)
let prefix = "com.example";
if (fs.existsSync(configPath)) {
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  if (config.types && config.types[appType] && config.types[appType].prefix) {
    prefix = config.types[appType].prefix;
  }
}
const packageName = `${prefix}.${runId}`;

(async () => {
  const credentialsDir = path.join(__dirname, '../credentials');
  const profileDir = path.join(credentialsDir, '.chrome_profile');

  if (!fs.existsSync(profileDir)) {
    console.error("❌ Profil Chrome tidak ditemukan. Harap login terlebih dahulu.");
    process.exit(1);
  }

  console.log("============================================================");
  console.log(`🚀 MEMBUAT APLIKASI: ${appName}`);
  console.log(`📦 Package Name: ${packageName}`);
  console.log("============================================================");

  try {
    const context = await chromium.launchPersistentContext(profileDir, {
      headless: false, // Tetap false agar Anda bisa memantau prosesnya
      channel: 'chrome',
      args: ['--disable-blink-features=AutomationControlled'],
      ignoreDefaultArgs: ['--enable-automation']
    });

    await context.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    });

    const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();
    
    const devIdFile = path.join(credentialsDir, 'playstore_dev_id.txt');
    let devId = "";

    if (fs.existsSync(devIdFile)) {
        devId = fs.readFileSync(devIdFile, 'utf8').trim();
    } else {
        await page.goto('https://play.google.com/console');
        await page.waitForURL('**/developers/**');
        const url = page.url();
        const match = url.match(/(?:u\/\d+\/)?developers\/\d+/);
        if (match) {
            devId = match[0];
            fs.writeFileSync(devIdFile, devId);
        }
    }

    if (devId) {
        console.log(`🔗 Navigasi langsung ke Dashboard Aplikasi...`);
        await page.goto(`https://play.google.com/console/${devId}/app-list`);
    } else {
        await page.goto('https://play.google.com/console');
    }
    await page.waitForLoadState('domcontentloaded');

    // ==========================================
    // KODE HASIL REKAMAN (SUDAH DINAMIS)
    // ==========================================
    console.log("Mengklik 'Create app'...");
    await page.getByRole('link', { name: 'Create app' }).click();
    
    console.log("Mengisi nama aplikasi...");
    await page.getByRole('textbox', { name: 'App name' }).click();
    await page.getByRole('textbox', { name: 'App name' }).fill(appName);
    
    // (Opsional) Mengisi package name jika diminta oleh form
    try {
      await page.getByRole('textbox', { name: 'App package name' }).click({ timeout: 2000 });
      await page.getByRole('textbox', { name: 'App package name' }).fill(packageName);
    } catch (e) {
      // Abaikan jika tidak ada input package name
    }

    console.log("Memilih opsi App & Free...");
    await page.getByRole('radio', { name: 'App' }).check();
    await page.getByRole('radio', { name: 'Free' }).check();
    
    console.log("Menyetujui persyaratan hukum...");
    await page.getByRole('checkbox', { name: 'Confirm app meets the' }).check();
    await page.getByRole('checkbox', { name: 'Accept US export laws I' }).check();
    
    console.log("Klik tombol pembuatan aplikasi...");
    await page.getByRole('button', { name: 'Create app' }).click();
    // ==========================================
    
    // Tunggu sistem Google Play memproses pembuatan aplikasi
    console.log("⏳ Menunggu respons dari Google...");
    await page.waitForTimeout(7000);
    
    console.log("✅ Pembuatan aplikasi selesai!");
    await context.close();
  } catch (error) {
    console.error("❌ Terjadi kesalahan saat membuat aplikasi:", error.message);
    process.exit(1);
  }
})();