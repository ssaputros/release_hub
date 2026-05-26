module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: financial_features.js");

    const entryBtn = page.getByRole('button', { name: 'Financial features' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'Financial features' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();
    
    await page.getByRole('checkbox', { name: 'My app doesn\'t provide any' }).check();
    await page.getByRole('button', { name: 'Next' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('button', { name: 'Save', exact: true }).click();

    // Tunggu proses save di background selesai
    await page.waitForTimeout(2000);

    await page.getByRole('button', { name: 'Dashboard' }).click();

    // 2. Beri jeda sebentar untuk menunggu render atau proses save.
    // await page.waitForTimeout(2000); 
    
    // 3. Kembali ke dashboard App Content (hanya untuk app_info)
    // await page.goto('https://play.google.com/console/...');
    
    console.log("✅ Step financial_features.js selesai!");
};
