async (page) => {
  const context = await page.context().browser().newContext();
  const check = await context.newPage();
  await check.route("**/*", route => new URL(route.request().url()).hostname === "localhost" ? route.continue() : route.abort());
  const results = [];
  const hasPublicBase=(candidate,base)=> {
    const url=new URL(candidate), expected=new URL(base);
    const mount=expected.pathname.replace(/\/$/,"");
    return url.origin===expected.origin && (url.pathname===mount || url.pathname.startsWith(mount+"/"));
  };
  try {
    for (const environment of ["production", "development"]) {
      const response = await context.request.get("http://localhost:8500/fpw/tests/email-reliability-capture.cfm?confirm=RUN_EMAIL_RELIABILITY_CAPTURE&environment=" + environment);
      if (!response.ok()) throw new Error(await response.text());
      const payload = await response.json();
      if (payload.MESSAGES.length !== 21) throw new Error("Shared inventory must contain 21 variants.");
      const base = environment === "production" ? "https://floatplanwizard.com" : "http://localhost:8500/fpw";
      if (payload.PUBLICBASEURL !== base) throw new Error("Unexpected public origin.");
      for (const message of payload.MESSAGES) {
        if (!/@floatplanwizard\.com>?$/i.test(message.FROM)) throw new Error("Invalid From: " + message.VARIANT);
        if (message.REPLYTO && !/@floatplanwizard\.com$/i.test(message.REPLYTO)) throw new Error("Invalid Reply-To");
        const record = { environment, variant: message.VARIANT, from: message.FROM, replyTo: message.REPLYTO, ctas: [] };
        if (message.HTMLBODY) {
          await check.setContent(message.HTMLBODY);
          const inspected = await check.evaluate(() => {
            const bodyText = document.body.innerText;
            const literalUrls = [...document.querySelectorAll(".fpw-email-url-fallback, a")].map(e=>e.innerText.trim()).filter(t=>/^https?:\/\//.test(t));
            return {
              links: [...document.querySelectorAll("a")].map(a => ({label:a.innerText, href:a.getAttribute("href"), visible:literalUrls.includes(a.getAttribute("href")), fallback:literalUrls.find(t=>t===a.getAttribute("href")) || "", hasJavascript:a.hasAttribute("onclick") || /^javascript:/i.test(a.getAttribute("href") || "")})),
              fallbacks:[...document.querySelectorAll(".fpw-email-url-fallback")].map(s => s.textContent),
              scripts:document.querySelectorAll("script").length,
              malformed:document.querySelectorAll("a a, p p").length,
              leakedEntities:/&(?:amp|#38|#x26);/.test(bodyText)
            };
          });
          if (inspected.scripts || inspected.malformed || inspected.leakedEntities) throw new Error("Malformed email HTML " + message.VARIANT);
          for (const link of inspected.links) {
            if (!hasPublicBase(link.href,base) || link.hasJavascript || !link.visible) throw new Error("CTA origin or fallback failure " + message.VARIANT + " " + link.label);
            if (!message.TEXTBODY.includes(link.href)) throw new Error("Plaintext URL differs " + message.VARIANT);
            record.ctas.push({label:link.label, href:link.href, fallback:link.fallback, equal:true});
          }
          if (message.VARIANT.startsWith("Recovery ") && message.VARIANT !== "Recovery personal") {
            const action = inspected.links[0].href;
            if (!action.includes("/app/recovery-click.cfm?t=") || inspected.fallbacks[0] !== action) throw new Error("Recovery fallback is not the final tracked URL.");
          }
        } else {
          const textUrls=message.TEXTBODY.match(/https?:\/\/[^\s]+/g)||[];
          if (textUrls.length !== 2 || textUrls.some(url=>!hasPublicBase(url,base))) throw new Error("Early access public URL mismatch.");
        }
        record.status = "PASS"; results.push(record);
      }
      if (payload.EARLYACCESSCOPIES.length !== 2 || payload.EARLYACCESSCOPIES[0].TEXTBODY !== payload.EARLYACCESSCOPIES[1].TEXTBODY) throw new Error("Retained early-access helper mismatch.");
    }
    const directResponse=await context.request.get("http://localhost:8500/fpw/tests/direct-email-reliability-capture.cfm?confirm=CAPTURE_DIRECT_EMAILS_NO_SMTP");
    if(!directResponse.ok()) throw new Error(await directResponse.text());
    const direct=await directResponse.json();
    if(direct.COUNT!==7) throw new Error("Expected seven direct variants.");
    for(const message of direct.VARIANTS) {
      if(!/@floatplanwizard\.com>?$/i.test(message.FROM)) throw new Error("Direct sender domain failure.");
      const contact=message.VARIANT === "contact_us";
      if(message.REPLYTO && !contact && !/@floatplanwizard\.com$/i.test(message.REPLYTO)) throw new Error("Direct Reply-To domain failure.");
      if(!message.SUBJECT || !(message.HTMLBODY||message.TEXTBODY)) throw new Error("Direct capture incomplete.");
      if(message.HTMLBODY) {
        await check.setContent(message.HTMLBODY);
        if(await check.locator("script, a").count()) throw new Error("Unexpected direct-email action needs fallback review.");
      }
      results.push({environment:"both",variant:message.VARIANT,from:message.FROM,replyTo:message.REPLYTO,approvedVisitorReplyTo:contact,origin:"N/A: no URLs",fallback:"N/A: no CTA",status:"PASS"});
    }
    return {status:"PASS", variants:28, originConfigurations:2, checks:results};
  } finally { await context.close(); }
}
