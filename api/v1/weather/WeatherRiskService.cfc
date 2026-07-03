<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfreturn this>
  </cffunction>

  <cffunction name="scoreConditions" access="public" returntype="struct" output="false">
    <cfargument name="currentInput" type="any" required="true">
    <cfargument name="marineInput" type="any" required="true">
    <cfargument name="alertsInput" type="any" required="true">

    <cfset var score = 0>
    <cfset var reasons = arrayNew(1)>
    <cfset var wind = "">
    <cfset var gust = "">
    <cfset var seas = "">
    <cfset var visibility = "">
    <cfset var alertScore = 0>
    <cfset var level = "Good">
    <cfset var recommendation = "Conditions look favorable, but review the hourly table before departure.">
    <cfset var result = structNew()>

    <cfif isStruct(arguments.currentInput)>
      <cfif structKeyExists(arguments.currentInput, "windMph") AND isNumeric(arguments.currentInput.windMph)>
        <cfset wind = val(arguments.currentInput.windMph)>
      </cfif>
      <cfif structKeyExists(arguments.currentInput, "gustMph") AND isNumeric(arguments.currentInput.gustMph)>
        <cfset gust = val(arguments.currentInput.gustMph)>
      </cfif>
      <cfif structKeyExists(arguments.currentInput, "visibilityMi") AND isNumeric(arguments.currentInput.visibilityMi)>
        <cfset visibility = val(arguments.currentInput.visibilityMi)>
      </cfif>
    </cfif>

    <cfif isStruct(arguments.marineInput)>
      <cfif structKeyExists(arguments.marineInput, "seasFt") AND isNumeric(arguments.marineInput.seasFt)>
        <cfset seas = val(arguments.marineInput.seasFt)>
      <cfelseif structKeyExists(arguments.marineInput, "waveHeightFt") AND isNumeric(arguments.marineInput.waveHeightFt)>
        <cfset seas = val(arguments.marineInput.waveHeightFt)>
      </cfif>
    </cfif>

    <cfif isNumeric(wind)>
      <cfif wind GTE 25>
        <cfset score = score + 40>
      <cfelseif wind GTE 15>
        <cfset score = score + 20>
      </cfif>
    </cfif>

    <cfif isNumeric(gust)>
      <cfif gust GTE 35>
        <cfset score = score + 35>
      <cfelseif gust GTE 22>
        <cfset score = score + 18>
      </cfif>
    </cfif>

    <cfif isNumeric(seas)>
      <cfif seas GTE 6>
        <cfset score = score + 35>
      <cfelseif seas GTE 3>
        <cfset score = score + 18>
      </cfif>
    </cfif>

    <cfif isNumeric(visibility) AND visibility LT 3>
      <cfset score = score + 15>
    </cfif>

    <cfif isArray(arguments.alertsInput) AND arrayLen(arguments.alertsInput) GT 0>
      <cfset alertScore = arrayLen(arguments.alertsInput) * 10>
      <cfif alertScore GT 35>
        <cfset alertScore = 35>
      </cfif>
      <cfset score = score + alertScore>
    </cfif>

    <cfif score GT 100>
      <cfset score = 100>
    </cfif>

    <cfif score GTE 65>
      <cfset level = "High">
      <cfset recommendation = "Conditions may be hazardous. Review official NOAA alerts and delay departure if needed.">
    <cfelseif score GTE 25>
      <cfset level = "Caution">
      <cfset recommendation = "Conditions are manageable near shore but may be uncomfortable for smaller boats or exposed water.">
    </cfif>

    <cfset result.riskLevel = level>
    <cfset result.riskScore = score>
    <cfset result.recommendation = recommendation>
    <cfset result.reasons = reasons>
    <cfreturn result>
  </cffunction>

  <cffunction name="riskForForecastPeriod" access="public" returntype="string" output="false">
    <cfargument name="periodInput" type="any" required="true">
    <cfargument name="marineInput" type="any" required="false" default="">

    <cfset var wind = 0>
    <cfset var gust = 0>
    <cfset var mph = 0>

    <cfif isStruct(arguments.periodInput)>
      <cfif structKeyExists(arguments.periodInput, "windMph") AND isNumeric(arguments.periodInput.windMph)>
        <cfset wind = val(arguments.periodInput.windMph)>
      </cfif>
      <cfif structKeyExists(arguments.periodInput, "gustMph") AND isNumeric(arguments.periodInput.gustMph)>
        <cfset gust = val(arguments.periodInput.gustMph)>
      </cfif>
    </cfif>

    <cfset mph = gust GT 0 ? gust : wind>

    <cfif mph GTE 20>
      <cfreturn "Extreme">
    <cfelseif mph GTE 15>
      <cfreturn "High">
    <cfelseif mph GTE 10>
      <cfreturn "Caution">
    </cfif>

    <cfreturn "Good">
  </cffunction>

</cfcomponent>



