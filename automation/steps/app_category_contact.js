module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: app_category_contact.js");

    const entryBtn = page.getByRole('button', { name: 'Select an app category and' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'App category and contact' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();
    
    await page.locator('console-header').filter({ hasText: 'App categoryEdit Choose an' }).locator('button').click();
    await page.getByRole('button', { name: 'Select a category' }).click();
    await page.getByRole('option', { name: 'Business' }).click();
    await page.getByRole('button', { name: 'Save' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('button', { name: 'Close' }).click();
    await page.locator('console-header').filter({ hasText: 'Store listing contact' }).locator('button').click();
    await page.locator('console-form-row').filter({ hasText: 'Email address *' }).getByLabel('', { exact: true }).click();
    await page.locator('console-form-row').filter({ hasText: 'Email address *' }).getByLabel('', { exact: true }).fill('product@hashmicro.com');
    await page.getByRole('button', { name: 'Save' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('button', { name: 'Close' }).click();

    // 2. Beri jeda sebentar untuk menunggu render atau proses save.
    // await page.waitForTimeout(2000); 
    
    // 3. Kembali ke dashboard App Content (hanya untuk app_info)
    // await page.goto('https://play.google.com/console/...');
    
    console.log("✅ Step app_category_contact.js selesai!");
};
