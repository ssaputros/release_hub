const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const appName = process.argv[2] || "My App";
const appleId = process.argv[3] || "";
const appType = process.argv[4] || "HRM Apps";

(async () => {
    console.log(`🚀 Memulai Playwright untuk Unlisted App Request...`);
    console.log(`App Name: ${appName}`);
    console.log(`Apple ID: ${appleId}`);
    console.log(`App Type: ${appType}`);

    // Baca template dari folder unlisted_templates/<appType>
    const templateDir = path.join(__dirname, '..', 'unlisted_templates', appType);
    let businessProblemText = '';
    let publicDistText = '';
    let privateDistText = '';

    try {
        businessProblemText = fs.readFileSync(path.join(templateDir, 'business_problem_app_solves.txt'), 'utf8');
        publicDistText = fs.readFileSync(path.join(templateDir, 'why_unlisted_app_over_public_distribution.txt'), 'utf8');
        privateDistText = fs.readFileSync(path.join(templateDir, 'why_unlisted_app_over_private_distribution.txt'), 'utf8');
    } catch (e) {
        console.log(`⚠️ Peringatan: Gagal membaca file template dari ${templateDir}. Pastikan file .txt tersedia.`);
    }

    const userDataDir = path.join(__dirname, '..', 'credentials', '.chrome_profile');
    
    // Pastikan direktori profil ada
    if (!fs.existsSync(userDataDir)) {
        fs.mkdirSync(userDataDir, { recursive: true });
    }

    const context = await chromium.launchPersistentContext(userDataDir, {
        headless: false,
        viewport: null, // Fullscreen or default
        args: ['--start-maximized'],
        // Set timeout yang lama untuk menunggu input manual jika perlu
        timeout: 120000 
    });

    const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();
    
    console.log('🌐 Membuka halaman Unlisted App Request...');
    await page.goto('https://developer.apple.com/contact/request/unlisted-app/', { waitUntil: 'networkidle' });

    console.log('⏳ Menunggu halaman dimuat...');
    // Tunggu sampai form utama muncul
    try {
        await page.waitForSelector('//*[@id="contact-information"]', { timeout: 15000 });
    } catch (e) {
        console.log('⚠️ Form utama tidak langsung muncul. Anda mungkin perlu Login terlebih dahulu.');
        console.log('⏳ Menunggu login manual...');
        await page.waitForSelector('//*[@id="contact-information"]', { timeout: 120000 });
    }

    console.log('📝 Mengisi data form secara otomatis...');

    // 1. Coba isi App Name dan Apple ID secara dinamis (karena tidak ada di Automa JSON)
    try {
        const appNameInputs = ['input[name="app_name"]', 'input[id="app_name"]', 'input[id*="app-name"]', 'input[name*="AppName"]'];
        for (const sel of appNameInputs) {
            if (await page.locator(sel).count() > 0) {
                await page.fill(sel, appName);
                break;
            }
        }
        
        console.log('-> Mengisi Apple ID...');
        await page.getByRole('textbox', { name: 'How to find this ID ' }).click().catch(() => {});
        await page.getByRole('textbox', { name: 'How to find this ID ' }).fill(appleId).catch(() => {});
    } catch (e) {
        console.log('ℹ️ Tidak dapat mengisi App Name / Apple ID secara otomatis, silakan periksa manual.');
    }

    // Eksekusi flow sesuai Automa JSON
    try {
        // Event Click - Select organization type
        console.log('-> Memilih organization type...');
        await page.locator('//*[@id="contact-information"]/fieldset/label[4]/div/label[1]/input').click().catch(() => {});
        
        // Optional Select - contact_team_id
        const envTeamId = process.env.TEAM_ID;
        if (envTeamId) {
            const teamSelect = page.locator('//*[@id="contact_team_id"]');
            if (await teamSelect.count() > 0) {
                console.log(`-> Memilih Team ID (${envTeamId}) di contact_team_id...`);
                // Pilih berdasarkan value dari TEAM_ID. (menggunakan huruf besar agar case-insensitive sesuai request)
                await teamSelect.selectOption(envTeamId.toUpperCase()).catch(() => {});
            }
        }

        // Forms Select - is_submitted_for_review
        console.log('-> Mengatur is_submitted_for_review...');
        await page.locator('//*[@id="is_submitted_for_review"]').selectOption('yes').catch(() => {});

        // Forms Text-Field - business_problem_app_solves
        console.log('-> Mengisi business_problem_app_solves...');
        if (businessProblemText) await page.locator('//*[@id="business_problem_app_solves"]').fill(businessProblemText).catch(() => {});

        // Forms Text-Field - why_unlisted_app_over_public_distribution
        console.log('-> Mengisi why_unlisted_app_over_public_distribution...');
        if (publicDistText) await page.locator('//*[@id="why_unlisted_app_over_public_distribution"]').fill(publicDistText).catch(() => {});

        // Forms Text-Field - why_unlisted_app_over_private_distribution
        console.log('-> Mengisi why_unlisted_app_over_private_distribution...');
        if (privateDistText) await page.locator('//*[@id="why_unlisted_app_over_private_distribution"]').fill(privateDistText).catch(() => {});

        // Checkboxes & Radios
        console.log('-> Mencetang Checkboxes dan Radio Buttons...');
        const clickList = [
            '//*[@id="app-details"]/fieldset/section/label[4]/div/label[1]/input',
            '//*[@id="app-details"]/fieldset/section/label[7]/div/label[1]/input',
            '//*[@id="app-details"]/fieldset/section/label[7]/div/label[2]/input',
            '//*[@id="app-details"]/fieldset/section/label[9]/div/label[4]/input',
            '//*[@id="app-details"]/fieldset/section/label[11]/div/label[1]/input',
            '//*[@id="app-details"]/fieldset/section/label[11]/div/label[2]/input',
            '//*[@id="territories_all"]',
            '//*[@id="chk-agree"]/fieldset/label/div/label/input'
        ];

        for (const xpath of clickList) {
            await page.locator(xpath).click().catch(() => {});
        }

        // Additional Numbers
        console.log('-> Mengisi field angka (Users & Organizations)...');
        await page.locator('//*[@id="number_of_users"]').fill('500').catch(() => {});
        await page.locator('//*[@id="number_of_organizations"]').fill('1').catch(() => {});
        await page.locator('//*[@id="distribution_type_unmanaged"]').fill('500').catch(() => {});

    } catch (e) {
        console.log(`❌ Terjadi error saat mengisi formulir: ${e.message}`);
    }

    console.log('\n========================================================================');
    console.log('✅ Form telah diisi sesuai dengan template!');
    console.log('🚀 Mengirimkan formulir secara otomatis...');
    console.log('========================================================================\n');

    // Klik tombol submit
    await page.getByRole('button', { name: 'Submit' }).click().catch(() => {});
    
    // Verifikasi keberhasilan
    console.log('⏳ Menunggu konfirmasi keberhasilan...');
    try {
        await page.getByRole('heading', { name: 'Thank you for your submission.' }).waitFor({ state: 'visible', timeout: 30000 });
        console.log('🎉 Permintaan Unlisted App berhasil dikirim!');
        
        // Log hasil submit
        const logPath = path.join(__dirname, '..', 'unlisted_requests.log');
        const logEntry = `[${new Date().toLocaleString()}] SUCCESS: Unlisted Request for App: ${appName} | Apple ID: ${appleId} | Type: ${appType}\n`;
        fs.appendFileSync(logPath, logEntry);
        console.log(`📝 Log disimpan ke unlisted_requests.log`);
    } catch (e) {
        console.log('❌ Gagal mendeteksi layar "Thank you for your submission." dalam 30 detik.');
        console.log('⚠️ Terjadi error saat submit (Mungkin ada field yang terlewat). Script akan di-PAUSE untuk inspeksi manual.');
        await page.pause();
    }

    // Tutup browser
    await context.close();
})();
