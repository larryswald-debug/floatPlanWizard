<cfscript>
setting showdebugoutput=false;
cfcontent(type="application/json; charset=utf-8");

if (!structKeyExists(session, "user") || !isStruct(session.user)) {
  session.user = {};
}
session.user.userId = 187;
session.user.id = 187;
session.user.USERID = 187;

rb = createObject("component", "api.v1.routeBuilder");

function callHandle(required string action, struct scopedParams = {}) {
  var raw = "";
  var parsed = {};
  var argBag = { action = arguments.action };
  var k = "";

  for (k in arguments.scopedParams) {
    url[k] = arguments.scopedParams[k];
    argBag[k] = arguments.scopedParams[k];
  }

  savecontent variable="raw" {
    rb.handle(argumentCollection = argBag);
  }

  for (k in arguments.scopedParams) {
    structDelete(url, k, false);
  }

  try {
    parsed = deserializeJSON(raw);
  } catch (any e) {
    parsed = { "SUCCESS" = false, "MESSAGE" = "Response parse failure", "ERROR" = { "MESSAGE" = e.message }, "RAW" = raw };
  }

  return { "RAW" = raw, "JSON" = parsed };
}

resTemplates = callHandle("listRouteTemplates");
resPreview = callHandle("getRouteTemplatePreview", { "routeCode" = "GL_REUSE_V1", "direction" = "CCW" });
resDetours = callHandle("getRouteTemplateDetours", { "routeCode" = "GULF-WEST" });

templatesCount = 0;
previewSegmentsCount = 0;
detoursCount = 0;
if (structKeyExists(resTemplates.JSON, "DATA") && isStruct(resTemplates.JSON.DATA) && structKeyExists(resTemplates.JSON.DATA, "ROUTES") && isArray(resTemplates.JSON.DATA.ROUTES)) {
  templatesCount = arrayLen(resTemplates.JSON.DATA.ROUTES);
}
if (structKeyExists(resPreview.JSON, "DATA") && isStruct(resPreview.JSON.DATA) && structKeyExists(resPreview.JSON.DATA, "SEGMENTS") && isArray(resPreview.JSON.DATA.SEGMENTS)) {
  previewSegmentsCount = arrayLen(resPreview.JSON.DATA.SEGMENTS);
}
if (structKeyExists(resDetours.JSON, "DATA") && isStruct(resDetours.JSON.DATA) && structKeyExists(resDetours.JSON.DATA, "DETOURS") && isArray(resDetours.JSON.DATA.DETOURS)) {
  detoursCount = arrayLen(resDetours.JSON.DATA.DETOURS);
}

writeOutput(serializeJSON({
  "SMOKE" = {
    "listRouteTemplates" = {
      "SUCCESS" = (structKeyExists(resTemplates.JSON, "SUCCESS") ? resTemplates.JSON.SUCCESS : false),
      "COUNT" = templatesCount
    },
    "getRouteTemplatePreview" = {
      "SUCCESS" = (structKeyExists(resPreview.JSON, "SUCCESS") ? resPreview.JSON.SUCCESS : false),
      "COUNT" = previewSegmentsCount
    },
    "getRouteTemplateDetours" = {
      "SUCCESS" = (structKeyExists(resDetours.JSON, "SUCCESS") ? resDetours.JSON.SUCCESS : false),
      "COUNT" = detoursCount
    }
  },
  "EXAMPLES" = {
    "TEMPLATES" = resTemplates.JSON,
    "PREVIEW" = resPreview.JSON,
    "DETOURS" = resDetours.JSON
  }
}));
</cfscript>
