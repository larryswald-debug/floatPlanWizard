<cfif NOT structKeyExists(variables, "bhPageReady")><cfheader statuscode="404"><cfabort></cfif>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<cfoutput>
<title>#encodeForHTML(bhTitle)# | FPW</title>
<meta name="description" content="#encodeForHTMLAttribute(bhDescription)#">
<meta name="robots" content="#bhPublished ? 'index,follow' : 'noindex,follow'#">
<link rel="canonical" href="#encodeForHTMLAttribute(bhCanonical)#">
<meta property="og:type" content="article">
<meta property="og:site_name" content="FloatPlanWizard">
<meta property="og:title" content="#encodeForHTMLAttribute(bhTitle)#">
<meta property="og:description" content="#encodeForHTMLAttribute(bhDescription)#">
<meta property="og:url" content="#encodeForHTMLAttribute(bhCanonical)#">
<link rel="icon" type="image/svg+xml" href="#bhBase#/assets/images/landing/fpw-logo.svg">
<link rel="stylesheet" href="#bhBase#/assets/css/layout.css?v=20260620-page-width">
<link rel="stylesheet" href="#bhBase#/assets/css/top-nav.css?v=20261028-approved-navigation">
<link rel="stylesheet" href="#bhBase#/assets/css/bahamas-guide.css?v=20261109-guide-focus">
<cfif NOT bhIsItinerary>
<link rel="stylesheet" href="#bhBase#/assets/css/shore-contact-overdue-guide.css?v=20260806-cta-color" media="screen">
<link rel="stylesheet" href="#bhBase#/assets/css/cruising-guides.css?v=20261114-three-guide-library" media="screen">
<link rel="stylesheet" href="#bhBase#/assets/css/bahamas-guide-dark.css?v=20261114-dark-guide" media="screen">
</cfif>
<script type="application/ld+json">#bhJsonLd#</script>
</cfoutput>
<cfinclude template="../../includes/analytics_ga4.cfm">
<cfinclude template="../../includes/analytics_clarity.cfm">
<cfinclude template="../../includes/trustedsite.cfm">
</head>
<body<cfif NOT bhIsItinerary> class="fpw-overdue-body bh-dark-guide"</cfif>>
<cfinclude template="../../includes/top_nav.cfm">
<main id="main-content" class="bh-page<cfif NOT bhIsItinerary> fpw-overdue-page</cfif>">
<div class="bh-shell<cfif NOT bhIsItinerary> fpw-overdue-content</cfif>">
<cfoutput>
<cfif NOT bhIsItinerary><div class="bh-guide-hero"><div class="bh-guide-hero-inner"></cfif>
<nav class="bh-breadcrumbs" aria-label="Breadcrumb">
<a href="#bhBase#/">FloatPlanWizard</a><span aria-hidden="true">/</span>
<a href="#bhBase#/boating-guides/">Cruising Guides</a><span aria-hidden="true">/</span>
<cfif bhIsItinerary><a href="#bhHub#">Bahamas</a><span aria-hidden="true">/</span><span aria-current="page">Fort Lauderdale to Bimini</span>
<cfelse><span aria-current="page">Bahamas</span></cfif>
</nav>
<header class="bh-hero">
<p class="bh-eyebrow">Cruising and trip planning · Bahamas</p>
<h1>#encodeForHTML(bhTitle)#</h1>
<p class="bh-lede">#encodeForHTML(bhDescription)#</p>
<p class="bh-meta">By FloatPlanWizard · Source review <time datetime="#encodeForHTMLAttribute(bhChecked)#">November 9, 2026</time>. Individual retrieval dates and verification limits appear beside the relevant facts.</p>
<cfif NOT bhPublished><p class="bh-status"><strong>Release preview.</strong> Personal-copy import is awaiting owner publication approval and production checks.</p></cfif>
</header>
<cfif NOT bhIsItinerary></div></div></cfif>
</cfoutput>




