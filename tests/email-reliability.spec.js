const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

test("all 28 email variants enforce sender, public origin and decoded fallback equality", async ({ page }, testInfo) => {
  const sourcePath = path.join(__dirname, "email-reliability.playwright.js");
  const run = vm.runInThisContext(fs.readFileSync(sourcePath, "utf8"), { filename: sourcePath });
  const result = await run(page);
  await testInfo.attach("email-reliability-results", { body: JSON.stringify(result, null, 2), contentType: "application/json" });
  expect(result.status).toBe("PASS");
  expect(result.variants).toBe(28);
  expect(result.checks.every(item => item.status === "PASS")).toBe(true);
});
