const { test } = require("@playwright/test");

test.afterEach(async ({ page }, testInfo) => {
  if (testInfo.status !== testInfo.expectedStatus) {
    console.log(`❌ Test failed: ${testInfo.title}`);
    await page.pause();
  }
});
