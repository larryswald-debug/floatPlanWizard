<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Float Plan Wizard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="/fpw/includes/header_styles.cfm">
    <cfinclude template="/fpw/includes/floatplan-wizard-styles.cfm">
</head>
<body class="wizard-body">

<cfset wizardShellClasses = "wizard-shell wizard-shell-standalone">
<cfset wizardAutoInit = true>
<cfinclude template="/fpw/includes/floatplan-wizard-content.cfm">

<cfinclude template="/fpw/includes/footer_scripts.cfm">

<script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
<script src="/fpw/assets/js/app/validate.js"></script>
<script src="/fpw/assets/js/app/floatplanWizard.js"></script>

</body>
</html>
