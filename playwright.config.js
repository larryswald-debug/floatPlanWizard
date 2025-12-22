module.exports = {
  testDir: "./tests",
  use: {
    baseURL: "http://localhost:8500", // change if FPW runs elsewhere
    headless: false,                  // visible browser (best for learning)
    viewport: { width: 1280, height: 800 }
  }
};
