module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: app_access.js");

    const entryBtn = page.getByRole('button', { name: 'App access' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'App access' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();
    
    await page.getByRole('radio', { name: 'All or some functionality in' }).check();
    await page.getByRole('button', { name: 'Add instructions' }).click();
    await page.getByRole('group', { name: 'Instruction name' }).getByLabel('', { exact: true }).click();
    await page.getByRole('group', { name: 'Instruction name' }).getByLabel('', { exact: true }).fill('login');
    await page.getByRole('textbox', { name: 'Username, email address, or' }).click();
    await page.getByRole('textbox', { name: 'Username, email address, or' }).fill('admin');
    await page.getByRole('textbox', { name: 'Password' }).click();
    await page.getByRole('textbox', { name: 'Password' }).fill('Hash82821Micro#');
    await page.getByRole('checkbox', { name: 'No other information is' }).check();
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await page.getByRole('button', { name: 'Save' }).click();
    await page.waitForTimeout(2000);
    // scroll ke paling atas
    await page.getByRole('button', { name: 'Dashboard' }).click();

    // 2. Beri jeda sebentar untuk menunggu render atau proses save.
    // await page.waitForTimeout(2000); 
    
    // 3. Kembali ke dashboard App Content (hanya untuk app_info)
    // await page.goto('https://play.google.com/console/...');
    
    console.log("✅ Step app_access.js selesai!");
};