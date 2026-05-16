<cfdump var ="#application.dsn#">

<cfquery name="dsnTest" datasource="#application.dsn#" result="dsnTestResult">
    SELECT 1 AS testValue
</cfquery>
<cfdump var="#dsnTestResult#">
