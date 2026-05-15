component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
  }

  function beforeEach() {
    variables.originalEnvExists = structKeyExists(application, "env");
    variables.originalEnv = variables.originalEnvExists ? application.env : "";
    variables.originalMonitorTokenExists = structKeyExists(application, "monitorToken");
    variables.originalMonitorToken = variables.originalMonitorTokenExists ? application.monitorToken : "";
    variables.originalDebugRequestTraceExists = structKeyExists(application, "debugRequestTrace");
    variables.originalDebugRequestTrace = variables.originalDebugRequestTraceExists ? application.debugRequestTrace : false;
  }

  function afterEach() {
    if (variables.originalEnvExists) {
      application.env = variables.originalEnv;
    } else {
      structDelete(application, "env", false);
    }

    if (variables.originalMonitorTokenExists) {
      application.monitorToken = variables.originalMonitorToken;
    } else {
      structDelete(application, "monitorToken", false);
    }

    if (variables.originalDebugRequestTraceExists) {
      application.debugRequestTrace = variables.originalDebugRequestTrace;
    } else {
      structDelete(application, "debugRequestTrace", false);
    }
  }

  function run() {
    describe("Production hardening gates", function() {
      it("ignores X-FPW-Test-UserId in production mode", function() {
        setProductionMode("");

        var result = getJsonWithTestHeader("/api/v1/me.cfc?method=handle", 187);

        expect(result.payload.AUTH).toBeFalse(serializeJSON(result.payload));
        expect(result.payload.SUCCESS).toBeFalse(serializeJSON(result.payload));
      });

      it("still honors X-FPW-Test-UserId in explicit dev mode", function() {
        setDevMode("phase4a-dev-token");

        var result = getJsonWithTestHeader("/api/v1/me.cfc?method=handle", 187);

        expect(result.payload.AUTH).toBeTrue(serializeJSON(result.payload));
        expect(resolveUserId(result.payload.USER)).toBe(187);
      });

      it("blocks public debug and test pages in production mode", function() {
        setProductionMode("");

        var apiDump = getPlain("/api/test.cfm");
        var testingPage = getPlain("/api/v1/testing.cfm");
        var testingComponent = getPlain("/api/v1/testing.cfc?method=testCreateFullPlan&token=phase4a");
        var weatherDebug = getPlain("/dev/weather_debug.cfm?floatPlanId=1");

        expect(left(apiDump.statusCode, 3)).toBe("404");
        expect(left(testingPage.statusCode, 3)).toBe("404");
        expect(left(testingComponent.statusCode, 3)).toBe("404");
        expect(left(weatherDebug.statusCode, 3)).toBe("404");
      });

      it("blocks weather token user bypass in production mode", function() {
        setProductionMode("phase4a-monitor-token");

        var result = getJson("/api/v1/weather.cfc?method=handle&action=get&token=phase4a-monitor-token&asUserId=187");

        expect(result.payload.AUTH).toBeFalse(serializeJSON(result.payload));
        expect(result.payload.SUCCESS).toBeFalse(serializeJSON(result.payload));
      });

      it("fails monitoring evaluator closed when production monitor token is missing", function() {
        setProductionMode("");

        var result = getJson("/api/v1/monitor.cfc?method=runMonitoringEvaluator&token=phase4a-monitor-token");

        expect(result.payload.SUCCESS).toBeFalse(serializeJSON(result.payload));
        expect(result.payload.ERROR).toBe("UNAUTHORIZED");
      });
    });
  }

  private void function setProductionMode(string monitorToken="") {
    application.env = "prod";
    application.monitorToken = arguments.monitorToken;
    application.debugRequestTrace = false;
  }

  private void function setDevMode(string monitorToken="") {
    application.env = "dev";
    application.monitorToken = arguments.monitorToken;
    application.debugRequestTrace = false;
  }

  private struct function getPlain(required string path) {
    var httpResult = {};
    cfhttp(url = variables.baseUrl & arguments.path, method = "get", result = "httpResult", charset = "utf-8", timeout = 20);
    return {
      statusCode = structKeyExists(httpResult, "statusCode") ? toString(httpResult.statusCode) : "",
      body = structKeyExists(httpResult, "fileContent") ? trim(toString(httpResult.fileContent)) : ""
    };
  }

  private struct function getJson(required string path) {
    var plain = getPlain(arguments.path);
    plain.payload = deserializeJSON(plain.body);
    return plain;
  }

  private struct function getJsonWithTestHeader(required string path, required numeric userId) {
    var httpResult = {};
    cfhttp(url = variables.baseUrl & arguments.path, method = "get", result = "httpResult", charset = "utf-8", timeout = 20) {
      cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = toString(arguments.userId));
    }
    return {
      statusCode = structKeyExists(httpResult, "statusCode") ? toString(httpResult.statusCode) : "",
      body = structKeyExists(httpResult, "fileContent") ? trim(toString(httpResult.fileContent)) : "",
      payload = deserializeJSON(trim(toString(httpResult.fileContent)))
    };
  }

  private numeric function resolveUserId(required struct userPayload) {
    if (structKeyExists(arguments.userPayload, "userId") && isNumeric(arguments.userPayload.userId)) {
      return val(arguments.userPayload.userId);
    }
    if (structKeyExists(arguments.userPayload, "USERID") && isNumeric(arguments.userPayload.USERID)) {
      return val(arguments.userPayload.USERID);
    }
    if (structKeyExists(arguments.userPayload, "id") && isNumeric(arguments.userPayload.id)) {
      return val(arguments.userPayload.id);
    }
    return 0;
  }
}
