<!--- /fpw/dev/weather_debug.cfm  (DROP-IN)
      Purpose: Render HTML debug output for weather API without JSON headers.
      Usage:
        /fpw/dev/weather_debug.cfm?floatPlanId=123
        /fpw/dev/weather_debug.cfm?floatPlanId=123&call=internal   (optional)
--->

<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<!--- Basic inputs --->
<cfparam name="url.floatPlanId" default="">
<cfparam name="url.call" default="remote"><!--- remote | internal --->

<cfset  floatPlanId = int(val(url.floatPlanId))>
<cfset  mode = lcase(trim(url.call))>

<html>
<head>
    <meta charset="utf-8">
    <title>FPW Weather Debug</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body{ font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; padding:16px; background:#0b1220; color:rgba(4, 0, 87, 0.92); }
        .panel{ background:rgba(255,255,255,.06); border:1px solid rgba(255,255,255,.12); border-radius:12px; padding:14px; margin:12px 0; }
        .muted{ color:rgba(255,255,255,.70); }
        .row{ display:flex; gap:12px; flex-wrap:wrap; }
        .row > * { flex: 1 1 280px; }
        code, pre{ background:rgba(0,0,0,.25); padding:10px; border-radius:10px; overflow:auto; }
        a{ color:#2dd4bf; text-decoration:none; }
        a:hover{ text-decoration:underline; }
        .bad{ color:#ffb4b4; }
        .good{ color:#a7f3d0; }
        input, button, select{
            background:rgba(255,255,255,.08);
            color:rgba(255,255,255,.92);
            border:1px solid rgba(255,255,255,.18);
            border-radius:10px;
            padding:10px 12px;
            font-size:14px;
        }
        button{ cursor:pointer; }
        .small{ font-size:13px; }
    </style>
</head>
<body>

<cfoutput>
    <h1 style="margin:0 0 6px 0;">FPW Weather Debug</h1>
    <div class="muted">HTML debug harness for <code>/fpw/api/v1/weather.cfc</code></div>

    <div class="panel">
        <form method="get" action="weather_debug.cfm" class="row" style="align-items:end;">
            <div>
                <div class="small muted" style="margin-bottom:6px;">FloatPlanId</div>
                <input type="text" name="floatPlanId" value="#encodeForHTMLAttribute(url.floatPlanId)#" placeholder="123" />
            </div>
            <div>
                <div class="small muted" style="margin-bottom:6px;">Call Mode</div>
                <select name="call">
                    <option value="remote" <cfif mode EQ "remote">selected</cfif>>Remote (HTTP to weather.cfc)</option>
                    <option value="internal" <cfif mode EQ "internal">selected</cfif>>Internal (createObject + call handle)</option>
                </select>
            </div>
            <div style="flex:0 0 auto;">
                <button type="submit">Run</button>
            </div>
        </form>

        <div class="muted small" style="margin-top:10px;">
            Tip: Remote mode is closest to real usage. Internal mode helps prove routing/compilation issues.
        </div>
    </div>

    <cfif floatPlanId LTE 0>
        <div class="panel bad">
            Enter a valid <b>floatPlanId</b> and click Run.
        </div>
    <cfelse>

        <cfset  apiUrl = "http://localhost:8500/fpw/api/v1/weather.cfc?method=handle&action=get&floatPlanId=" & floatPlanId & "&returnformat=json">
        <cfset  raw = "">
        <cfset  parsed = "">
        <cfset  isJson = false>
        <cfset  httpStatus = "">
        <cfset  httpHeaders = {}>

        <cfif mode EQ "remote">
            <!--- Remote call via cfhttp --->
            <cftry>
                <cfhttp url="#apiUrl#" method="get" result="h" timeout="20">
                    <cfhttpparam type="header" name="Accept" value="application/json">
                </cfhttp>
                <cfset raw = h.fileContent>
                <cfset httpStatus = h.statusCode>
                <cfif structKeyExists(h, "responseHeader") AND isStruct(h.responseHeader)>
                    <cfset httpHeaders = h.responseHeader>
                </cfif>
                <cfcatch>
                    <div class="panel bad">
                        <h3 style="margin-top:0;">cfhttp error</h3>
                        <cfdump var="#cfcatch#">
                    </div>
                </cfcatch>
            </cftry>

        <cfelse>
            <!--- Internal call (best-effort):
                  Many remote handlers write directly to output, so we capture it. --->
            <cfset  buffer = "">
            <cftry>
                <cfsavecontent variable="buffer">
                    <!--- Create component and invoke handle() --->
                    <cfset  w = createObject("component", "fpw.api.v1.weather")>
                    <cfset w.handle(action="get", floatPlanId=floatPlanId)>
                </cfsavecontent>
                <cfset raw = buffer>
                <cfset httpStatus = "INTERNAL">
                <cfcatch>
                    <div class="panel bad">
                        <h3 style="margin-top:0;">Internal call error</h3>
                        <cfdump var="#cfcatch#">
                    </div>
                </cfcatch>
            </cftry>
        </cfif>

        <!--- Try JSON parse --->
        <cftry>
            <cfset parsed = deserializeJSON(raw)>
            <cfset isJson = true>
            <cfcatch>
                <cfset isJson = false>
            </cfcatch>
        </cftry>

        <div class="panel">
            <div class="row">
                <div>
                    <div class="small muted">Mode</div>
                    <div><b>#mode#</b></div>
                </div>
                <div>
                    <div class="small muted">FloatPlanId</div>
                    <div><b>#floatPlanId#</b></div>
                </div>
                <div>
                    <div class="small muted">Status</div>
                    <div><b>#encodeForHTML(httpStatus)#</b></div>
                </div>
                <div>
                    <div class="small muted">Parsed JSON</div>
                    <div>
                        <cfif isJson>
                            <span class="good"><b>YES</b></span>
                        <cfelse>
                            <span class="bad"><b>NO</b></span>
                        </cfif>
                    </div>
                </div>
            </div>

            <div class="muted small" style="margin-top:10px;">
                API URL: <a href="#apiUrl#">#encodeForHTML(apiUrl)#</a>
            </div>
        </div>

        <cfif mode EQ "remote" AND isStruct(httpHeaders) AND structCount(httpHeaders)>
            <div class="panel">
                <h3 style="margin-top:0;">Response Headers</h3>
                <cfdump var ="#httpHeaders#">
            </div>
        </cfif>

        <div class="panel">
            <h3 style="margin-top:0;">Raw Response</h3>
            <pre>#encodeForHTML(raw)#</pre>
        </div>

        <cfif isJson>
            <div class="panel">
                <h3 style="margin-top:0;">Parsed JSON</h3>
                <cfdump var="#parsed#" label="deserializeJSON(raw)">
            </div>

            <cfif isStruct(parsed) AND structKeyExists(parsed, "SUCCESS")>
                <div class="panel">
                    <h3 style="margin-top:0;">Quick Signals</h3>
                    <ul>
                        <li>SUCCESS: <b>#parsed.SUCCESS#</b></li>
                        <cfif structKeyExists(parsed, "MESSAGE")>
                            <li>MESSAGE: <b>#encodeForHTML(parsed.MESSAGE)#</b></li>
                        </cfif>
                        <cfif structKeyExists(parsed, "DATA") AND isStruct(parsed.DATA)>
                            <li>FORECAST items: <b>#(structKeyExists(parsed.DATA,"FORECAST") AND isArray(parsed.DATA.FORECAST) ? arrayLen(parsed.DATA.FORECAST) : 0)#</b></li>
                            <li>ALERTS items: <b>#(structKeyExists(parsed.DATA,"ALERTS") AND isArray(parsed.DATA.ALERTS) ? arrayLen(parsed.DATA.ALERTS) : 0)#</b></li>
                            <li>MAP_LAYERS items: <b>#(structKeyExists(parsed.DATA,"MAP_LAYERS") AND isArray(parsed.DATA.MAP_LAYERS) ? arrayLen(parsed.DATA.MAP_LAYERS) : 0)#</b></li>
                            <cfif structKeyExists(parsed.DATA,"SUMMARY")>
                                <li>SUMMARY: <b>#encodeForHTML(parsed.DATA.SUMMARY)#</b></li>
                            </cfif>
                        </cfif>
                    </ul>
                </div>
            </cfif>
        <cfelse>
            <div class="panel bad">
                <h3 style="margin-top:0;">Not JSON</h3>
                <div class="muted small">
                    If you see HTML here, your API is dumping error pages (good clue). If you see CFML tags,
                    the response is being served as text/plain somewhere.
                </div>
            </div>
        </cfif>

    </cfif>
</cfoutput>

</body>
</html>
