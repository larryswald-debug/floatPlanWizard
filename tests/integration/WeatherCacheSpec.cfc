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

      it( "returns forecast cache hit on second request for same lat/lng", function() {
        clearUnifiedWeatherCacheStore();
        var weatherCache = newWeatherCacheService();
        var fetchCalls = 0;
        var fetcher = function( required numeric lat, required numeric lng ) {
          fetchCalls = fetchCalls + 1;
          return {
            "success" = true,
            "source" = "NWS",
            "step" = "forecast",
            "points_url" = "https://api.weather.gov/points/" & lat & "," & lng,
            "forecast_url" = "https://example.test/forecast",
            "grid_url" = "",
            "points_status" = 200,
            "forecast_status" = 200,
            "grid_status" = 0,
            "points_body" = "{}",
            "forecast_body" = "{""properties"":{""periods"":[]}}",
            "grid_body" = ""
          };
        };

        var firstRes = weatherCache.getNwsForecastCached( 27.98144, -82.73144, 900, false, fetcher );
        var secondRes = weatherCache.getNwsForecastCached( 27.98144, -82.73144, 900, false, fetcher );

        expect( fetchCalls ).toBe( 1 );
        expect( structKeyExists( firstRes, "cache_meta" ) ).toBeTrue( "First forecast result missing cache_meta: #serializeJSON(firstRes)#" );
        expect( structKeyExists( secondRes, "cache_meta" ) ).toBeTrue( "Second forecast result missing cache_meta: #serializeJSON(secondRes)#" );
        expect( !!secondRes.cache_meta.hit ).toBeTrue( "Second forecast call should be cache hit: #serializeJSON(secondRes)#" );
      } );

      it( "bypassCache skips forecast cache and marks bypass in metadata", function() {
        clearUnifiedWeatherCacheStore();
        var weatherCache = newWeatherCacheService();
        var fetchCalls = 0;
        var fetcher = function( required numeric lat, required numeric lng ) {
          fetchCalls = fetchCalls + 1;
          return {
            "success" = true,
            "source" = "NWS",
            "step" = "forecast",
            "points_url" = "https://api.weather.gov/points/" & lat & "," & lng,
            "forecast_url" = "https://example.test/forecast",
            "grid_url" = "",
            "points_status" = 200,
            "forecast_status" = 200,
            "grid_status" = 0,
            "points_body" = "{}",
            "forecast_body" = "{""properties"":{""periods"":[]}}",
            "grid_body" = ""
          };
        };

        weatherCache.getNwsForecastCached( 27.98144, -82.73144, 900, false, fetcher );
        var bypassRes = weatherCache.getNwsForecastCached( 27.98144, -82.73144, 900, true, fetcher );

        expect( fetchCalls ).toBe( 2 );
        expect( structKeyExists( bypassRes, "cache_meta" ) ).toBeTrue( "Bypass result missing cache_meta: #serializeJSON(bypassRes)#" );
        expect( !!bypassRes.cache_meta.hit ).toBeFalse( "Bypass call should not be cache hit: #serializeJSON(bypassRes)#" );
        expect( structKeyExists( bypassRes.cache_meta, "bypass" ) && !!bypassRes.cache_meta.bypass ).toBeTrue( "Bypass call should flag cache_meta.bypass=true: #serializeJSON(bypassRes)#" );
      } );

      it( "normalizes forecast cache key by rounding lat/lng to three decimals", function() {
        clearUnifiedWeatherCacheStore();
        var weatherCache = newWeatherCacheService();
        var fetchCalls = 0;
        var fetcher = function( required numeric lat, required numeric lng ) {
          fetchCalls = fetchCalls + 1;
          return {
            "success" = true,
            "source" = "NWS",
            "step" = "forecast",
            "points_url" = "https://api.weather.gov/points/" & lat & "," & lng,
            "forecast_url" = "https://example.test/forecast",
            "grid_url" = "",
            "points_status" = 200,
            "forecast_status" = 200,
            "grid_status" = 0,
            "points_body" = "{}",
            "forecast_body" = "{""properties"":{""periods"":[]}}",
            "grid_body" = ""
          };
        };

        var firstRes = weatherCache.getNwsForecastCached( 27.98144, -82.73144, 900, false, fetcher );
        var secondRes = weatherCache.getNwsForecastCached( 27.98149, -82.73149, 900, false, fetcher );

        expect( fetchCalls ).toBe( 1 );
        expect( structKeyExists( firstRes, "cache_meta" ) ).toBeTrue( "First normalization result missing cache_meta: #serializeJSON(firstRes)#" );
        expect( structKeyExists( secondRes, "cache_meta" ) ).toBeTrue( "Second normalization result missing cache_meta: #serializeJSON(secondRes)#" );
        expect( !!secondRes.cache_meta.hit ).toBeTrue( "Expected key normalization cache hit on second call: #serializeJSON(secondRes)#" );
        expect( toString( firstRes.cache_meta.key ) ).toBe( toString( secondRes.cache_meta.key ) );
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

  private any function newWeatherCacheService() {
    var userAgent = "FPW Test WeatherCacheSpec";
    try {
      return createObject( "component", "fpw.api.services.weatherCache" ).init(
        userAgent = userAgent,
        httpTimeout = 2
      );
    } catch ( any ePrimaryPath ) {
      return createObject( "component", "api.services.weatherCache" ).init(
        userAgent = userAgent,
        httpTimeout = 2
      );
    }
  }

  private void function clearUnifiedWeatherCacheStore() {
    application.weatherCacheUnified = {};
  }

}
