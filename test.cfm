
        <cfset mailAttrs = {
            to = 'lswald@yahoo.com',
            from = 'noreply@floatplanwizard.com',
            subject = 'Test Email from Float Plan Wizard',
            charset = "utf-8",
            replyToEmail = 'info@floatplanwizard.com'
        }>

   

        <cfmail attributeCollection="#mailAttrs#">
            test email body`
        </cfmail>


        successfully sent test email. Check your inbox.