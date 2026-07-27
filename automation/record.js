const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const TARGET_ALIASES = {
  'playstore': 'playstore',
  'play-store': 'playstore',
  'google-play': 'playstore',
  'google-play-console': 'playstore',
  'appstore': 'appstore',
  'app-store': 'appstore',
  'appstoreconnect': 'appstore',
  'app-store-connect': 'appstore',
  'asc': 'appstore'
};

const TARGETS = {
  playstore: {
    label: 'Google Play Console',
    url: 'https://play.google.com/console',
    requiresGoogleAuthBootstrap: true
  },
  appstore: {
    label: 'App Store Connect',
    url: 'https://appstoreconnect.apple.com',
    requiresGoogleAuthBootstrap: false
  }
};

function usage() {
  console.log('Usage: node record.js [playstore|appstore]');
  console.log('  playstore : buka Google Play Console');
  console.log('  appstore  : buka App Store Connect');
}

(async () => {
  const rawTarget = (process.argv[2] || 'playstore').toLowerCase();
  const targetKey = TARGET_ALIASES[rawTarget] || rawTarget;
  const target = TARGETS[targetKey];

  if (!target) {
    console.error(`❌ Target record tidak dikenal: ${rawTarget}`);
    usage();
    process.exit(1);
  }

  const credentialsDir = path.join(__dirname, '../credentials');
  const profileDir = path.join(credentialsDir, '.chrome_profile');

  if (!fs.existsSync(credentialsDir)) {
    fs.mkdirSync(credentialsDir, { recursive: true });
  }

  // Play Store masih memakai bootstrap auth.js lama supaya profil Google tersimpan.
  // App Store Connect cukup buka browser profile yang sama dan user bisa login manual jika diminta.
  if (target.requiresGoogleAuthBootstrap && !fs.existsSync(profileDir)) {
    console.log('⚠️ Sesi profil Chrome tidak ditemukan.');
    console.log('Memulai proses login otomatis Play Store (auth.js)...');
    try {
      execSync('npm run auth', { stdio: 'inherit' });
    } catch (e) {
      console.error('❌ Gagal menjalankan proses autentikasi.');
      process.exit(1);
    }
  }

  console.log('============================================================');
  console.log(`🎥 MEMULAI PLAYWRIGHT INSPECTOR - ${target.label}`);
  console.log('============================================================');
  console.log('Browser akan terbuka dengan sesi login Anda sebelumnya.');
  console.log("Jendela 'Playwright Inspector' akan muncul.");
  console.log("👉 Klik tombol 'Record' di jendela Inspector, lalu mulai berinteraksi di browser.");
  console.log('Playwright akan men-generate skrip automation-nya.');
  console.log('Tutup jendela browser jika sudah selesai.');

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

    console.log(`🌐 Membuka ${target.label}: ${target.url}`);
    await page.goto(target.url, { waitUntil: 'domcontentloaded', timeout: 60000 });

    // Jeda script dan buka Playwright Inspector.
    await page.pause();

    await context.close();
    console.log('✅ Proses perekaman selesai.');
  } catch (error) {
    console.error('❌ Terjadi kesalahan saat membuka perekam:', error.message);
    process.exit(1);
  }
})();
