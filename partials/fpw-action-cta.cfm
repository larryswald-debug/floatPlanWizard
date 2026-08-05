<cfscript>
fpwActionCtaConfig = (isDefined("fpwCtaConfig") AND isStruct(fpwCtaConfig))
  ? duplicate(fpwCtaConfig)
  : {};

fpwActionCtaId = structKeyExists(fpwActionCtaConfig, "id")
  ? trim(toString(fpwActionCtaConfig.id))
  : "";
fpwActionCtaId = reReplace(lCase(fpwActionCtaId), "[^a-z0-9_-]+", "-", "all");
fpwActionCtaId = reReplace(fpwActionCtaId, "(^-+|-+$)", "", "all");
if (!len(fpwActionCtaId)) {
  fpwActionCtaId = "fpw-action-cta-" & reReplace(lCase(createUUID()), "[^a-z0-9]", "", "all");
}

fpwActionCtaHeadingId = fpwActionCtaId & "-title";
fpwActionCtaHeadline = structKeyExists(fpwActionCtaConfig, "headline")
  ? trim(toString(fpwActionCtaConfig.headline))
  : "";
fpwActionCtaSupportingText = structKeyExists(fpwActionCtaConfig, "supportingText")
  ? trim(toString(fpwActionCtaConfig.supportingText))
  : "";
fpwActionCtaButtonLabel = structKeyExists(fpwActionCtaConfig, "buttonLabel")
  ? trim(toString(fpwActionCtaConfig.buttonLabel))
  : "";
fpwActionCtaDestinationUrl = structKeyExists(fpwActionCtaConfig, "destinationUrl")
  ? trim(toString(fpwActionCtaConfig.destinationUrl))
  : "";
fpwActionCtaAriaLabel = structKeyExists(fpwActionCtaConfig, "ariaLabel")
  ? trim(toString(fpwActionCtaConfig.ariaLabel))
  : "";
fpwActionCtaUnavailableMessage = structKeyExists(fpwActionCtaConfig, "unavailableMessage")
  ? trim(toString(fpwActionCtaConfig.unavailableMessage))
  : "Route planning is currently unavailable.";

fpwActionCtaAnalyticsEvent = structKeyExists(fpwActionCtaConfig, "analyticsEvent")
  ? trim(toString(fpwActionCtaConfig.analyticsEvent))
  : "";
fpwActionCtaSourcePage = structKeyExists(fpwActionCtaConfig, "sourcePage")
  ? trim(toString(fpwActionCtaConfig.sourcePage))
  : "";
fpwActionCtaSection = structKeyExists(fpwActionCtaConfig, "section")
  ? trim(toString(fpwActionCtaConfig.section))
  : "";
fpwActionCtaType = structKeyExists(fpwActionCtaConfig, "ctaType")
  ? trim(toString(fpwActionCtaConfig.ctaType))
  : "";
fpwActionCtaAuthState = structKeyExists(fpwActionCtaConfig, "authState")
  ? lCase(trim(toString(fpwActionCtaConfig.authState)))
  : "";
fpwActionCtaDestinationKey = structKeyExists(fpwActionCtaConfig, "destinationKey")
  ? trim(toString(fpwActionCtaConfig.destinationKey))
  : "";

fpwActionCtaContentValid = (
  len(fpwActionCtaHeadline)
  AND len(fpwActionCtaSupportingText)
  AND len(fpwActionCtaButtonLabel)
  AND len(fpwActionCtaAriaLabel)
);
fpwActionCtaDestinationSupported = (
  len(fpwActionCtaDestinationUrl)
  AND find("?", fpwActionCtaDestinationUrl) EQ 0
  AND find("##", fpwActionCtaDestinationUrl) EQ 0
  AND find(chr(92), fpwActionCtaDestinationUrl) EQ 0
  AND (
    (
      left(fpwActionCtaDestinationUrl, 1) EQ "/"
      AND left(fpwActionCtaDestinationUrl, 2) NEQ "//"
      AND reFindNoCase("/app/(dashboard|join)\.cfm$", fpwActionCtaDestinationUrl) GT 0
    )
    OR reFindNoCase("^\.\./app/(dashboard|join)\.cfm$", fpwActionCtaDestinationUrl) GT 0
  )
);
fpwActionCtaCanNavigate = fpwActionCtaContentValid AND fpwActionCtaDestinationSupported;
fpwActionCtaTrackingValid = (
  reFind("^[a-z0-9_]+$", fpwActionCtaAnalyticsEvent) GT 0
  AND reFind("^[a-z0-9_]+$", fpwActionCtaSourcePage) GT 0
  AND reFind("^[a-z0-9_]+$", fpwActionCtaSection) GT 0
  AND reFind("^[a-z0-9_]+$", fpwActionCtaType) GT 0
  AND listFindNoCase("signed_in,signed_out", fpwActionCtaAuthState) GT 0
  AND reFind("^[a-z0-9_]+$", fpwActionCtaDestinationKey) GT 0
);

if (!len(fpwActionCtaUnavailableMessage)) {
  fpwActionCtaUnavailableMessage = "Route planning is currently unavailable.";
}
if (!len(fpwActionCtaHeadline)) {
  fpwActionCtaHeadline = "Plan your route";
}
if (!len(fpwActionCtaSupportingText)) {
  fpwActionCtaSupportingText = fpwActionCtaUnavailableMessage;
}
</cfscript>

<section class="fpw-action-cta" id="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaId)#</cfoutput>" aria-labelledby="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaHeadingId)#</cfoutput>">
  <div class="fpw-action-cta__content">
    <h2 id="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaHeadingId)#</cfoutput>"><cfoutput>#encodeForHTML(fpwActionCtaHeadline)#</cfoutput></h2>
    <p><cfoutput>#encodeForHTML(fpwActionCtaSupportingText)#</cfoutput></p>
  </div>

  <div class="fpw-action-cta__action">
    <cfif fpwActionCtaCanNavigate>
      <a
        class="fpw-cta fpw-cta-primary"
        href="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaDestinationUrl)#</cfoutput>"
        aria-label="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaAriaLabel)#</cfoutput>"
        <cfif fpwActionCtaTrackingValid>
          data-fpw-action-cta
          data-fpw-track="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaAnalyticsEvent)#</cfoutput>"
          data-fpw-track-source-page="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaSourcePage)#</cfoutput>"
          data-fpw-track-section="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaSection)#</cfoutput>"
          data-fpw-track-cta-type="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaType)#</cfoutput>"
          data-fpw-track-label="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaButtonLabel)#</cfoutput>"
          data-fpw-track-auth-state="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaAuthState)#</cfoutput>"
          data-fpw-track-destination-key="<cfoutput>#encodeForHTMLAttribute(fpwActionCtaDestinationKey)#</cfoutput>"
        </cfif>>
        <span><cfoutput>#encodeForHTML(fpwActionCtaButtonLabel)#</cfoutput></span>
        <span class="fpw-cta-arrow" aria-hidden="true">&rarr;</span>
      </a>
    <cfelse>
      <p class="fpw-action-cta__unavailable" role="status"><cfoutput>#encodeForHTML(fpwActionCtaUnavailableMessage)#</cfoutput></p>
    </cfif>
  </div>
</section>
