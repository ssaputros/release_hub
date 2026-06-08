module.exports = async function(page, appData) {
    console.log("⏳ Memulai eksekusi step: app_access.js (Sign in details)");

    const entryBtn = page.getByRole('button', { name: 'Sign in details' });
    if (!await entryBtn.isVisible().catch(() => false)) {
        console.log("✅ Info 'Sign in details' sudah diisi (tombol tidak ditemukan). Melewati step ini.");
        return;
    }
    await entryBtn.click();
    
    await page.getByRole('radio', { name: 'Yes' }).check();
    await page.getByRole('button', { name: 'Add details' }).click();
    await page.getByRole('group', { name: 'Name', exact: true }).getByLabel('', { exact: true }).click();
    await page.getByRole('group', { name: 'Name', exact: true }).getByLabel('', { exact: true }).fill('Login');
    await page.getByRole('textbox', { name: 'Username, email address, or' }).click();
    await page.getByRole('textbox', { name: 'Username, email address, or' }).fill('Admin');
    await page.getByRole('textbox', { name: 'Password' }).click();
    await page.getByRole('textbox', { name: 'Password' }).fill('Hash82821Micro#');
    await page.getByRole('checkbox', { name: 'Sign in details in this' }).check();
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await page.getByRole('button', { name: 'Save' }).click();
    await page.getByRole('link', { name: 'Go back to Dashboard' }).click();

    console.log("✅ Step app_access.js selesai!");
};