const {test,expect}=require("@playwright/test");
const fs=require("node:fs");
const path=require("node:path");
const vm=require("node:vm");
test("Recovery Center real admin UI, controls, settings, preview and local personal follow-up",async({page},testInfo)=>{
  test.setTimeout(240000);
  const source=path.join(__dirname,"recovery-center.playwright.js");
  const result=await vm.runInThisContext(fs.readFileSync(source,"utf8"),{filename:source})(page);
  await testInfo.attach("recovery-center-results",{body:JSON.stringify(result,null,2),contentType:"application/json"});
  console.log(JSON.stringify(result));
  expect(result.cleanupVerified).toBe(true);
  expect(result.results.filter(r=>!r.passed)).toEqual([]);
  expect(result.ok).toBe(true);
});
