const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

test("email destinations preserve login, ownership, preferences and reject injection", async ({ page }, testInfo) => {
  test.setTimeout(180000);
  const sourcePath = path.join(__dirname, "email-auth-continuation.playwright.js");
  const run = vm.runInThisContext(fs.readFileSync(sourcePath, "utf8"), { filename: sourcePath });
  const result = await run(page);
  await testInfo.attach("email-auth-continuation-results", { body: JSON.stringify(result, null, 2), contentType: "application/json" });
  console.log(JSON.stringify(result));
  expect(result.cleanupVerified).toBe(true);
  expect(result.results.filter(item => !item.passed)).toEqual([]);
  expect(result.ok).toBe(true);
});
