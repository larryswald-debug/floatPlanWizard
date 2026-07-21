<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
reloadCompleted = structKeyExists(request, "fpwApplicationReloaded")
    AND request.fpwApplicationReloaded;
</cfscript>
<cfinclude template="../includes/fpw_base_path.cfm">
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Application Reload</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body{margin:24px;background:#f7f7f7;color:#111;font-family:Arial,sans-serif}
    .admin-wrap{max-width:1560px;margin:0 auto;padding:20px;border:1px solid #ddd;border-radius:8px;background:#fff}
    .reload-panel{max-width:760px}
    @media(max-width:640px){body{margin:10px}.admin-wrap{padding:12px}}
  </style>
</head>
<body>
  <div class="admin-wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">
    <div class="reload-panel">
      <h1 class="h3 mb-1">Application Reload</h1>
      <p class="text-muted">Reload application-scoped FPW settings after an approved deployment or configuration change.</p>

      <cfif reloadCompleted>
        <div class="alert alert-success" role="status">The FPW application was reloaded successfully.</div>
      </cfif>

      <div class="alert alert-warning">
        This operation immediately reruns FPW application initialization. Existing login sessions are not cleared.
      </div>

      <form method="post" action="?appreload=1">
        <cfoutput>
          <input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(toString(request.fpwAdminCsrfToken))#">
        </cfoutput>
        <button class="btn btn-danger" type="submit">Reload FPW Application</button>
      </form>
    </div>
  </div>
</body>
</html>
