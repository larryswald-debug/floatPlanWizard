component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {};

    if ( structKeyExists( CGI, "SCRIPT_NAME" ) && findNoCase( "/testbox/", CGI.SCRIPT_NAME ) ) {
      variables.ctx.sessionReady = false;
      return;
    }

    var scheme = ( structKeyExists( CGI, "https" ) && CGI.https == "on" ) ? "https" : "http";
    var host = CGI.server_name;
    var port = CGI.server_port;
    var portPart = "";
    if ( !( scheme == "http" && port == 80 ) && !( scheme == "https" && port == 443 ) ) {
      portPart = ":" & port;
    }

    variables.ctx.baseUrl = scheme & "://" & host & portPart;
    variables.ctx.weatherZipUrl = variables.ctx.baseUrl
      & "/fpw/api/v1/weather.cfc?method=handle&action=zip&zip=02110&returnformat=json&marineMode=quick&marineOnly=1";
    variables.ctx.forceUserId = structKeyExists( url, "testUserId" ) && isNumeric( url.testUserId )
      ? val( url.testUserId )
      : 187;

    ensureSessionUser();
    variables.ctx.sessionReady = !structKeyExists( variables.ctx, "sessionError" );
  }

  function run() {
    describe( "Weather cache behavior", function() {

      it( "caches geocode zip key and preserves it on second request", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var geocodeKey = "wx_geocode_zip:02110";
        var hadPrevious = marineCacheEntryExists( geocodeKey );
        var previousEntry = hadPrevious ? duplicate( application.marineCache[ geocodeKey ] ) : {};

        try {
          ensureMarineCache();
          removeMarineCacheKey( geocodeKey );

          var firstRes = weatherZipGet();
          expect( isStruct( firstRes ) ).toBeTrue( "First weather call did not return struct: #serializeJSON(firstRes)#" );
          expect( structKeyExists( firstRes, "SUCCESS" ) ).toBeTrue( "First weather response missing SUCCESS: #serializeJSON(firstRes)#" );
          expect( structKeyExists( firstRes, "DATA" ) ).toBeTrue( "First weather response missing DATA: #serializeJSON(firstRes)#" );
          expect( marineCacheEntryExists( geocodeKey ) ).toBeTrue( "Expected geocode cache key after first call: #geocodeKey#" );

          var secondRes = weatherZipGet();
          expect( isStruct( secondRes ) ).toBeTrue( "Second weather call did not return struct: #serializeJSON(secondRes)#" );
          expect( structKeyExists( secondRes, "SUCCESS" ) ).toBeTrue( "Second weather response missing SUCCESS: #serializeJSON(secondRes)#" );
          expect( structKeyExists( secondRes, "DATA" ) ).toBeTrue( "Second weather response missing DATA: #serializeJSON(secondRes)#" );
          expect( marineCacheEntryExists( geocodeKey ) ).toBeTrue( "Expected geocode cache key after second call: #geocodeKey#" );
        } finally {
          if ( hadPrevious ) {
            application.marineCache[ geocodeKey ] = previousEntry;
          } else {
            removeMarineCacheKey( geocodeKey );
          }
        }
      } );

      it( "creates ndbc 404 negative-cache key when invalid buoy is forced", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var forcedBuoyId = "WXNEG" & left( reReplace( createUUID(), "[^A-Za-z0-9]", "", "all" ), 6 );
        var expectedNegKey = "ndbc_wave_404:" & uCase( forcedBuoyId );
        var stationsKey = "ndbc_stations";
        var hadStations = marineCacheEntryExists( stationsKey );
        var previousStationsEntry = hadStations ? duplicate( application.marineCache[ stationsKey ] ) : {};
        var beforeNegKeys = getMarineCacheKeysByPrefix( "ndbc_wave_404:" );
        var createdNegKeys = [];

        try {
          ensureMarineCache();

          application.marineCache[ stationsKey ] = {
            "ts" = now(),
            "val" = [
              {
                "id" = forcedBuoyId,
                "name" = "Forced Invalid Buoy",
                "lat" = "42.3576",
                "lon" = "-71.0514"
              }
            ]
          };

          var firstRes = weatherZipGet();
          expect( isStruct( firstRes ) ).toBeTrue( "First weather call did not return struct: #serializeJSON(firstRes)#" );
          expect( structKeyExists( firstRes, "SUCCESS" ) ).toBeTrue( "First weather response missing SUCCESS: #serializeJSON(firstRes)#" );
          expect( structKeyExists( firstRes, "DATA" ) ).toBeTrue( "First weather response missing DATA: #serializeJSON(firstRes)#" );

          var afterFirstNegKeys = getMarineCacheKeysByPrefix( "ndbc_wave_404:" );
          createdNegKeys = arrayDiffNoCase( afterFirstNegKeys, beforeNegKeys );
          if ( arrayFindNoCase( createdNegKeys, expectedNegKey ) EQ 0
            && arrayFindNoCase( beforeNegKeys, expectedNegKey ) EQ 0
            && marineCacheEntryExists( expectedNegKey ) ) {
            arrayAppend( createdNegKeys, expectedNegKey );
          }
          expect( marineCacheEntryExists( expectedNegKey ) ).toBeTrue( "Expected forced negative cache key after first call: #expectedNegKey#" );
          expect( arrayLen( createdNegKeys ) ).toBeGTE( 1, "Expected new ndbc_wave_404:* key after forced invalid buoy." );

          var secondRes = weatherZipGet();
          expect( isStruct( secondRes ) ).toBeTrue( "Second weather call did not return struct: #serializeJSON(secondRes)#" );
          expect( structKeyExists( secondRes, "SUCCESS" ) ).toBeTrue( "Second weather response missing SUCCESS: #serializeJSON(secondRes)#" );
          expect( structKeyExists( secondRes, "DATA" ) ).toBeTrue( "Second weather response missing DATA: #serializeJSON(secondRes)#" );

          for ( var negKey in createdNegKeys ) {
            expect( marineCacheEntryExists( negKey ) ).toBeTrue( "Expected negative cache key to remain present: #negKey#" );
          }
        } finally {
          if ( hadStations ) {
            application.marineCache[ stationsKey ] = previousStationsEntry;
          } else {
            removeMarineCacheKey( stationsKey );
          }

          for ( var createdKey in createdNegKeys ) {
            if ( arrayFindNoCase( beforeNegKeys, createdKey ) EQ 0 ) {
              removeMarineCacheKey( createdKey );
            }
          }
        }
      } );

    } );
  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) || val( session.user.userId ) LTE 0 ) {
        session.user.userId = variables.ctx.forceUserId;
        session.user.id = session.user.userId;
        session.user.USERID = session.user.userId;
      }
    } catch ( any e ) {
      variables.ctx.sessionError = e.message;
    }
  }

  private struct function weatherZipGet() {
    return apiGetJson( variables.ctx.weatherZipUrl );
  }

  private array function getSessionCookies() {
    var cookiePairs = [];
    var cookieNames = [ "CFID", "CFTOKEN", "JSESSIONID" ];
    var runtimeCfid = "";
    var runtimeCftoken = "";
    try { runtimeCfid = trim( toString( CFID ) ); } catch ( any _cfidErr ) {}
    try { runtimeCftoken = trim( toString( CFTOKEN ) ); } catch ( any _cftErr ) {}

    for ( var name in cookieNames ) {
      var cookieVal = "";
      if ( structKeyExists( cookie, name ) ) {
        cookieVal = trim( toString( cookie[ name ] ) );
      } else if ( name EQ "CFID" && len( runtimeCfid ) ) {
        cookieVal = runtimeCfid;
      } else if ( name EQ "CFTOKEN" && len( runtimeCftoken ) ) {
        cookieVal = runtimeCftoken;
      } else if ( name EQ "JSESSIONID" && structKeyExists( session, "sessionid" ) ) {
        cookieVal = trim( toString( session.sessionid ) );
      }
      if ( len( cookieVal ) ) {
        arrayAppend( cookiePairs, { name = name, value = cookieVal } );
      }
    }

    return cookiePairs;
  }

  private struct function apiGetJson( required string url ) {
    var sessionCookies = getSessionCookies();
    var testHeaderUserId = resolveTestHeaderUserId();
    var res = {};

    cfhttp( method="GET", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      if ( testHeaderUserId GT 0 ) {
        cfhttpparam( type="header", name="X-FPW-Test-UserId", value=toString( testHeaderUserId ) );
      }
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
      return { success = false, message = "JSON was not a struct", raw = raw, parsed = parsed };
    } catch ( any e ) {
      return { success = false, message = "Response was not JSON", raw = raw, error = e.message };
    }
  }

  private numeric function resolveTestHeaderUserId() {
    var userId = 0;
    if ( structKeyExists( session, "user" ) && isStruct( session.user ) && structKeyExists( session.user, "userId" ) && isNumeric( session.user.userId ) ) {
      userId = val( session.user.userId );
    }
    if ( userId LTE 0 && structKeyExists( variables, "ctx" ) && structKeyExists( variables.ctx, "forceUserId" ) && isNumeric( variables.ctx.forceUserId ) ) {
      userId = val( variables.ctx.forceUserId );
    }
    return ( userId GT 0 ? userId : 0 );
  }

  private void function ensureMarineCache() {
    if ( !structKeyExists( application, "marineCache" ) || !isStruct( application.marineCache ) ) {
      application.marineCache = {};
    }
  }

  private boolean function marineCacheEntryExists( required string key ) {
    ensureMarineCache();
    return structKeyExists( application.marineCache, arguments.key );
  }

  private void function removeMarineCacheKey( required string key ) {
    ensureMarineCache();
    if ( structKeyExists( application.marineCache, arguments.key ) ) {
      structDelete( application.marineCache, arguments.key, false );
    }
  }

  private array function getMarineCacheKeysByPrefix( required string prefix ) {
    ensureMarineCache();
    var keys = structKeyArray( application.marineCache );
    var matches = [];
    for ( var key in keys ) {
      if ( left( key, len( arguments.prefix ) ) EQ arguments.prefix ) {
        arrayAppend( matches, key );
      }
    }
    return matches;
  }

  private array function arrayDiffNoCase( required array source, required array excluded ) {
    var out = [];
    for ( var item in arguments.source ) {
      if ( arrayFindNoCase( arguments.excluded, item ) EQ 0 ) {
        arrayAppend( out, item );
      }
    }
    return out;
  }

}
