const { test, expect } = require("@playwright/test");

const diagnosticUrl = "http://localhost:8500/fpw/admin/email-test.cfm";

test("anonymous requests cannot open the email diagnostic", async ({ request }) => {
  const response = await request.get(diagnosticUrl, { failOnStatusCode: false });
  expect(response.status()).toBe(401);
  expect(response.headers()["cache-control"]).toContain("no-store");
  await expect(response.text()).resolves.toContain("Authentication is required");
});

test("anonymous POST attempts cannot use the diagnostic as a mail relay", async ({ request }) => {
  const response = await request.post(diagnosticUrl, {
    failOnStatusCode: false,
    form: {
      action: "send",
      adminCsrfToken: "invalid-token",
      testId: "DKIM-20260825-120000-AAAAAAAA",
      fromAddress: "anything@example.com",
      to: "outside@example.com",
      replyTo: "lswald@yahoo.com",
      subject: "Unauthorized relay test",
      messageBody: "This request must be rejected before mail submission.",
    },
  });

  expect(response.status()).toBe(401);
  expect(response.headers()["cache-control"]).toContain("no-store");
  await expect(response.text()).resolves.toContain("Authentication is required");
});
