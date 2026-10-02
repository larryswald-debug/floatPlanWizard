<cfif NOT structKeyExists(request, "fpwAuthModalRendered")>
  <cfset request.fpwAuthModalRendered = true>
  <cfscript>
  fpwAuthModalBase = structKeyExists(request, "fpwBase") ? trim(toString(request.fpwBase)) : "";
  if (!len(fpwAuthModalBase) AND isDefined("topNavBasePath")) fpwAuthModalBase = topNavBasePath;
  if (!len(fpwAuthModalBase) AND isDefined("footerBasePath")) fpwAuthModalBase = footerBasePath;
  fpwAuthModalBase = reReplace(fpwAuthModalBase, "/$", "");
  </cfscript>
  <cfoutput>
  <link rel="stylesheet" href="#encodeForHTMLAttribute(fpwAuthModalBase)#/assets/css/fpw-auth-modal.css?v=20261001-unified-auth">
  <dialog id="fpwAuthModal" class="fpw-auth-modal" aria-labelledby="fpwAuthTitle" aria-describedby="fpwAuthDescription" data-fpw-base="#encodeForHTMLAttribute(fpwAuthModalBase)#" data-clarity-mask="True">
    <div class="fpw-auth-modal__content">
      <button type="button" class="fpw-auth-modal__close" aria-label="Close account access" data-fpw-auth-close>&times;</button>
      <h2 id="fpwAuthTitle">Log in or create your free account</h2>
      <p id="fpwAuthDescription">Enter your email and password to continue.</p>
      <div id="fpwAuthAlert" class="fpw-auth-modal__alert" role="alert" tabindex="-1" hidden></div>
      <form id="fpwAuthForm" novalidate>
        <div class="fpw-auth-modal__field">
          <label for="fpwAuthEmail">Email</label>
          <input type="email" id="fpwAuthEmail" name="email" autocomplete="email" autocapitalize="none" spellcheck="false" maxlength="254" required>
        </div>
        <div class="fpw-auth-modal__field">
          <label for="fpwAuthPassword">Password</label>
          <input type="password" id="fpwAuthPassword" name="password" autocomplete="current-password" required>
        </div>
        <div class="fpw-auth-modal__honeypot" aria-hidden="true">
          <label for="fpwAuthWebsite">Website</label>
          <input type="text" id="fpwAuthWebsite" name="website" tabindex="-1" autocomplete="off">
        </div>
        <p class="fpw-auth-modal__disclosure">
          <span id="fpwAuthDisclosureText"></span>
          <a id="fpwAuthTerms" href="#encodeForHTMLAttribute(fpwAuthModalBase)#/terms_of_service.cfm" target="_blank" rel="noopener">Terms of Service</a>
          and <a id="fpwAuthPrivacy" href="#encodeForHTMLAttribute(fpwAuthModalBase)#/privacy_policy.cfm" target="_blank" rel="noopener">Privacy Policy</a>.
        </p>
        <button type="submit" id="fpwAuthContinue" class="fpw-auth-modal__continue">Continue</button>
        <a class="fpw-auth-modal__forgot" href="#encodeForHTMLAttribute(fpwAuthModalBase)#/app/forgot-password.cfm">Forgot password?</a>
      </form>
    </div>
  </dialog>
  <cfif NOT structKeyExists(request, "fpwApiScriptRendered")>
    <cfset request.fpwApiScriptRendered = true>
    <script>window.FPW_BASE = "#JSStringFormat(fpwAuthModalBase)#"; window.FPW_API_BASE = "#JSStringFormat(fpwAuthModalBase)#/api/v1";</script>
    <script src="#encodeForHTMLAttribute(fpwAuthModalBase)#/assets/js/app/api.js?v=20261001-unified-auth"></script>
  </cfif>
  <cfif NOT structKeyExists(request, "fpwAuthScriptRendered")>
    <cfset request.fpwAuthScriptRendered = true>
    <script src="#encodeForHTMLAttribute(fpwAuthModalBase)#/assets/js/app/auth.js?v=20261001-unified-auth"></script>
  </cfif>
  <script src="#encodeForHTMLAttribute(fpwAuthModalBase)#/assets/js/app/auth-modal.js?v=20261001-unified-auth"></script>
  </cfoutput>
</cfif>
