const DEFAULT_SAVE_SETTLE_DELAY_MS = Number.parseInt(process.env.PLAYSTORE_SAVE_SETTLE_DELAY_MS || '8000', 10);

function getSaveSettleDelayMs() {
    if (Number.isFinite(DEFAULT_SAVE_SETTLE_DELAY_MS) && DEFAULT_SAVE_SETTLE_DELAY_MS >= 0) {
        return DEFAULT_SAVE_SETTLE_DELAY_MS;
    }
    return 8000;
}

async function waitAfterSave(page, sectionName = 'section') {
    const delayMs = getSaveSettleDelayMs();
    const seconds = (delayMs / 1000).toFixed(delayMs % 1000 === 0 ? 0 : 1);
    console.log(`⏳ Menunggu ${seconds}s agar proses save ${sectionName} selesai sebelum lanjut/navigasi...`);
    await page.waitForTimeout(delayMs);
}

module.exports = {
    waitAfterSave,
    getSaveSettleDelayMs,
};
