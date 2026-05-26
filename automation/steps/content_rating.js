module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: content_rating.js");

    const entryBtn = page.getByRole('button', { name: 'Content rating' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'Content rating' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();

    const startBtn = page.getByRole('button', { name: 'Start questionnaire' });
    const editBtn = page.getByRole('button', { name: 'Edit' });

    // Tunggu sebentar hingga salah satu tombol muncul
    await startBtn.or(editBtn).waitFor({ state: 'visible', timeout: 10000 }).catch(() => {});

    if (await startBtn.isVisible()) {
        await startBtn.click();
    } else if (await editBtn.isVisible()) {
        await editBtn.click();
    } else {
        console.log("⚠️ Tidak menemukan tombol 'Start questionnaire' maupun 'Edit'. Mencoba lanjut...");
    }

    await page.getByLabel('', { exact: true }).click();
    await page.getByLabel('', { exact: true }).fill('product@hashmicro.com');
    await page.getByRole('radio', { name: 'All Other App Types' }).check();
    await page.getByRole('checkbox', { name: 'I agree to the Terms of Use' }).check();
    await page.getByRole('button', { name: 'Next' }).click();
    await page.waitForTimeout(2000);

    console.log("\n============================================================");
    console.log("🛑 INTERVENSI MANUAL DIBUTUHKAN!");
    console.log("Skrip telah mengisi form tahap pertama.");
    console.log("Silakan lanjutkan mengisi sisa kuesioner (checklist radio button) di browser secara manual.");
    console.log("Setelah selesai, simpan (Save -> Next -> Save), lalu klik tombol 'Go back to Dashboard'.");
    console.log("Skrip akan otomatis melanjutkan ke step berikutnya saat mendeteksi halaman Dashboard.");
    console.log("============================================================\n");

    // Tunggu sampai user kembali ke halaman dashboard (tanpa timeout)
    await page.waitForURL(/\/app-dashboard/, { timeout: 0 });
    
    console.log("✅ Halaman Dashboard terdeteksi. Step content_rating.js selesai!");
};
