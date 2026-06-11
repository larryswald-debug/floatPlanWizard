component output="false" {

  variables.api = "";
  variables.pdfDir = "";

  public any function init(any apiSupport="", string pdfDir="") output="false" {
    if (structKeyExists(arguments, "apiSupport")) {
      variables.api = arguments.apiSupport;
    }
    variables.pdfDir = len(arguments.pdfDir) ? arguments.pdfDir : expandPath("/fpw/floatPlans/user_float_plans");
    return this;
  }

  public void function cleanupFloatPlan(required numeric floatPlanId) output="false" {
    var bootstrap = variables.api.postJson("/api/v1/floatplan.cfc?method=handle", {
      action = "bootstrap",
      floatPlanId = arguments.floatPlanId
    });
    var plan = structKeyExists(bootstrap, "FLOATPLAN") ? bootstrap.FLOATPLAN : {};
    var status = structKeyExists(plan, "STATUS") ? uCase(trim(toString(plan.STATUS))) : "";
    var routeInstanceId = structKeyExists(plan, "ROUTE_INSTANCE_ID") && isNumeric(plan.ROUTE_INSTANCE_ID) ? val(plan.ROUTE_INSTANCE_ID) : 0;
    var routeCode = routeInstanceId GT 0 ? loadRouteCodeForRouteInstance(routeInstanceId) : "";
    if (status EQ "ACTIVE") {
      if (routeInstanceId GT 0) {
        requireSuccess(variables.api.postJson("/api/v1/floatplan.cfc?method=handle", {
          action = "cancel",
          floatPlanId = arguments.floatPlanId
        }), "cancel float plan before delete");
      } else {
        queryExecute(
          "UPDATE floatplans
           SET `status` = 'CLOSED',
               checkedInAt = UTC_TIMESTAMP(),
               checkin_context = NULL,
               closedAt = UTC_TIMESTAMP(),
               lastUpdateStatus = UTC_TIMESTAMP()
           WHERE floatplanId = :floatPlanId",
          {
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
      }
    }
    if (len(routeCode)) {
      requireSuccess(variables.api.postJson("/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute", {
        routeCode = routeCode
      }), "delete route for route-linked float plan");
      return;
    }
    requireSuccess(variables.api.postJson("/api/v1/floatplan.cfc?method=handle", {
      action = "delete",
      floatPlanId = arguments.floatPlanId
    }), "delete float plan");
  }

  public void function cleanupRoute(required string routeCode) output="false" {
    requireSuccess(variables.api.postJson("/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute", {
      routeCode = arguments.routeCode
    }), "delete route");
  }

  public void function cleanupCurrentRouteFloatPlanGroup(numeric userId=0) output="false" {
    var effectiveUserId = resolveCleanupUserId(arguments.userId);
    var attempts = 0;
    var qCurrent = queryNew("");
    var routeCodes = [];
    var row = 0;
    var floatPlanId = 0;
    var statusValue = "";
    var routeCode = "";
    var cancelPayload = {};
    var deletePayload = {};
    var deleteError = "";
    var deleteMessage = "";
    var authContext = {};

    if (effectiveUserId LTE 0) {
      return;
    }

    authContext = applyCleanupSessionUser(effectiveUserId);
    try {
      while (attempts LT 5) {
        attempts++;
        qCurrent = loadCurrentRouteFloatPlanGroups(effectiveUserId);
        if (qCurrent.recordCount EQ 0) {
          return;
        }

        routeCodes = [];
        for (row = 1; row LTE qCurrent.recordCount; row++) {
          floatPlanId = val(qCurrent.floatplanId[row]);
          statusValue = trim(toString(qCurrent.statusValue[row]));
          routeCode = trim(toString(qCurrent.routeCode[row]));

          if (statusValue EQ "ACTIVE" AND floatPlanId GT 0) {
            cancelPayload = variables.api.postJson("/api/v1/floatplan.cfc?method=handle", {
              action = "cancel",
              floatPlanId = floatPlanId
            });
            if (!structKeyExists(cancelPayload, "SUCCESS") OR cancelPayload.SUCCESS NEQ true) {
              if (trim(toString(cancelPayload.ERROR ?: "")) NEQ "NO_ACTIVE_GROUP") {
                throw(message = "Cleanup failed: cancel current active route-linked float plan", detail = serializeJSON(cancelPayload));
              }
            }
          }

          if (len(routeCode) AND arrayFindNoCase(routeCodes, routeCode) EQ 0) {
            arrayAppend(routeCodes, routeCode);
          }
        }

        for (routeCode in routeCodes) {
          deletePayload = variables.api.postJson("/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute", {
            routeCode = routeCode
          });
          if (!structKeyExists(deletePayload, "SUCCESS") OR deletePayload.SUCCESS NEQ true) {
            deleteError = "";
            deleteMessage = "";
            if (isStruct(deletePayload.ERROR ?: "")) {
              deleteError = trim(toString(deletePayload.ERROR.CODE ?: ""));
              deleteMessage = trim(toString(deletePayload.ERROR.MESSAGE ?: ""));
            } else {
              deleteError = trim(toString(deletePayload.ERROR ?: ""));
              deleteMessage = trim(toString(deletePayload.MESSAGE ?: ""));
            }
            if (
              deleteError NEQ "NOT_FOUND"
              AND !findNoCase("Route not found", deleteMessage)
              AND !findNoCase("Route is not available for this user.", deleteMessage)
            ) {
              throw(message = "Cleanup failed: delete current route/float-plan group route", detail = serializeJSON(deletePayload));
            }
          }
        }
      }

      qCurrent = loadCurrentRouteFloatPlanGroups(effectiveUserId);
      if (qCurrent.recordCount GT 0) {
        throw(message = "Cleanup failed: current route/float-plan group still exists.", detail = "Remaining row count: " & qCurrent.recordCount);
      }
    } finally {
      restoreCleanupSessionUser(authContext);
    }
  }

  public void function cleanupUserRoute(required numeric routeId) output="false" {
    requireSuccess(variables.api.postJson("/api/v1/routeBuilder.cfc?method=handle&action=deleteUserRoute", {
      route_id = arguments.routeId
    }), "delete user route");
  }

  public void function cleanupVessel(required numeric vesselId) output="false" {
    requireSuccess(variables.api.postJson("/api/v1/vessel.cfc?method=handle", {
      action = "delete",
      vesselId = arguments.vesselId
    }), "delete vessel");
  }

  public void function cleanupOperator(required numeric operatorId) output="false" {
    requireSuccess(variables.api.postJson("/api/v1/operator.cfc?method=handle", {
      action = "delete",
      operatorId = arguments.operatorId
    }), "delete operator");
  }

  public void function cleanupPassenger(required numeric passengerId) output="false" {
    requireSuccess(variables.api.postJson("/api/v1/passenger.cfc?method=handle", {
      action = "delete",
      passengerId = arguments.passengerId
    }), "delete passenger");
  }

  public void function cleanupContact(required numeric contactId) output="false" {
    requireSuccess(variables.api.postJson("/api/v1/contact.cfc?method=handle", {
      action = "delete",
      contactId = arguments.contactId
    }), "delete contact");
  }

  public void function cleanupWaypoint(required numeric waypointId) output="false" {
    requireSuccess(variables.api.postJson("/api/v1/waypoint.cfc?method=handle", {
      action = "delete",
      waypointId = arguments.waypointId
    }), "delete waypoint");
  }

  public void function cleanupPdfPrefix(required string prefix) output="false" {
    var files = [];
    var i = 0;
    var filePath = "";
    if (!directoryExists(variables.pdfDir)) {
      return;
    }
    files = directoryList(variables.pdfDir, false, "path", arguments.prefix & "*.pdf");
    for (i = 1; i LTE arrayLen(files); i++) {
      filePath = files[i];
      if (fileExists(filePath)) {
        fileDelete(filePath);
      }
    }
  }

  private void function requireSuccess(required struct payload, required string actionLabel) output="false" {
    if (!structKeyExists(arguments.payload, "SUCCESS") OR arguments.payload.SUCCESS NEQ true) {
      throw(message = "Cleanup failed: " & arguments.actionLabel, detail = serializeJSON(arguments.payload));
    }
  }

  private numeric function resolveCleanupUserId(numeric preferredUserId=0) output="false" {
    if (arguments.preferredUserId GT 0) {
      return arguments.preferredUserId;
    }
    if (structKeyExists(url, "testUserId") AND isNumeric(url.testUserId) AND val(url.testUserId) GT 0) {
      return val(url.testUserId);
    }
    if (structKeyExists(session, "user") AND isStruct(session.user)) {
      if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId) AND val(session.user.userId) GT 0) {
        return val(session.user.userId);
      }
      if (structKeyExists(session.user, "id") AND isNumeric(session.user.id) AND val(session.user.id) GT 0) {
        return val(session.user.id);
      }
      if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID) AND val(session.user.USERID) GT 0) {
        return val(session.user.USERID);
      }
    }
    return 0;
  }

  private struct function applyCleanupSessionUser(required numeric userId) output="false" {
    var context = {
      hadUrlUser = structKeyExists(url, "testUserId"),
      priorUrlUser = structKeyExists(url, "testUserId") ? url.testUserId : "",
      hadSessionUser = structKeyExists(session, "user"),
      priorSessionUser = (structKeyExists(session, "user") AND isStruct(session.user)) ? duplicate(session.user) : {}
    };
    url.testUserId = arguments.userId;
    if (!structKeyExists(session, "user") OR !isStruct(session.user)) {
      session.user = {};
    }
    session.user.userId = arguments.userId;
    session.user.id = arguments.userId;
    session.user.USERID = arguments.userId;
    return context;
  }

  private void function restoreCleanupSessionUser(required struct context) output="false" {
    if (arguments.context.hadUrlUser) {
      url.testUserId = arguments.context.priorUrlUser;
    } else {
      structDelete(url, "testUserId", false);
    }
    if (arguments.context.hadSessionUser) {
      session.user = arguments.context.priorSessionUser;
    } else {
      structDelete(session, "user", false);
    }
  }

  private query function loadCurrentRouteFloatPlanGroups(required numeric userId) output="false" {
    return queryExecute(
      "SELECT fp.floatplanId,
              UPPER(TRIM(fp.`status`)) AS statusValue,
              COALESCE(ri.generated_route_code, '') AS routeCode
         FROM floatplans fp
         LEFT JOIN route_instances ri ON ri.id = fp.route_instance_id
        WHERE fp.userId = :userId
          AND fp.route_instance_id IS NOT NULL
          AND (
            (
              UPPER(TRIM(fp.`status`)) = 'DRAFT'
              AND fp.activatedAt IS NULL
              AND fp.initialSentAt IS NULL
              AND fp.checkedInAt IS NULL
              AND fp.closedAt IS NULL
            )
            OR UPPER(TRIM(fp.`status`)) = 'ACTIVE'
          )
        ORDER BY fp.floatplanId DESC",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private string function loadRouteCodeForRouteInstance(required numeric routeInstanceId) output="false" {
    var qRoute = queryExecute(
      "SELECT generated_route_code
       FROM route_instances
       WHERE id = :routeInstanceId
       LIMIT 1",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    if (qRoute.recordCount EQ 0) {
      return "";
    }
    return trim(toString(qRoute.generated_route_code[1]));
  }
}
