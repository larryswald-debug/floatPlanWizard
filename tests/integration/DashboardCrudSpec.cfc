component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {};

    if ( structKeyExists( CGI, "SCRIPT_NAME" ) && findNoCase( "/testbox/", CGI.SCRIPT_NAME ) ) {
      variables.ctx.sessionReady = false;
      return;
    }

    var scheme = ( structKeyExists( CGI, "https" ) && CGI.https == "on" ) ? "https" : "http";
    var host   = CGI.server_name;
    var port   = CGI.server_port;
    var portPart = "";
    if ( !( scheme == "http" && port == 80 ) && !( scheme == "https" && port == 443 ) ) {
      portPart = ":" & port;
    }

    variables.ctx.baseUrl = scheme & "://" & host & portPart;

    variables.ctx.urls = {
      vesselSave    = variables.ctx.baseUrl & "/fpw/api/v1/vessel.cfc?method=handle",
      vesselDelete  = variables.ctx.baseUrl & "/fpw/api/v1/vessel.cfc?method=handle",
      vesselCanDel  = variables.ctx.baseUrl & "/fpw/api/v1/vessel.cfc?method=handle",
      vesselsList   = variables.ctx.baseUrl & "/fpw/api/v1/vessels.cfc?method=handle&limit=250",

      contactSave   = variables.ctx.baseUrl & "/fpw/api/v1/contact.cfc?method=handle",
      contactDelete = variables.ctx.baseUrl & "/fpw/api/v1/contact.cfc?method=handle",
      contactCanDel = variables.ctx.baseUrl & "/fpw/api/v1/contact.cfc?method=handle",
      contactsList  = variables.ctx.baseUrl & "/fpw/api/v1/contacts.cfc?method=handle&limit=250",

      passengerSave   = variables.ctx.baseUrl & "/fpw/api/v1/passenger.cfc?method=handle",
      passengerDelete = variables.ctx.baseUrl & "/fpw/api/v1/passenger.cfc?method=handle",
      passengerCanDel = variables.ctx.baseUrl & "/fpw/api/v1/passenger.cfc?method=handle",
      passengersList  = variables.ctx.baseUrl & "/fpw/api/v1/passengers.cfc?method=handle&limit=250",

      waypointSave   = variables.ctx.baseUrl & "/fpw/api/v1/waypoint.cfc?method=handle",
      waypointDelete = variables.ctx.baseUrl & "/fpw/api/v1/waypoint.cfc?method=handle",
      waypointCanDel = variables.ctx.baseUrl & "/fpw/api/v1/waypoint.cfc?method=handle",
      waypointsList  = variables.ctx.baseUrl & "/fpw/api/v1/waypoints.cfc?method=handle&limit=250",

      operatorSave   = variables.ctx.baseUrl & "/fpw/api/v1/operator.cfc?method=handle",
      operatorDelete = variables.ctx.baseUrl & "/fpw/api/v1/operator.cfc?method=handle",
      operatorCanDel = variables.ctx.baseUrl & "/fpw/api/v1/operator.cfc?method=handle",
      operatorsList  = variables.ctx.baseUrl & "/fpw/api/v1/operators.cfc?method=handle&limit=250",

      homeportGet  = variables.ctx.baseUrl & "/fpw/api/v1/homeport.cfc?method=handle",
      homeportSave = variables.ctx.baseUrl & "/fpw/api/v1/homeport.cfc?method=handle"
    };

    ensureSessionUser();
    variables.ctx.sessionReady = !structKeyExists( variables.ctx, "sessionError" );
  }

  function run() {

    describe( "Dashboard CRUD - Vessels", function() {

      it( "validates required vessel fields", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var res = apiPostJson( variables.ctx.urls.vesselSave, { action = "save", vessel = {} } );
        expect( isStruct( res ) ).toBeTrue();
        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( findNoCase( "Vessel name is required", toString( res.DETAIL ?: "" ) ) ).toBeGT( 0 );
      } );

      it( "creates, updates, lists, and deletes a vessel", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var suffix = uniqueSuffix();
        var payload = {
          action = "save",
          VESSEL = {
            VESSELNAME = "Test Vessel " & suffix,
            TYPE = "Sailboat",
            LENGTH = "30",
            COLOR = "White",
            REGISTRATION = "REG-" & suffix,
            MAKE = "Test",
            MODEL = "Model",
            HOMEPORT = "Boston"
          }
        };

        var createRes = apiPostJson( variables.ctx.urls.vesselSave, payload );
        expect( pickBool( createRes, "SUCCESS" ) ).toBeTrue( "Create failed: #serializeJSON(createRes)#" );
        var vesselId = val( createRes.VESSELID ?: 0 );
        expect( vesselId ).toBeGT( 0 );

        payload.VESSEL.VESSELID = vesselId;
        payload.VESSEL.VESSELNAME = payload.VESSEL.VESSELNAME & " Updated";
        var updateRes = apiPostJson( variables.ctx.urls.vesselSave, payload );
        expect( pickBool( updateRes, "SUCCESS" ) ).toBeTrue( "Update failed: #serializeJSON(updateRes)#" );

        var listRes = apiGetJson( variables.ctx.urls.vesselsList );
        expect( pickBool( listRes, "SUCCESS" ) ).toBeTrue( "List failed: #serializeJSON(listRes)#" );
        expect( findIdInList( listRes.VESSELS, "VESSELID", vesselId ) ).toBeTrue();

        var canDelRes = apiPostJson( variables.ctx.urls.vesselCanDel, { action = "candelete", vesselId = vesselId } );
        expect( pickBool( canDelRes, "SUCCESS" ) ).toBeTrue();
        expect( pickBool( canDelRes, "CANDELETE" ) ).toBeTrue();

        var deleteRes = apiPostJson( variables.ctx.urls.vesselDelete, { action = "delete", vesselId = vesselId } );
        expect( pickBool( deleteRes, "SUCCESS" ) ).toBeTrue( "Delete failed: #serializeJSON(deleteRes)#" );
      } );

    } );

    describe( "Dashboard CRUD - Contacts", function() {

      it( "validates required contact fields", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var res = apiPostJson( variables.ctx.urls.contactSave, { action = "save", contact = {} } );
        expect( isStruct( res ) ).toBeTrue();
        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( findNoCase( "Contact name is required", toString( res.DETAIL ?: "" ) ) ).toBeGT( 0 );
      } );

      it( "creates, updates, lists, and deletes a contact", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var suffix = uniqueSuffix();
        var payload = {
          action = "save",
          CONTACT = {
            CONTACTNAME = "Test Contact " & suffix,
            PHONE = "555-555-1212",
            EMAIL = "contact-" & suffix & "@example.com"
          }
        };

        var createRes = apiPostJson( variables.ctx.urls.contactSave, payload );
        expect( pickBool( createRes, "SUCCESS" ) ).toBeTrue( "Create failed: #serializeJSON(createRes)#" );
        var contactId = val( createRes.CONTACTID ?: 0 );
        expect( contactId ).toBeGT( 0 );

        payload.CONTACT.CONTACTID = contactId;
        payload.CONTACT.CONTACTNAME = payload.CONTACT.CONTACTNAME & " Updated";
        var updateRes = apiPostJson( variables.ctx.urls.contactSave, payload );
        expect( pickBool( updateRes, "SUCCESS" ) ).toBeTrue( "Update failed: #serializeJSON(updateRes)#" );

        var listRes = apiGetJson( variables.ctx.urls.contactsList );
        expect( pickBool( listRes, "SUCCESS" ) ).toBeTrue( "List failed: #serializeJSON(listRes)#" );
        expect( findIdInList( listRes.CONTACTS, "CONTACTID", contactId ) ).toBeTrue();

        var canDelRes = apiPostJson( variables.ctx.urls.contactCanDel, { action = "candelete", contactId = contactId } );
        expect( pickBool( canDelRes, "SUCCESS" ) ).toBeTrue();
        expect( pickBool( canDelRes, "CANDELETE" ) ).toBeTrue();

        var deleteRes = apiPostJson( variables.ctx.urls.contactDelete, { action = "delete", contactId = contactId } );
        expect( pickBool( deleteRes, "SUCCESS" ) ).toBeTrue( "Delete failed: #serializeJSON(deleteRes)#" );
      } );

    } );

    describe( "Dashboard CRUD - Passengers", function() {

      it( "validates required passenger fields", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var res = apiPostJson( variables.ctx.urls.passengerSave, { action = "save", passenger = {} } );
        expect( isStruct( res ) ).toBeTrue();
        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( findNoCase( "Name is required", toString( res.DETAIL ?: "" ) ) ).toBeGT( 0 );
      } );

      it( "creates, updates, lists, and deletes a passenger", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var suffix = uniqueSuffix();
        var payload = {
          action = "save",
          PASSENGER = {
            PASSENGERNAME = "Test Passenger " & suffix,
            PHONE = "555-555-1313",
            AGE = "42",
            GENDER = "Other",
            NOTES = "Test notes"
          }
        };

        var createRes = apiPostJson( variables.ctx.urls.passengerSave, payload );
        expect( pickBool( createRes, "SUCCESS" ) ).toBeTrue( "Create failed: #serializeJSON(createRes)#" );
        var passengerId = val( createRes.PASSENGERID ?: 0 );
        expect( passengerId ).toBeGT( 0 );

        payload.PASSENGER.PASSENGERID = passengerId;
        payload.PASSENGER.PASSENGERNAME = payload.PASSENGER.PASSENGERNAME & " Updated";
        var updateRes = apiPostJson( variables.ctx.urls.passengerSave, payload );
        expect( pickBool( updateRes, "SUCCESS" ) ).toBeTrue( "Update failed: #serializeJSON(updateRes)#" );

        var listRes = apiGetJson( variables.ctx.urls.passengersList );
        expect( pickBool( listRes, "SUCCESS" ) ).toBeTrue( "List failed: #serializeJSON(listRes)#" );
        expect( findIdInList( listRes.PASSENGERS, "PASSENGERID", passengerId ) ).toBeTrue();

        var canDelRes = apiPostJson( variables.ctx.urls.passengerCanDel, { action = "candelete", passengerId = passengerId } );
        expect( pickBool( canDelRes, "SUCCESS" ) ).toBeTrue();
        expect( pickBool( canDelRes, "CANDELETE" ) ).toBeTrue();

        var deleteRes = apiPostJson( variables.ctx.urls.passengerDelete, { action = "delete", passengerId = passengerId } );
        expect( pickBool( deleteRes, "SUCCESS" ) ).toBeTrue( "Delete failed: #serializeJSON(deleteRes)#" );
      } );

    } );

    describe( "Dashboard CRUD - Waypoints", function() {

      it( "validates required waypoint fields", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var res = apiPostJson( variables.ctx.urls.waypointSave, { action = "save", waypoint = {} } );
        expect( isStruct( res ) ).toBeTrue();
        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( findNoCase( "Name is required", toString( res.DETAIL ?: "" ) ) ).toBeGT( 0 );
      } );

      it( "creates, updates, lists, and deletes a waypoint", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var suffix = uniqueSuffix();
        var payload = {
          action = "save",
          WAYPOINT = {
            WAYPOINTNAME = "Test Waypoint " & suffix,
            LATITUDE = "42.3601",
            LONGITUDE = "-71.0589",
            NOTES = "Test waypoint notes"
          }
        };

        var createRes = apiPostJson( variables.ctx.urls.waypointSave, payload );
        expect( pickBool( createRes, "SUCCESS" ) ).toBeTrue( "Create failed: #serializeJSON(createRes)#" );
        var waypointId = val( createRes.WAYPOINTID ?: 0 );
        expect( waypointId ).toBeGT( 0 );

        payload.WAYPOINT.WAYPOINTID = waypointId;
        payload.WAYPOINT.WAYPOINTNAME = payload.WAYPOINT.WAYPOINTNAME & " Updated";
        var updateRes = apiPostJson( variables.ctx.urls.waypointSave, payload );
        expect( pickBool( updateRes, "SUCCESS" ) ).toBeTrue( "Update failed: #serializeJSON(updateRes)#" );

        var listRes = apiGetJson( variables.ctx.urls.waypointsList );
        expect( pickBool( listRes, "SUCCESS" ) ).toBeTrue( "List failed: #serializeJSON(listRes)#" );
        expect( findIdInList( listRes.WAYPOINTS, "WAYPOINTID", waypointId ) ).toBeTrue();

        var canDelRes = apiPostJson( variables.ctx.urls.waypointCanDel, { action = "candelete", waypointId = waypointId } );
        expect( pickBool( canDelRes, "SUCCESS" ) ).toBeTrue();
        expect( pickBool( canDelRes, "CANDELETE" ) ).toBeTrue();

        var deleteRes = apiPostJson( variables.ctx.urls.waypointDelete, { action = "delete", waypointId = waypointId } );
        expect( pickBool( deleteRes, "SUCCESS" ) ).toBeTrue( "Delete failed: #serializeJSON(deleteRes)#" );
      } );

    } );

    describe( "Dashboard CRUD - Operators", function() {

      it( "validates required operator fields", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var res = apiPostJson( variables.ctx.urls.operatorSave, { action = "save", operator = {} } );
        expect( isStruct( res ) ).toBeTrue();
        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( findNoCase( "Name is required", toString( res.DETAIL ?: "" ) ) ).toBeGT( 0 );
      } );

      it( "creates, updates, lists, and deletes an operator", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var suffix = uniqueSuffix();
        var payload = {
          action = "save",
          OPERATOR = {
            OPERATORNAME = "Test Operator " & suffix,
            PHONE = "555-555-1414",
            NOTES = "Test operator notes"
          }
        };

        var createRes = apiPostJson( variables.ctx.urls.operatorSave, payload );
        expect( pickBool( createRes, "SUCCESS" ) ).toBeTrue( "Create failed: #serializeJSON(createRes)#" );
        var operatorId = val( createRes.OPERATORID ?: 0 );
        expect( operatorId ).toBeGT( 0 );

        payload.OPERATOR.OPERATORID = operatorId;
        payload.OPERATOR.OPERATORNAME = payload.OPERATOR.OPERATORNAME & " Updated";
        var updateRes = apiPostJson( variables.ctx.urls.operatorSave, payload );
        expect( pickBool( updateRes, "SUCCESS" ) ).toBeTrue( "Update failed: #serializeJSON(updateRes)#" );

        var listRes = apiGetJson( variables.ctx.urls.operatorsList );
        expect( pickBool( listRes, "SUCCESS" ) ).toBeTrue( "List failed: #serializeJSON(listRes)#" );
        expect( findIdInList( listRes.OPERATORS, "OPERATORID", operatorId ) ).toBeTrue();

        var canDelRes = apiPostJson( variables.ctx.urls.operatorCanDel, { action = "candelete", operatorId = operatorId } );
        expect( pickBool( canDelRes, "SUCCESS" ) ).toBeTrue();
        expect( pickBool( canDelRes, "CANDELETE" ) ).toBeTrue();

        var deleteRes = apiPostJson( variables.ctx.urls.operatorDelete, { action = "delete", operatorId = operatorId } );
        expect( pickBool( deleteRes, "SUCCESS" ) ).toBeTrue( "Delete failed: #serializeJSON(deleteRes)#" );
      } );

    } );

    describe( "Dashboard CRUD - Home Port", function() {

      it( "validates required home port fields", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var res = apiPostJson( variables.ctx.urls.homeportSave, { action = "save" } );
        expect( isStruct( res ) ).toBeTrue();
        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( res.ERROR ?: "" ).toBe( "MISSING_FIELDS" );
      } );

      it( "saves and restores home port details", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var getRes = apiGetJson( variables.ctx.urls.homeportGet );
        expect( pickBool( getRes, "SUCCESS" ) ).toBeTrue( "Get failed: #serializeJSON(getRes)#" );

        var current = structKeyExists( getRes, "HOMEPORT" ) && isStruct( getRes.HOMEPORT ) ? getRes.HOMEPORT : {};

        var suffix = uniqueSuffix();
        var updated = {
          address = "Test Dock " & suffix,
          city = "Testville",
          state = "MA",
          zip = "02110",
          phone = "555-555-1515",
          lat = "42.3601",
          lng = "-71.0589"
        };

        updated.action = "save";
        var saveRes = apiPostJson( variables.ctx.urls.homeportSave, updated );
        expect( pickBool( saveRes, "SUCCESS" ) ).toBeTrue( "Save failed: #serializeJSON(saveRes)#" );

        if ( structKeyExists( current, "RECID" ) && len( toString( current.RECID ) ) ) {
          var restorePayload = {
            action = "save",
            address = toString( current.ADDRESS ?: "" ),
            city = toString( current.CITY ?: "" ),
            state = toString( current.STATE ?: "" ),
            zip = toString( current.ZIP ?: "" ),
            phone = toString( current.PHONE ?: "" ),
            lat = toString( current.LAT ?: "" ),
            lng = toString( current.LNG ?: "" )
          };

          var hasRestoreValues = len( restorePayload.address ) || len( restorePayload.city ) || len( restorePayload.state ) || len( restorePayload.zip );
          if ( !hasRestoreValues ) {
            skip( "Existing home port is empty; skipping restore to avoid invalid save." );
          }

          var restoreRes = apiPostJson( variables.ctx.urls.homeportSave, restorePayload );
          expect( pickBool( restoreRes, "SUCCESS" ) ).toBeTrue( "Restore failed: #serializeJSON(restoreRes)#" );
        }
      } );

    } );

  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      var forceTestUser = true;
      if ( structKeyExists( url, "useTestUser" ) ) {
        forceTestUser = ( toString( url.useTestUser ) != "0" );
      }
      if ( forceTestUser ) {
        try {
          var testUserId = structKeyExists( url, "testUserId" ) && isNumeric( url.testUserId )
            ? val( url.testUserId )
            : ensureTestUserId();
          session.user.userId = testUserId;
          session.user.id = testUserId;
          session.user.USERID = testUserId;
        } catch ( any e ) {
          variables.ctx.testUserError = e.message;
        }
      }
      if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) ) {
        var fallbackId = structKeyExists( url, "testUserId" ) ? url.testUserId : 1;
        session.user.userId = val( fallbackId );
        session.user.id = session.user.userId;
        session.user.USERID = session.user.userId;
      }
    } catch ( any e ) {
      variables.ctx.sessionError = e.message;
    }
  }

  private numeric function ensureTestUserId() {
    var ds = "fpw";
    var dbQ = queryExecute( "SELECT DATABASE() AS dbName", {}, { datasource = ds } );
    var dbName = dbQ.dbName[ 1 ];
    var cols = queryExecute("
      SELECT COLUMN_NAME, IS_NULLABLE, COLUMN_DEFAULT, DATA_TYPE, COLUMN_TYPE, EXTRA
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = :schema
        AND TABLE_NAME = 'users'
      ORDER BY ORDINAL_POSITION
    ", { schema = { value = dbName, cfsqltype = "cf_sql_varchar" } }, { datasource = ds } );

    var idCol = "";
    var emailCol = "";
    for ( var row in cols ) {
      if ( !len( idCol ) && findNoCase( "auto_increment", row.EXTRA ) ) {
        idCol = row.COLUMN_NAME;
      }
      if ( !len( emailCol ) && findNoCase( "email", row.COLUMN_NAME ) ) {
        emailCol = row.COLUMN_NAME;
      }
    }
    if ( !len( idCol ) ) {
      idCol = "userId";
    }

    var testEmail = "testbox-dashboard-crud@example.com";
    if ( len( emailCol ) ) {
      var existing = queryExecute(
        "SELECT #idCol# AS id FROM users WHERE #emailCol# = :email LIMIT 1",
        { email = { value = testEmail, cfsqltype = "cf_sql_varchar" } },
        { datasource = ds }
      );
      if ( existing.recordCount ) {
        return val( existing.id[ 1 ] );
      }
    }

    var insertCols = [];
    var insertVals = [];
    var params = {};
    var suffix = uniqueSuffix();

    for ( var c in cols ) {
      var col = c.COLUMN_NAME;
      if ( findNoCase( "auto_increment", c.EXTRA ) ) {
        continue;
      }
      var isRequired = ( c.IS_NULLABLE == "NO" && isNull( c.COLUMN_DEFAULT ) );
      if ( !isRequired ) {
        continue;
      }
      var paramName = "p_" & reReplace( col, "[^A-Za-z0-9_]", "_", "all" );
      var value = buildColumnValue( c, col, suffix, testEmail );
      insertCols.append( col );
      insertVals.append( ":" & paramName );
      params[ paramName ] = {
        value = value,
        cfsqltype = sqlTypeFor( c.DATA_TYPE )
      };
    }

    if ( len( emailCol ) && !arrayContainsNoCase( insertCols, emailCol ) ) {
      var emailParam = "p_" & reReplace( emailCol, "[^A-Za-z0-9_]", "_", "all" );
      insertCols.append( emailCol );
      insertVals.append( ":" & emailParam );
      params[ emailParam ] = { value = testEmail, cfsqltype = "cf_sql_varchar" };
    }

    if ( !arrayLen( insertCols ) ) {
      return 1;
    }

    queryExecute(
      "INSERT INTO users (" & arrayToList( insertCols, "," ) & ") VALUES (" & arrayToList( insertVals, "," ) & ")",
      params,
      { datasource = ds }
    );
    var newIdQ = queryExecute( "SELECT LAST_INSERT_ID() AS newId", {}, { datasource = ds } );
    return val( newIdQ.newId[ 1 ] );
  }

  private any function buildColumnValue( required struct column, required string colName, required string suffix, required string testEmail ) {
    var dataType = lcase( column.DATA_TYPE ?: "" );
    var colLower = lcase( colName );
    if ( findNoCase( "email", colLower ) ) {
      return testEmail;
    }
    if ( dataType == "enum" ) {
      return firstEnumValue( column.COLUMN_TYPE );
    }
    if ( listFindNoCase( "date,datetime,timestamp", dataType ) ) {
      return now();
    }
    if ( dataType == "time" ) {
      return "00:00:00";
    }
    if ( listFindNoCase( "int,integer,smallint,mediumint,tinyint,bigint,decimal,numeric,float,double,bit,boolean", dataType ) ) {
      return 0;
    }
    return "test-" & suffix & "-" & colName;
  }

  private string function firstEnumValue( required string columnType ) {
    var matches = reMatch( "enum\\('([^']+)'", columnType );
    if ( arrayLen( matches ) ) {
      return replace( matches[ 1 ], "enum('", "", "one" );
    }
    return "";
  }

  private string function sqlTypeFor( required string dataType ) {
    var dt = lcase( dataType );
    if ( listFindNoCase( "int,integer,smallint,mediumint,tinyint", dt ) ) return "cf_sql_integer";
    if ( dt == "bigint" ) return "cf_sql_bigint";
    if ( listFindNoCase( "decimal,numeric", dt ) ) return "cf_sql_decimal";
    if ( listFindNoCase( "float,double", dt ) ) return "cf_sql_double";
    if ( listFindNoCase( "bit,boolean", dt ) ) return "cf_sql_bit";
    if ( dt == "date" ) return "cf_sql_date";
    if ( listFindNoCase( "datetime,timestamp", dt ) ) return "cf_sql_timestamp";
    return "cf_sql_varchar";
  }

  private boolean function arrayContainsNoCase( required array list, required string value ) {
    for ( var item in arguments.list ) {
      if ( lcase( toString( item ) ) == lcase( arguments.value ) ) {
        return true;
      }
    }
    return false;
  }

  private array function getSessionCookies() {
    var cookiePairs = [];
    var cookieNames = [ "CFID", "CFTOKEN", "JSESSIONID" ];
    for ( var name in cookieNames ) {
      if ( structKeyExists( cookie, name ) ) {
        arrayAppend( cookiePairs, { name = name, value = cookie[ name ] } );
      }
    }
    return cookiePairs;
  }

  private struct function apiPostJson( required string url, required struct body ) {
    var sessionCookies = getSessionCookies();
    var res = {};
    cfhttp( method="POST", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      cfhttpparam( type="header", name="Content-Type", value="application/json; charset=utf-8" );
      cfhttpparam( type="body", value=serializeJSON( arguments.body ) );
      for ( var cookiePair in sessionCookies ) {
        cfhttpparam( type="cookie", name=cookiePair.name, value=cookiePair.value );
      }
    }
    return decodeJsonResponse( res );
  }

  private struct function apiGetJson( required string url ) {
    var sessionCookies = getSessionCookies();
    var res = {};
    cfhttp( method="GET", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      for ( var cookiePair in sessionCookies ) {
        cfhttpparam( type="cookie", name=cookiePair.name, value=cookiePair.value );
      }
    }
    return decodeJsonResponse( res );
  }

  private struct function decodeJsonResponse( required struct httpRes ) {
    var raw = "";
    if ( structKeyExists( arguments.httpRes, "fileContent" ) ) raw = arguments.httpRes.fileContent;
    else if ( structKeyExists( arguments.httpRes, "responseHeader" ) ) raw = toString( arguments.httpRes.responseHeader );
    try {
      var parsed = deserializeJSON( raw );
      if ( isStruct( parsed ) ) return parsed;
      return { success=false, message="JSON was not a struct", raw=raw, parsed=parsed };
    } catch ( any e ) {
      return { success=false, message="Response was not JSON", raw=raw, error=e.message };
    }
  }

  private boolean function pickBool( required struct payload, required string key ) {
    return structKeyExists( arguments.payload, arguments.key ) ? !!arguments.payload[ arguments.key ] : false;
  }

  private boolean function findIdInList( required any items, required string idKey, required numeric idValue ) {
    if ( !isArray( arguments.items ) ) return false;
    for ( var item in arguments.items ) {
      if ( isStruct( item ) && structKeyExists( item, arguments.idKey ) ) {
        if ( val( item[ arguments.idKey ] ) == arguments.idValue ) {
          return true;
        }
      }
    }
    return false;
  }

  private string function uniqueSuffix() {
    return dateTimeFormat( now(), "yyyymmddHHnnss" ) & "-" & right( createUUID(), 6 );
  }

}
