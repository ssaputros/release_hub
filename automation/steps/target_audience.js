module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: target_audience.js");

    const entryBtn = page.getByRole('button', { name: 'Target audience' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'Target audience' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();
    
    await page.getByRole('checkbox', { name: 'and over' }).check();
    await page.getByRole('button', { name: 'Next' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('button', { name: 'Save' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('link', { name: 'Go back to Dashboard' }).click();    

    // 2. Beri jeda sebentar untuk menunggu render atau proses save.
    // await page.waitForTimeout(2000); 
    
    // 3. Kembali ke dashboard App Content (hanya untuk app_info)
    // await page.goto('https://play.google.com/console/...');
    
    console.log("✅ Step target_audience.js selesai!");
};
