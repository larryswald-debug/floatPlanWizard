const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

test("Day 39 recovery destinations preserve login, ownership, and useful actions", async ({ page }, testInfo) => {
  test.setTimeout(300000);
  const sourcePath = path.join(__dirname, "inactive-member-recovery-destination.playwright.js");
  const run = vm.runInThisContext(fs.readFileSync(sourcePath, "utf8"), { filename: sourcePath });
  const result = await run(page);
  await testInfo.attach("recovery-destination-results", { body: JSON.stringify(result, null, 2), contentType: "application/json" });
  console.log(JSON.stringify(result));
  expect(result.cleanupVerified, "Disposable fixture cleanup").toBe(true);
  expect(result.results.filter(item => !item.passed), "Recovery browser failures").toEqual([]);
  expect(result.ok).toBe(true);
});
