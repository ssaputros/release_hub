module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: privacy_policy.js");

    const entryBtn = page.getByRole('button', { name: 'Set privacy policy' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'Set privacy policy' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();
    
    await page.getByRole('textbox', { name: 'Privacy policy URL' }).click();
    await page.getByRole('textbox', { name: 'Privacy policy URL' }).fill('https://hashmicro.com/privacy-policy');
    await page.getByRole('button', { name: 'Save' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('link', { name: 'Go back to Dashboard' }).click();


    // 2. Beri jeda sebentar untuk menunggu render atau proses save.
    // await page.waitForTimeout(2000); 
    
    // 3. Kembali ke dashboard App Content (hanya untuk app_info)
    // await page.goto('https://play.google.com/console/...');
    
    console.log("✅ Step privacy_policy.js selesai!");
};