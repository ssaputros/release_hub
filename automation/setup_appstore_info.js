const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const appleId = process.argv[2] || "";
const appName = process.argv[3] || "My App";

(async () => {
    const credentialsDir = path.join(__dirname, '../credentials');
    const profileDir = path.join(credentialsDir, '.chrome_profile');

    // Cek apakah folder profil Chrome sudah ada
    if (!fs.existsSync(profileDir)) {
        fs.mkdirSync(profileDir, { recursive: true });
    }

    console.log("============================================================");
    console.log(`🚀 MENJALANKAN AUTOMATION APP STORE INFO UNTUK: ${appName}`);
    console.log("============================================================");
    console.log("Browser akan terbuka otomatis dan melengkapi form.");
    console.log("============================================================");

    try {
        const context = await chromium.launchPersistentContext(profileDir, {
            headless: false,
            channel: 'chrome',
            viewport: null, // Fullscreen or default
            args: [
                '--start-maximized',
                '--disable-blink-features=AutomationControlled'
            ],
            ignoreDefaultArgs: ['--enable-automation']
        });

        await context.addInitScript(() => {
            Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
        });

        const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();
        // Set default timeout yang panjang untuk mentoleransi loading SPA Apple
        page.setDefaultTimeout(15000);
        
        const loginUrl = 'https://appstoreconnect.apple.com/';
        console.log(`🌐 Membuka ${loginUrl} untuk otentikasi...`);
        await page.goto(loginUrl, { waitUntil: 'networkidle' });
        
        console.log('⏳ Mengecek status login...');
        try {
            // Menunggu elemen 'My Apps' yang menandakan halaman beranda App Store Connect (sudah login)
            await page.waitForSelector('text=My Apps', { timeout: 15000 });
        } catch (e) {
            console.log('⚠️ Halaman beranda belum termuat atau Anda belum Login.');
            console.log('⏳ Silakan login secara manual (menunggu hingga 2 menit)...');
            await page.waitForSelector('text=My Apps', { timeout: 120000 });
        }

        if (appleId) {
            const targetUrl = `https://appstoreconnect.apple.com/apps/${appleId}/distribution/info`;
            console.log(`➡️ Berhasil login. Melanjutkan secara otomatis ke ${targetUrl} ...`);
            await page.goto(targetUrl, { waitUntil: 'networkidle' });
            
            console.log('⏳ Menunggu halaman pengaturan termuat...');
            await page.waitForSelector('text=App Privacy', { timeout: 30000 });
        }
        
        console.log("⚙️ Mengisi Content Rights & Age Ratings...");
        try {
            await page.getByRole('button', { name: 'Set Up Content Rights' }).click();
            await page.locator('.modal-body___1Ci0U > div > div:nth-child(2) > div').click();
            await page.getByRole('button', { name: 'Done', exact: true }).click();
            
            await page.getByRole('button', { name: 'Set Up Age Ratings' }).click();
            await page.locator('#parentalControls__false').check();
            await page.locator('#ageAssurance__false').check();
            await page.locator('#unrestrictedWebAccess__false').check();
            await page.locator('#userGeneratedContent__false').check();
            await page.locator('#messagingAndChat__false').check();
            await page.locator('#advertising__false').check();
            await page.getByRole('button', { name: 'Next' }).click();
            
            await page.locator('#profanityOrCrudeHumor__NONE').check();
            await page.locator('#horrorOrFearThemes__NONE').check();
            await page.locator('#alcoholTobaccoOrDrugUseOrReferences__NONE').check();
            await page.getByRole('button', { name: 'Next' }).click();
            
            await page.locator('#medicalOrTreatmentInformation__NONE').check();
            await page.locator('#healthOrWellnessTopics__false').check();
            await page.getByRole('button', { name: 'Next' }).click();
            
            await page.locator('#matureOrSuggestiveThemes__NONE').check();
            await page.locator('#sexualContentOrNudity__NONE').check();
            await page.locator('#sexualContentGraphicAndNudity__NONE').check();
            await page.getByRole('button', { name: 'Next' }).click();
            
            await page.locator('#violenceCartoonOrFantasy__NONE').check();
            await page.locator('#violenceRealistic__NONE').check();
            await page.locator('#violenceRealisticProlongedGraphicOrSadistic__NONE').check();
            await page.locator('#gunsOrOtherWeapons__NONE').check();
            await page.getByRole('button', { name: 'Next' }).click();
            
            await page.locator('#gamblingSimulated__NONE').check();
            await page.locator('#contests__NONE').check();
            await page.locator('#gambling__false').check();
            await page.locator('#lootBox__false').check();
            await page.getByRole('button', { name: 'Next' }).click();
            
            await page.getByLabel('Age RatingsStep 1Step 2Step').getByRole('button', { name: 'Save' }).click();
            await page.waitForTimeout(3000);
            
            await page.getByRole('button', { name: 'Save' }).click();
            await page.waitForTimeout(3000);
        } catch (e) {
            console.log("⚠️ Content Rights / Age Ratings gagal atau sudah diatur sebelumnya.");
        }

        console.log("⚙️ Mengisi App Privacy...");
        try {
            await page.getByRole('link', { name: 'App Privacy' }).click();
            await page.getByRole('button', { name: 'Get Started' }).click();
            await page.getByRole('radio', { name: 'No, we do not collect data' }).check();
            await page.getByRole('button', { name: 'Save' }).click();
            await page.waitForTimeout(3000);
            
            await page.getByRole('button', { name: 'Publish' }).click();
            await page.waitForTimeout(2000);
            await page.getByLabel('Publish Your App Privacy').getByRole('button', { name: 'Publish' }).click();
            await page.waitForTimeout(4000);
        } catch (e) {
            console.log("⚠️ App Privacy gagal atau sudah diatur sebelumnya.");
        }

        console.log("⚙️ Mengisi Pricing and Availability...");
        try {
            await page.getByRole('link', { name: 'Pricing and Availability' }).click();
            await page.getByRole('button', { name: 'Add Pricing' }).click();
            await page.getByRole('button', { name: 'Choose' }).click();
            await page.getByRole('button', { name: '$0.00' }).click();
            await page.getByRole('button', { name: 'Next' }).click();
            await page.getByRole('button', { name: 'Next' }).click();
            await page.getByRole('button', { name: 'Confirm' }).click();
            await page.waitForTimeout(3000);
            
            await page.getByRole('button', { name: 'Set Up Availability' }).click();
            await page.getByRole('button', { name: 'Next' }).click();
            await page.getByRole('button', { name: 'Confirm' }).click();
            await page.waitForTimeout(3000);
            
            await page.getByRole('link', { name: 'Pricing and Availability' }).click();
            await page.getByRole('checkbox', { name: 'Make this app available', exact: true }).uncheck();
            await page.getByRole('checkbox', { name: 'Make this app available on' }).uncheck();
            await page.getByRole('button', { name: 'Save' }).click();
            await page.waitForTimeout(3000);
        } catch (e) {
            console.log("⚠️ Pricing and Availability gagal atau sudah diatur sebelumnya.");
        }

        console.log("✅ Proses otomatisasi App Store Info selesai.");
        await context.close();
    } catch (error) {
        console.error("❌ Terjadi kesalahan fatal:", error.message);
        console.log("⚠️ Script di-PAUSE untuk inspeksi manual...");
        // Jika belum tertutup, kita tidak punya akses page di catch luar dengan mudah
        // tapi log ini akan membantu user
    }
})();
