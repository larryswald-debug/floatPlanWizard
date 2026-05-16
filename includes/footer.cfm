<cfscript>
footerBasePath = "";

if (structKeyExists(request, "fpwBase")) {
  footerBasePath = trim(toString(request.fpwBase));
}

if (!len(footerBasePath) AND structKeyExists(cgi, "script_name")) {
  footerScriptName = trim(toString(cgi.script_name));
  footerBasePath = reReplace(footerScriptName, "/boat-fuel-calculator/boat-fuel-calculator\.cfm$", "");
  footerBasePath = reReplace(footerBasePath, "/why-use-a-float-plan\.cfm$", "");
  footerBasePath = reReplace(footerBasePath, "/privacy_policy\.cfm$", "");
  footerBasePath = reReplace(footerBasePath, "/terms_of_service\.cfm$", "");
  footerBasePath = reReplace(footerBasePath, "/error\.cfm$", "");
  footerBasePath = reReplace(footerBasePath, "/index\.cfm$", "");

  if (footerBasePath EQ footerScriptName) {
    footerBasePath = getDirectoryFromPath(footerScriptName);
    footerBasePath = reReplace(footerBasePath, "/$", "");
  }
}

footerBasePath = reReplace(footerBasePath, "/$", "");
if (footerBasePath EQ "/") {
  footerBasePath = "";
}
if (len(footerBasePath) AND left(footerBasePath, 1) NEQ "/") {
  footerBasePath = "/" & footerBasePath;
}
</cfscript>

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">

<style>
  .fpw-floatplan-footer,
  .fpw-floatplan-footer * {
    box-sizing: border-box;
  }

  .fpw-floatplan-footer {
    --fpw-footer-max: var(--fpw-public-layout-max, var(--fpw-max, 1320px));
    --fpw-footer-cyan: var(--fpw-cyan, var(--accent-2, #23d7cf));
    width: 100vw;
    max-width: 100vw;
    margin-left: calc(50% - 50vw);
    margin-right: calc(50% - 50vw);
    padding: 0 0 12px;
    background: #04101c;
    font-family: inherit;
  }

  .fpw-floatplan-footer__inner {
    width: min(var(--fpw-footer-max), calc(100% - 48px));
    margin: 0 auto;
    min-height: 64px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 18px;
    flex-wrap: wrap;
    border-top: 1px solid rgba(132, 183, 216, 0.18);
    padding: 16px 14px 0;
    color: rgba(238, 247, 251, 0.72);
  }

  .fpw-floatplan-footer__brand {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    color: #f2f7ff;
    font-weight: 800;
  }

  .fpw-floatplan-footer__brand i {
    color: var(--fpw-footer-cyan);
    font-size: 1.75rem;
  }

  .fpw-floatplan-footer__tag {
    display: block;
    margin-top: 2px;
    color: var(--fpw-footer-cyan);
    font-size: 0.62rem;
    font-weight: 850;
    letter-spacing: 0.14em;
    text-transform: uppercase;
  }

  .fpw-floatplan-footer__links,
  .fpw-floatplan-footer__social {
    display: flex;
    align-items: center;
    gap: 24px;
    flex-wrap: wrap;
    color: rgba(238, 247, 251, 0.78);
    font-size: 0.9rem;
  }

  .fpw-floatplan-footer__links a {
    color: inherit;
    text-decoration: none;
  }

  .fpw-floatplan-footer__links a:hover {
    color: #ffffff;
    text-decoration: none;
  }

  .fpw-floatplan-footer__social span {
    display: inline-flex;
    align-items: center;
  }

  .fpw-floatplan-footer__copy {
    color: rgba(238, 247, 251, 0.55);
    font-size: 0.84rem;
  }

  .fpw-floatplan-footer__social {
    gap: 18px;
    font-size: 1.1rem;
  }

  @media (max-width: 900px) {
    .fpw-floatplan-footer__inner {
      width: min(calc(100% - 28px), var(--fpw-footer-max));
    }
  }

  @media (max-width: 620px) {
    .fpw-floatplan-footer__inner {
      width: min(100% - 20px, var(--fpw-footer-max));
    }

    .fpw-floatplan-footer__links,
    .fpw-floatplan-footer__social {
      gap: 14px;
    }
  }
</style>

<cfoutput>
<footer class="fpw-floatplan-footer">
  <div class="fpw-floatplan-footer__inner">
    <div class="fpw-floatplan-footer__brand">
      <i class="bi bi-compass" aria-hidden="true"></i>
      <span>FloatPlanWizard<span class="fpw-floatplan-footer__tag">Plan Smart. Boat Safe.</span></span>
    </div>
    <nav class="fpw-floatplan-footer__links" aria-label="Footer">
      <a href="#footerBasePath#/index.cfm##story">About Us</a>
      <a href="#footerBasePath#/privacy_policy.cfm">Privacy Policy</a>
      <a href="#footerBasePath#/terms_of_service.cfm">Terms of Service</a>
      <a href="#footerBasePath#/index.cfm##notify">Contact Us</a>
    </nav>
    <div class="fpw-floatplan-footer__copy">&copy; 2026 FloatPlanWizard. All rights reserved.</div>
    <div class="fpw-floatplan-footer__social" aria-hidden="true">
      <span><i class="bi bi-facebook"></i></span>
      <span><i class="bi bi-instagram"></i></span>
      <span><i class="bi bi-youtube"></i></span>
    </div>
  </div>
</footer>
</cfoutput>
