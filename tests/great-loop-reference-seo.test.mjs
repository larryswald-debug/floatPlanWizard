import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
const robots = fs.readFileSync(new URL("../robots.txt", import.meta.url), "utf8");
const config = fs.readFileSync(new URL("../web.config", import.meta.url), "utf8");
const sitemap = fs.readFileSync(new URL("../sitemap.xml", import.meta.url), "utf8");
const escapeRegex = value => value.replace(/[.+?^$(){}|[\]\\]/g, "\\$&");
// This repo has one wildcard user-agent group. Evaluate its allow/disallow
// precedence, including wildcards and end anchors, for the production paths.
function allowed(path) {
  const matches = [];
  for (const line of robots.split(/\r?\n/)) {
    const match = line.match(/^(Allow|Disallow):\s*(\S+)/);
    if (!match) continue;
    const rule = match[2], end = rule.endsWith("$");
    const pattern = end ? rule.slice(0, -1) : rule;
    const regex = new RegExp("^" + pattern.split("*").map(escapeRegex).join(".*") + (end ? "$" : ""));
    if (regex.test(path)) matches.push({ allow: match[1] === "Allow", length: pattern.replace(/\*/g, "").length });
  }
  matches.sort((a,b) => b.length - a.length || Number(b.allow) - Number(a.allow));
  return matches.length ? matches[0].allow : true;
}
test("the canonical reference, redirects and rendering assets are crawlable", () => {
  assert.deepEqual([...robots.matchAll(/^User-agent:\s*(.+)$/gm)].map(m => m[1]), ["*"]);
  for (const path of [
    "/fpw_great_loop_clockwise/index.cfm", "/fpw_great_loop_clockwise/index.html",
    "/fpw_great_loop_clockwise/", "/fpw_great_loop_clockwise",
    "/fpw_great_loop_clockwise/assets/css/fpw_great_loop.css",
    "/fpw_great_loop_clockwise/assets/js/fpw_great_loop.js?v=20261028-template-locks"
  ]) assert.equal(allowed(path), true, path);
});
test("other directory files and private/token URLs keep their existing blocks", () => {
  for (const path of [
    "/fpw_great_loop_clockwise/README.txt", "/fpw_great_loop_clockwise/footer.cfm",
    "/fpw_great_loop_clockwise/index.cfm?token=secret", "/api/v1/route.cfc",
    "/app/account.cfm", "/tests/great-loop-reference-runner.cfm", "/_fpw_private/example"
  ]) assert.equal(allowed(path), false, path);
  assert.equal(allowed("/great-loop/trip-planning/"), true);
});
test("IIS clean routing is narrowly matched and original-request guarded to prevent loops", () => {
  const rule = config.match(/<rule name="Redirect Great Loop leg reference aliases to clean URL"[\s\S]*?<\/rule>/)?.[0];
  assert.ok(rule);
  const path = new RegExp(rule.match(/<match url="([^"]+)"/)[1], "i");
  const original = new RegExp(rule.match(/input="\{THE_REQUEST\}" pattern="([^"]+)"/)[1], "i");
  for (const alias of ["fpw_great_loop_clockwise/index.html", "fpw_great_loop_clockwise/index.cfm", "fpw_great_loop_clockwise"]) {
    for (const query of ["", "?check=1"]) {
      assert.ok(path.test(alias)); assert.ok(original.test("GET /" + alias + query + " HTTP/1.1"));
    }
  }
  for (const other of ["fpw_great_loop_clockwise/", "fpw_great_loop_clockwise/assets/x.css", "fpw_great_loop_clockwise/README.txt", "fpw_great_loop_clockwise_other/index.cfm"]) {
    assert.equal(path.test(other) && original.test("GET /" + other + " HTTP/1.1"), false);
    assert.equal(original.test("GET /" + other + " HTTP/1.1"), false);
  }
  // Default-document resolution may present index.cfm while the original request is clean.
  assert.equal(original.test("GET /fpw_great_loop_clockwise/?check=1 HTTP/1.1"), false);
  assert.match(rule, /url="\/fpw_great_loop_clockwise\/" redirectType="Permanent" appendQueryString="true"/);
  const rewrite = config.match(/<rule name="Great Loop leg reference clean URL to CFM"[\s\S]*?<\/rule>/)?.[0];
  assert.ok(rewrite);
  assert.equal(rewrite.match(/<match url="([^"]+)"/)[1], "^fpw_great_loop_clockwise/$");
  assert.match(rewrite, /type="Rewrite" url="\/fpw_great_loop_clockwise\/index.cfm" appendQueryString="true"/);
  assert.equal(config.includes('<rule name="Redirect Great Loop leg reference aliases to CFM"'), false);
  assert.equal(fs.existsSync(new URL("../fpw_great_loop_clockwise/index.html", import.meta.url)), false);
});
test("sitemap uses one clean canonical and no index filename duplicates", () => {
  const locs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m=>m[1]);
  assert.equal(locs.filter(url => url === "https://floatplanwizard.com/fpw_great_loop_clockwise/").length, 1);
  assert.equal(locs.some(url => /\/fpw_great_loop_clockwise\/index\.(?:html|cfm)$/.test(url)), false);
});
