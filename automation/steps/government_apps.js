const { waitAfterSave } = require('./_helpers');
module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: government_apps.js");
     
    const entryBtn = page.getByRole('button', { name: 'Government apps' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'Government apps' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();
    await page.getByRole('radio', { name: 'No' }).check();
    await page.getByRole('button', { name: 'Save' }).click();
    await waitAfterSave(page, 'government apps');
    await page.getByRole('link', { name: 'Go back to Dashboard' }).click();

    // 2. Beri jeda sebentar untuk menunggu render atau proses save.
    // await page.waitForTimeout(2000); 
    
    // 3. Kembali ke dashboard App Content (hanya untuk app_info)
    // await page.goto('https://play.google.com/console/...');
    
    console.log("✅ Step government_apps.js selesai!");
};
