// Run with Playwright MCP browser_run_code_unsafe.filename against a local /fpw/ page.
// Reuse the page's current anonymous or disposable-member session.
async (page) => {
  const base = "http://localhost:8500/fpw";
  const assert = (ok, message) => { if (!ok) throw new Error(message); };
  const results = [];
  await page.goto(base + "/help/", { waitUntil: "domcontentloaded" });
  const member = await page.locator("[data-fpw-member-identity]").count() > 0;
  const audience = member ? "member" : "anonymous";
  const destinations = ["/help/", "/app/user-manual.cfm", "/faq/", "/app/contact.cfm",
    "/app/contact.cfm?mode=support#contactForm", "/app/contact.cfm?mode=feedback#contactForm"];
  for (const [width, height] of [[1920,1000],[1440,1000],[1280,900],[1100,800],[1041,800],[1040,800],[1024,900],[768,900],[430,844],[390,844],[320,568],[1100,360],[390,360]]) {
    await page.setViewportSize({ width, height });
    await page.goto(base + "/help/", { waitUntil: "domcontentloaded" });
    const mobile = width <= 1040;
    if (mobile) await page.locator("[data-fpw-mobile-toggle]").click();
    const toggle = page.locator("#fpwHelpToggle");
    const menu = page.locator("#fpwHelpMenu");
    if (!mobile) {
      await toggle.hover();
      await page.waitForTimeout(250);
      assert(await toggle.getAttribute("aria-expanded") === "false", width + ": hover does not open");
    }
    await toggle.click();
    assert(await toggle.getAttribute("aria-expanded") === "true", width + ": expanded");
    assert(await menu.isVisible(), width + ": menu visible");
    const box = await menu.boundingBox();
    assert(box.x >= -1 && box.x + box.width <= width + 1, width + ": horizontal containment");
    if (!mobile) assert(box.y >= 0 && box.y + box.height <= height + 1, width + ": vertical containment");
    const links = menu.locator("a");
    assert(await links.count() === destinations.length, "Six Help destinations");
    for (let i = 0; i < destinations.length; i++) {
      assert(await links.nth(i).getAttribute("href") === "/fpw" + destinations[i], width + ": destination " + destinations[i]);
    }
    if (!mobile) {
      await toggle.click();
      assert(!(await menu.isVisible()), width + ": second click closes");
      await toggle.focus();
      assert(!(await menu.isVisible()), width + ": focus alone does not open");
      await toggle.click();
      await page.mouse.move(width - 10, height - 10);
      assert(await menu.isVisible(), width + ": pointer leaving does not dismiss a clicked menu");
    }
    await toggle.focus();
    await page.keyboard.press("ArrowDown");
    assert(await links.first().evaluate(node => node === document.activeElement), width + ": ArrowDown");
    await page.keyboard.press("End");
    assert(await links.last().evaluate(node => node === document.activeElement), width + ": End");
    await page.keyboard.press("Home");
    assert(await links.first().evaluate(node => node === document.activeElement), width + ": Home");
    await page.keyboard.press("ArrowUp");
    assert(await links.last().evaluate(node => node === document.activeElement), width + ": ArrowUp wraps");
    await links.last().scrollIntoViewIfNeeded();
    const last = await links.last().boundingBox();
    assert(last.y >= 0 && last.y + last.height <= height + 1, width + ": last link reachable");
    await page.keyboard.press("Escape");
    assert(!(await menu.isVisible()), width + ": Escape closes Help");
    if (mobile) {
      const drawerToggle = page.locator("[data-fpw-mobile-toggle]");
      assert(await drawerToggle.getAttribute("aria-expanded") === "false", width + ": Escape closes drawer");
      assert(await drawerToggle.evaluate(node => node === document.activeElement), width + ": Escape restores drawer-toggle focus");
      await drawerToggle.click();
      await toggle.focus();
    } else {
      assert(await toggle.evaluate(node => node === document.activeElement), width + ": Escape restores Help focus");
    }
    await page.keyboard.press("Space");
    assert(await menu.isVisible(), width + ": Space activation");
    await page.keyboard.press("Enter");
    assert(!(await menu.isVisible()), width + ": Enter toggle");
    await toggle.click();
    if (mobile) {
      assert(await page.evaluate(() => document.body.style.overflow) === "hidden", width + ": body scroll locked");
      await page.locator("[data-fpw-mobile-close]").click();
      assert(!(await menu.isVisible()), width + ": drawer closes Help");
      assert(await page.evaluate(() => document.body.style.overflow) !== "hidden", width + ": body scroll restored");
    } else {
      await page.mouse.click(width - 10, height - 10);
      assert(!(await menu.isVisible()), width + ": outside click");
      const explore = page.locator("[aria-controls=fpwExploreMenu]");
      await explore.hover();
      assert(await explore.getAttribute("aria-expanded") === "false", width + ": Explore is also click-only");
    }
    if (mobile) await page.locator("[data-fpw-mobile-toggle]").click();
    await toggle.click();
    if ([1920,1440,390,320].includes(width) && height > 500) {
      await links.first().scrollIntoViewIfNeeded();
      await page.screenshot({ path: "output/playwright/global-help/" + audience + "-" + width + ".png" });
    }
    results.push({ audience, width, height, keyboard: true, containment: true, scrolling: true });
  }
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto(base + "/help/");
  assert(await page.locator(".fpw-help-topic").count() === 9, "Nine categories");
  assert(await page.locator("link[rel=canonical]").getAttribute("href") === "https://floatplanwizard.com/help/", "Canonical");
  const search = page.locator("[data-help-search]");
  await search.fill("boat loan");
  assert(await page.locator("#calculators-and-tools").isVisible(), "Category link search");
  await search.fill("no-such-help-topic-93481");
  assert(await page.locator("[data-help-empty]").isVisible(), "No results");
  await page.locator("[data-help-search-clear]").click();
  assert(await page.locator("[data-help-section]:visible").count() === await page.locator("[data-help-section]").count(), "Clear restores topics");
  await page.screenshot({ path: "output/playwright/global-help/" + audience + "-directory.png" });
  return { audience, viewports: results, search: true };
}
