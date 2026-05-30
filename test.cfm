
        <cfset mailAttrs = {
            to = 'lswald@yahoo.com',
            from = 'noreply@floatplanwizard.com',
            subject = 'Test Email from Float Plan Wizard',
            charset = "utf-8",
            replyToEmail = 'info@floatplanwizard.com'
        }>

   
<cfmail to="lswald@yahoo.com" 
        from="noreply@floatplanwizard.com" 
        subject="Test Email from Float Plan Wizard">
    Email body goes here.
</cfmail>
<cfdump var="#mailAttrs#" label="Mail Attributes">
<p>

        successfully sent test email. Check your inbox.