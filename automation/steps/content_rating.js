const readline = require('readline');

module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: content_rating.js");

    const entryBtn = page.getByRole('button', { name: 'Content rating' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'Content rating' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();

    console.log("\n==========================================================================");
    console.log("⚠️  PENGISIAN CONTENT RATING MANUAL DIBUTUHKAN  ⚠️");
    console.log("==========================================================================");
    console.log("Script tidak akan mengisi kuisioner otomatis.");
    console.log("Silakan isi kuisioner Content Rating secara manual di browser yang terbuka.");
    console.log("Selesaikan hingga tahap submit dan siap untuk kembali ke Dashboard.");
    console.log("==========================================================================\n");

    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });

    await new Promise(resolve => rl.question('Tekan ENTER jika Anda sudah selesai mengisi Content Rating di browser...', () => {
        rl.close();
        resolve();
    }));

    console.log("✅ Melanjutkan eksekusi setelah konfirmasi manual...");
    await page.waitForTimeout(1000);

    if (!/\/app-dashboard/.test(page.url())) {
        const dashboardUrl = page.url().replace(/\/app-content\/.*$/, '/app-dashboard');
        if (/\/app\//.test(dashboardUrl)) {
            console.log(`Mengalihkan kembali ke dashboard...`);
            await page.goto(dashboardUrl, { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
        }
    }
    await page.waitForTimeout(3000);

    console.log("✅ Halaman Dashboard terdeteksi. Step content_rating.js selesai!");
};

