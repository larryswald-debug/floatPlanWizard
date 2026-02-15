const { test } = require("@playwright/test");

test.afterEach(async ({ page }, testInfo) => {
  if (testInfo.status !== testInfo.expectedStatus) {
    console.log(`❌ Test failed: ${testInfo.title}`);
    if (process.env.PW_DEBUG_PAUSE_ON_FAIL === "1") {
      await page.pause();
    }
  }
});
