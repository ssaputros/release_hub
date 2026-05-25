const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {
  const credentialsDir = path.join(__dirname, '../credentials');
  const profileDir = path.join(credentialsDir, '.chrome_profile');

  if (!fs.existsSync(credentialsDir)) {
    fs.mkdirSync(credentialsDir, { recursive: true });
  }

  console.log("============================================================");
  console.log("🔓 MEMULAI PROSES AUTENTIKASI GOOGLE PLAY CONSOLE");
  console.log("============================================================");
  console.log("Membuka browser Chrome (Anti-Detection)...");
  console.log("Silakan login dengan akun Google Anda.");

  try {
    const context = await chromium.launchPersistentContext(profileDir, {
      headless: false,
      channel: 'chrome',
      args: ['--disable-blink-features=AutomationControlled'],
      ignoreDefaultArgs: ['--enable-automation']
    });

    // Skrip injeksi untuk memanipulasi deteksi bot Google
    await context.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    });

    const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();

    await page.goto('https://play.google.com/console');

    console.log("⏳ Menunggu deteksi login sukses...");
    
    // Tunggu hingga masuk ke dashboard developers
    await page.waitForURL('**/developers/**', { timeout: 0 });
    
    console.log("✅ Login berhasil dideteksi!");
    
    // Simpan Developer ID (termasuk session /u/x/ jika ada) untuk mempercepat navigasi skrip lain
    const url = page.url();
    const match = url.match(/(?:u\/\d+\/)?developers\/\d+/);
    if (match) {
        fs.writeFileSync(path.join(credentialsDir, 'playstore_dev_id.txt'), match[0]);
        console.log(`✅ Developer ID disimpan: ${match[0]}`);
    }

    await page.waitForTimeout(3000);
    
    console.log(`💾 Profil Chrome berhasil disimpan secara permanen di: credentials/.chrome_profile`);
    console.log("Sesi ini akan otomatis digunakan ulang oleh fitur perekam UI.");
    
    await context.close();
  } catch (error) {
    console.error("❌ Terjadi kesalahan saat proses login:", error);
    process.exit(1);
  }
})();
