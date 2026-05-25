const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

(async () => {
  const credentialsDir = path.join(__dirname, '../credentials');
  const profileDir = path.join(credentialsDir, '.chrome_profile');

  // Cek apakah folder profil Chrome sudah ada
  if (!fs.existsSync(profileDir)) {
    console.log("⚠️ Sesi profil Chrome tidak ditemukan.");
    console.log("Memulai proses login otomatis (auth.js)...");
    try {
      execSync('npm run auth', { stdio: 'inherit' });
    } catch (e) {
      console.error("❌ Gagal menjalankan proses autentikasi.");
      process.exit(1);
    }
  }

  console.log("============================================================");
  console.log("🎥 MEMULAI PLAYWRIGHT INSPECTOR (RECORD UI)");
  console.log("============================================================");
  console.log("Browser akan terbuka dengan sesi login Anda sebelumnya.");
  console.log("Jendela 'Playwright Inspector' akan muncul.");
  console.log("👉 KLIK TOMBOL 'RECORD' di jendela Inspector, lalu mulailah berinteraksi di browser!");
  console.log("Playwright akan men-generate skrip automation-nya.");
  console.log("Tutup jendela browser jika sudah selesai.");

  try {
    const context = await chromium.launchPersistentContext(profileDir, {
      headless: false,
      channel: 'chrome',
      args: ['--disable-blink-features=AutomationControlled'],
      ignoreDefaultArgs: ['--enable-automation']
    });

    await context.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    });

    const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();
    
    await page.goto('https://play.google.com/console');
    
    // Jeda script dan buka Playwright Inspector
    await page.pause();

    await context.close();
    console.log("✅ Proses perekaman selesai.");
  } catch (error) {
    console.error("❌ Terjadi kesalahan saat membuka perekam:", error.message);
  }
})();
