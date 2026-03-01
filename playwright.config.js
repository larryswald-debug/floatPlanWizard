const { devices } = require("@playwright/test");

module.exports = {
  testDir: "./tests",
  workers: process.env.PW_WORKERS ? Number(process.env.PW_WORKERS) : 3,
  use: {
    baseURL: "http://localhost:8500", // change if FPW runs elsewhere
    headless: false,                  // visible browser (best for learning)
    viewport: { width: 1280, height: 800 }
  },
  projects: [
    {
      name: "chromium",
      testIgnore: /.*\.mobile\.spec\.js/,
      use: { browserName: "chromium" }
    },
    {
      name: "firefox",
      testIgnore: /.*\.mobile\.spec\.js/,
      use: { browserName: "firefox" }
    },
    {
      name: "webkit",
      testIgnore: /.*\.mobile\.spec\.js/,
      use: { browserName: "webkit" }
    },
    {
      name: "mobile-chromium",
      testMatch: /.*\.mobile\.spec\.js/,
      use: {
        ...devices["Pixel 5"],
        browserName: "chromium"
      }
    },
    {
      name: "mobile-webkit",
      testMatch: /.*\.mobile\.spec\.js/,
      use: {
        ...devices["iPhone 13"],
        browserName: "webkit"
      }
    }
  ]
};
