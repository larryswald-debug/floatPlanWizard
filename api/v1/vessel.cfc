<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Require authenticated session -->
            <cfif NOT structKeyExists(session, "user") OR NOT isStruct(session.user)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "NOT_LOGGED_IN",
                    MESSAGE = "Not logged in."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Resolve userId from session -->
            <cfset userId = 0>
            <cfif structKeyExists(session.user, "userId")>
                <cfset userId = session.user.userId>
            <cfelseif structKeyExists(session.user, "id")>
                <cfset userId = session.user.id>
            <cfelseif structKeyExists(session.user, "USERID")>
                <cfset userId = session.user.USERID>
            </cfif>

            <cfif NOT isNumeric(userId) OR userId LTE 0>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "INVALID_SESSION",
                    MESSAGE = "Session user is invalid."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Optional JSON body -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cftry>
                    <cfset body = deserializeJSON(rawBody, false)>
                <cfcatch>
                    <cfset body = {}>
                </cfcatch>
                </cftry>
            </cfif>

            <cfset action = "">
            <cfif structKeyExists(url, "action")>
                <cfset action = lcase(trim(url.action))>
            <cfelseif structKeyExists(body, "action")>
                <cfset action = lcase(trim(body.action))>
            </cfif>

	            <cfif action EQ "save">
	                <cfset memberGateResult = getMemberAccessGateService().requirePlanningAccess(userId)>
	                <cfif NOT memberGateResult.allowed>
	                    <cfoutput>#serializeJSON(memberGateResult.response)#</cfoutput>
	                    <cfsetting enablecfoutputonly="false">
	                    <cfabort>
	                </cfif>

	                <cfset vessel = {}>
                <cfif structKeyExists(body, "vessel")>
                    <cfset vessel = body.vessel>
                <cfelseif structKeyExists(body, "VESSEL")>
                    <cfset vessel = body.VESSEL>
                </cfif>

                <cfset vesselId = 0>
                <cfif structKeyExists(vessel, "VESSELID")>
                    <cfset vesselId = val(vessel.VESSELID)>
                <cfelseif structKeyExists(vessel, "vesselId")>
                    <cfset vesselId = val(vessel.vesselId)>
                </cfif>

                <cfset vesselName = structKeyExists(vessel, "VESSELNAME") ? trim(vessel.VESSELNAME) : (structKeyExists(vessel, "vesselName") ? trim(vessel.vesselName) : "")>
                <cfif NOT len(vesselName)>
                    <cfthrow message="Vessel name is required.">
                </cfif>

                <cfset registration = structKeyExists(vessel, "REGISTRATION") ? trim(vessel.REGISTRATION) : (structKeyExists(vessel, "registration") ? trim(vessel.registration) : "")>
                <cfset vesselType  = structKeyExists(vessel, "TYPE") ? trim(vessel.TYPE) : (structKeyExists(vessel, "type") ? trim(vessel.type) : "")>
                <cfset make        = structKeyExists(vessel, "MAKE") ? trim(vessel.MAKE) : (structKeyExists(vessel, "make") ? trim(vessel.make) : "")>
                <cfset model       = structKeyExists(vessel, "MODEL") ? trim(vessel.MODEL) : (structKeyExists(vessel, "model") ? trim(vessel.model) : "")>
                <cfset length      = structKeyExists(vessel, "LENGTH") ? trim(vessel.LENGTH) : (structKeyExists(vessel, "length") ? trim(vessel.length) : "")>
                <cfset color       = structKeyExists(vessel, "COLOR") ? trim(vessel.COLOR) : (structKeyExists(vessel, "color") ? trim(vessel.color) : "")>
                <cfset homePort    = structKeyExists(vessel, "HOMEPORT") ? trim(vessel.HOMEPORT) : (structKeyExists(vessel, "homePort") ? trim(vessel.homePort) : "")>
                <cfset maxSpeedRaw = structKeyExists(vessel, "MAX_SPEED") ? trim(vessel.MAX_SPEED) : (structKeyExists(vessel, "max_speed") ? trim(vessel.max_speed) : (structKeyExists(vessel, "maxSpeed") ? trim(vessel.maxSpeed) : ""))>
                <cfset mostEfficientSpeedRaw = structKeyExists(vessel, "MOST_EFFICIENT_SPEED") ? trim(vessel.MOST_EFFICIENT_SPEED) : (structKeyExists(vessel, "most_efficient_speed") ? trim(vessel.most_efficient_speed) : (structKeyExists(vessel, "mostEfficientSpeed") ? trim(vessel.mostEfficientSpeed) : ""))>
                <cfset gallonsPerHourRaw = structKeyExists(vessel, "GALLONS_PER_HOUR") ? trim(vessel.GALLONS_PER_HOUR) : (structKeyExists(vessel, "gallons_per_hour") ? trim(vessel.gallons_per_hour) : (structKeyExists(vessel, "gallonsPerHour") ? trim(vessel.gallonsPerHour) : ""))>
                <cfset gphAtMaxSpeedRaw = structKeyExists(vessel, "GPH_AT_MAX_SPEED") ? trim(vessel.GPH_AT_MAX_SPEED) : (structKeyExists(vessel, "gph_at_max_speed") ? trim(vessel.gph_at_max_speed) : (structKeyExists(vessel, "gphAtMaxSpeed") ? trim(vessel.gphAtMaxSpeed) : ""))>
                <cfset fuelCapacityRaw = structKeyExists(vessel, "FUEL_CAPACITY") ? trim(vessel.FUEL_CAPACITY) : (structKeyExists(vessel, "fuel_capacity") ? trim(vessel.fuel_capacity) : (structKeyExists(vessel, "fuelCapacity") ? trim(vessel.fuelCapacity) : ""))>
                <cfset hasHin = hasPayloadKey(vessel, ["HIN", "hin"])>
                <cfset hasYearBuilt = hasPayloadKey(vessel, ["YEARBUILT", "yearBuilt"])>
                <cfset hasDraft = hasPayloadKey(vessel, ["DRAFT", "draft"])>
                <cfset hasHullMaterial = hasPayloadKey(vessel, ["HULLMATERIAL", "hullMaterial"])>
                <cfset hasProminentFeatures = hasPayloadKey(vessel, ["PROMINENTFEATURES", "prominentFeatures"])>
                <cfset hasCallSignNumber = hasPayloadKey(vessel, ["CALLSIGNNUMBER", "callSignNumber"])>
                <cfset hasDscMmsi = hasPayloadKey(vessel, ["DSCMMSI", "dscMmsi"])>
                <cfset hasRadio1Type = hasPayloadKey(vessel, ["RADIO_1_TYPE", "radio_1_type"])>
                <cfset hasRadio1Channel = hasPayloadKey(vessel, ["RADIO_1_CHANNEL", "radio_1_channel"])>
                <cfset hasRadio2Type = hasPayloadKey(vessel, ["RADIO_2_TYPE", "radio_2_type"])>
                <cfset hasRadio2Channel = hasPayloadKey(vessel, ["RADIO_2_CHANNEL", "radio_2_channel"])>
                <cfset hasMobilePhone = hasPayloadKey(vessel, ["MOBILEPHONE", "mobilePhone"])>
                <cfset hasSattelite = hasPayloadKey(vessel, ["SATTELITE", "sattelite"])>
                <cfset hasPrimaryPropulsion = hasPayloadKey(vessel, ["PRIMARYPROPULSION", "primaryPropulsion"])>
                <cfset hasPrimaryPropulsionType = hasPayloadKey(vessel, ["PRIMARYPROPULSIONTYPE", "primaryPropulsionType"])>
                <cfset hasNumberPrimary = hasPayloadKey(vessel, ["NUMBERPRIMARY", "numberPrimary"])>
                <cfset hasPrimaryFuelCapacity = hasPayloadKey(vessel, ["PRIMARYFUELCAPACITY", "primaryFuelCapacity"])>
                <cfset hasAuxPropulsion = hasPayloadKey(vessel, ["AUXPROPULSION", "auxPropulsion"])>
                <cfset hasAuxPropulsionType = hasPayloadKey(vessel, ["AUXPROPULSIONTYPE", "auxPropulsionType"])>
                <cfset hasNumberAux = hasPayloadKey(vessel, ["NUMBERAUX", "numberAux"])>
                <cfset hasAuxFuelCapacity = hasPayloadKey(vessel, ["AUXFUELCAPACITY", "auxFuelCapacity"])>
                <cfset hasNavigation = hasPayloadKey(vessel, ["NAVIGATION", "navigation"])>
                <cfset hasOtherNavigation = hasPayloadKey(vessel, ["OTHERNAVIGATION", "otherNavigation"])>
                <cfset hasVisualDistressSignals = hasPayloadKey(vessel, ["VISUALDISTRESSSIGNALS", "visualDistressSignals"])>
                <cfset hasAudibleDistressSignals = hasPayloadKey(vessel, ["AUDIBLEDISTRESSSIGNALS", "audibleDistressSignals"])>
                <cfset hasAepirb = hasPayloadKey(vessel, ["AEPIRB", "aepirb"])>
                <cfset hasAnchor = hasPayloadKey(vessel, ["ANCHOR", "anchor"])>
                <cfset hasAnchorLineLength = hasPayloadKey(vessel, ["ANCHORLINELENGTH", "anchorLineLength"])>
                <cfset hasAdditionalGear = hasPayloadKey(vessel, ["ADDITIONALGEAR", "additionalGear"])>
                <cfset hasOtherEquipment = hasPayloadKey(vessel, ["OTHEREQUIPMENT", "otherEquipment"])>
                <cfset hasOtherEquipmentB = hasPayloadKey(vessel, ["OTHEREQUIPMENT_B", "otherEquipment_b"])>
                <cfset hasOtherEquipmentC = hasPayloadKey(vessel, ["OTHEREQUIPMENT_C", "otherEquipment_c"])>
                <cfset hasOtherEquipmentD = hasPayloadKey(vessel, ["OTHEREQUIPMENT_D", "otherEquipment_d"])>

                <cfset hin = hasHin ? trim(toString(readPayloadValue(vessel, ["HIN", "hin"]))) : "">
                <cfset yearBuilt = hasYearBuilt ? trim(toString(readPayloadValue(vessel, ["YEARBUILT", "yearBuilt"]))) : "">
                <cfset draft = hasDraft ? trim(toString(readPayloadValue(vessel, ["DRAFT", "draft"]))) : "">
                <cfset hullMaterial = hasHullMaterial ? normalizeAllowedValue(readPayloadValue(vessel, ["HULLMATERIAL", "hullMaterial"]), ["Aluminum", "Composite", "Concrete", "Fabric", "Fiberglass", "Plastic", "Steel", "Wood"], "Hull material") : "">
                <cfset prominentFeatures = hasProminentFeatures ? trim(toString(readPayloadValue(vessel, ["PROMINENTFEATURES", "prominentFeatures"]))) : "">
                <cfset callSignNumber = hasCallSignNumber ? trim(toString(readPayloadValue(vessel, ["CALLSIGNNUMBER", "callSignNumber"]))) : "">
                <cfset dscMmsi = hasDscMmsi ? trim(toString(readPayloadValue(vessel, ["DSCMMSI", "dscMmsi"]))) : "">
                <cfset radio1Type = hasRadio1Type ? normalizeAllowedValue(readPayloadValue(vessel, ["RADIO_1_TYPE", "radio_1_type"]), ["none", "CB", "HF", "MF", "VHF-FM"], "Primary radio type") : "">
                <cfset radio1Channel = hasRadio1Channel ? trim(toString(readPayloadValue(vessel, ["RADIO_1_CHANNEL", "radio_1_channel"]))) : "">
                <cfset radio2Type = hasRadio2Type ? normalizeAllowedValue(readPayloadValue(vessel, ["RADIO_2_TYPE", "radio_2_type"]), ["none", "CB", "HF", "MF", "VHF-FM"], "Secondary radio type") : "">
                <cfset radio2Channel = hasRadio2Channel ? trim(toString(readPayloadValue(vessel, ["RADIO_2_CHANNEL", "radio_2_channel"]))) : "">
                <cfset mobilePhone = hasMobilePhone ? trim(toString(readPayloadValue(vessel, ["MOBILEPHONE", "mobilePhone"]))) : "">
                <cfset sattelite = hasSattelite ? trim(toString(readPayloadValue(vessel, ["SATTELITE", "sattelite"]))) : "">
                <cfset primaryPropulsion = hasPrimaryPropulsion ? trim(toString(readPayloadValue(vessel, ["PRIMARYPROPULSION", "primaryPropulsion"]))) : "">
                <cfset primaryPropulsionType = hasPrimaryPropulsionType ? normalizeAllowedValue(readPayloadValue(vessel, ["PRIMARYPROPULSIONTYPE", "primaryPropulsionType"]), ["Diesel IB", "Diesel IO", "Diesel OB", "Electric IB", "Electric IO", "Electric OB", "Fan", "Gas IB", "Gas IO", "Gas OB", "Oar", "Paddle", "Wind"], "Primary propulsion type") : "">
                <cfset numberPrimary = hasNumberPrimary ? trim(toString(readPayloadValue(vessel, ["NUMBERPRIMARY", "numberPrimary"]))) : "">
                <cfset primaryFuelCapacityRaw = hasPrimaryFuelCapacity ? trim(toString(readPayloadValue(vessel, ["PRIMARYFUELCAPACITY", "primaryFuelCapacity"]))) : "">
                <cfset auxPropulsion = hasAuxPropulsion ? trim(toString(readPayloadValue(vessel, ["AUXPROPULSION", "auxPropulsion"]))) : "">
                <cfset auxPropulsionType = hasAuxPropulsionType ? normalizeAllowedValue(readPayloadValue(vessel, ["AUXPROPULSIONTYPE", "auxPropulsionType"]), ["none", "Diesel IB", "Diesel IO", "Diesel OB", "Electric IB", "Electric IO", "Electric OB", "Fan", "Gas IB", "Gas IO", "Gas OB", "Oar", "Paddle", "Wind"], "Auxiliary propulsion type") : "">
                <cfset numberAux = hasNumberAux ? trim(toString(readPayloadValue(vessel, ["NUMBERAUX", "numberAux"]))) : "">
                <cfset auxFuelCapacityRaw = hasAuxFuelCapacity ? trim(toString(readPayloadValue(vessel, ["AUXFUELCAPACITY", "auxFuelCapacity"]))) : "">
                <cfset navigation = hasNavigation ? normalizeTokenList(readPayloadValue(vessel, ["NAVIGATION", "navigation"]), ["compass", "radar", "gps_dgps", "depthSounder", "charts", "maps", "other"], "Navigation equipment") : "">
                <cfset otherNavigation = hasOtherNavigation ? trim(toString(readPayloadValue(vessel, ["OTHERNAVIGATION", "otherNavigation"]))) : "">
                <cfset visualDistressSignals = hasVisualDistressSignals ? normalizeTokenList(readPayloadValue(vessel, ["VISUALDISTRESSSIGNALS", "visualDistressSignals"]), ["ElectricDistressLight", "Flag", "FlareAerial", "FlareHandheld", "SignalMirror", "Smoke"], "Visual distress signals") : "">
                <cfset audibleDistressSignals = hasAudibleDistressSignals ? normalizeTokenList(readPayloadValue(vessel, ["AUDIBLEDISTRESSSIGNALS", "audibleDistressSignals"]), ["Bell", "Horn", "Whistle"], "Audible distress signals") : "">
                <cfset aepirb = hasAepirb ? trim(toString(readPayloadValue(vessel, ["AEPIRB", "aepirb"]))) : "">
                <cfset anchor = hasAnchor ? normalizeOptionalFlag(readPayloadValue(vessel, ["ANCHOR", "anchor"]), "Anchor") : "">
                <cfset anchorLineLength = hasAnchorLineLength ? trim(toString(readPayloadValue(vessel, ["ANCHORLINELENGTH", "anchorLineLength"]))) : "">
                <cfset additionalGear = hasAdditionalGear ? normalizeTokenList(readPayloadValue(vessel, ["ADDITIONALGEAR", "additionalGear"]), ["DewateringDevice", "ExposureSuits", "FireExtinguisher", "FlashlightSearchLight", "RaftDinghy"], "Additional gear") : "">
                <cfset otherEquipment = hasOtherEquipment ? trim(toString(readPayloadValue(vessel, ["OTHEREQUIPMENT", "otherEquipment"]))) : "">
                <cfset otherEquipmentB = hasOtherEquipmentB ? trim(toString(readPayloadValue(vessel, ["OTHEREQUIPMENT_B", "otherEquipment_b"]))) : "">
                <cfset otherEquipmentC = hasOtherEquipmentC ? trim(toString(readPayloadValue(vessel, ["OTHEREQUIPMENT_C", "otherEquipment_c"]))) : "">
                <cfset otherEquipmentD = hasOtherEquipmentD ? trim(toString(readPayloadValue(vessel, ["OTHEREQUIPMENT_D", "otherEquipment_d"]))) : "">
                <cfset isDefaultRaw = "1">
                <cfif structKeyExists(vessel, "ISDEFAULTVESSEL")>
                    <cfset isDefaultRaw = trim(vessel.ISDEFAULTVESSEL)>
                <cfelseif structKeyExists(vessel, "isDefaultVessel")>
                    <cfset isDefaultRaw = trim(vessel.isDefaultVessel)>
                </cfif>
                <cfset isDefaultVessel = 1>
                <cfif isNumeric(isDefaultRaw)>
                    <cfset isDefaultVessel = (val(isDefaultRaw) GT 0 ? 1 : 0)>
                <cfelseif isBoolean(isDefaultRaw)>
                    <cfset isDefaultVessel = (isDefaultRaw ? 1 : 0)>
                <cfelseif lcase(isDefaultRaw) EQ "true" OR lcase(isDefaultRaw) EQ "yes" OR lcase(isDefaultRaw) EQ "on">
                    <cfset isDefaultVessel = 1>
                <cfelseif lcase(isDefaultRaw) EQ "false" OR lcase(isDefaultRaw) EQ "no" OR lcase(isDefaultRaw) EQ "off">
                    <cfset isDefaultVessel = 0>
                </cfif>
                <cfset hasMaxSpeed = len(maxSpeedRaw)>
                <cfset hasMostEfficientSpeed = len(mostEfficientSpeedRaw)>
                <cfset hasGallonsPerHour = len(gallonsPerHourRaw)>
                <cfset hasGphAtMaxSpeed = len(gphAtMaxSpeedRaw)>
                <cfset hasFuelCapacity = len(fuelCapacityRaw)>
                <cfset hasPrimaryFuelCapacityValue = len(primaryFuelCapacityRaw)>
                <cfset hasAuxFuelCapacityValue = len(auxFuelCapacityRaw)>
                <cfif NOT len(vesselType)>
                    <cfthrow message="Vessel type is required.">
                </cfif>
                <cfif NOT len(length)>
                    <cfthrow message="Vessel length is required.">
                </cfif>
                <cfif NOT len(color)>
                    <cfthrow message="Hull color is required.">
                </cfif>
                <cfif hasMaxSpeed AND NOT isNumeric(maxSpeedRaw)>
                    <cfthrow message="Max speed must be numeric.">
                </cfif>
                <cfif hasMostEfficientSpeed AND NOT isNumeric(mostEfficientSpeedRaw)>
                    <cfthrow message="Most efficient speed must be numeric.">
                </cfif>
                <cfif hasGallonsPerHour AND NOT isNumeric(gallonsPerHourRaw)>
                    <cfthrow message="Gallons per hour must be numeric.">
                </cfif>
                <cfif hasGphAtMaxSpeed AND NOT isNumeric(gphAtMaxSpeedRaw)>
                    <cfthrow message="GPH at max speed must be numeric.">
                </cfif>
                <cfif hasFuelCapacity AND NOT isNumeric(fuelCapacityRaw)>
                    <cfthrow message="Fuel capacity must be numeric.">
                </cfif>
                <cfif len(numberPrimary) AND NOT reFind("^[0-9]+$", numberPrimary)>
                    <cfthrow message="Primary engine count must be a non-negative whole number.">
                </cfif>
                <cfif len(numberAux) AND NOT reFind("^[0-9]+$", numberAux)>
                    <cfthrow message="Auxiliary engine count must be a non-negative whole number.">
                </cfif>
                <cfif hasPrimaryFuelCapacityValue AND (NOT reFind("^[0-9]+([.][0-9]{1,2})?$", primaryFuelCapacityRaw) OR val(primaryFuelCapacityRaw) GT 99999999.99)>
                    <cfthrow message="Primary fuel capacity must be between 0 and 99999999.99 with no more than two decimal places.">
                </cfif>
                <cfif hasAuxFuelCapacityValue AND (NOT reFind("^[0-9]+([.][0-9]{1,2})?$", auxFuelCapacityRaw) OR val(auxFuelCapacityRaw) GT 99999999.99)>
                    <cfthrow message="Auxiliary fuel capacity must be between 0 and 99999999.99 with no more than two decimal places.">
                </cfif>
                <cfset enforceMaxLength(hin, 255, "HIN")>
                <cfset enforceMaxLength(yearBuilt, 45, "Year built")>
                <cfset enforceMaxLength(draft, 45, "Draft")>
                <cfset enforceMaxLength(hullMaterial, 155, "Hull material")>
                <cfset enforceMaxLength(prominentFeatures, 255, "Prominent features")>
                <cfset enforceMaxLength(callSignNumber, 255, "Radio call sign")>
                <cfset enforceMaxLength(dscMmsi, 150, "MMSI")>
                <cfset enforceMaxLength(radio1Channel, 255, "Primary channel or frequency")>
                <cfset enforceMaxLength(radio2Channel, 255, "Secondary channel or frequency")>
                <cfset enforceMaxLength(mobilePhone, 45, "Vessel mobile phone")>
                <cfset enforceMaxLength(sattelite, 45, "Satellite phone")>
                <cfset enforceMaxLength(primaryPropulsion, 45, "Primary propulsion details")>
                <cfset enforceMaxLength(numberPrimary, 45, "Primary engine count")>
                <cfset enforceMaxLength(auxPropulsion, 45, "Auxiliary propulsion details")>
                <cfset enforceMaxLength(numberAux, 45, "Auxiliary engine count")>
                <cfset enforceMaxLength(otherNavigation, 255, "Other navigation equipment")>
                <cfset enforceMaxLength(aepirb, 150, "EPIRB UIN")>
                <cfset enforceMaxLength(anchorLineLength, 150, "Anchor line or rode length")>
                <cfset enforceMaxLength(otherEquipment, 255, "Other equipment 1")>
                <cfset enforceMaxLength(otherEquipmentB, 255, "Other equipment 2")>
                <cfset enforceMaxLength(otherEquipmentC, 255, "Other equipment 3")>
                <cfset enforceMaxLength(otherEquipmentD, 255, "Other equipment 4")>

                <cfif vesselId GT 0>
                    <cfif isDefaultVessel EQ 1>
                        <cfquery datasource="fpw">
                            UPDATE vessels
                            SET isDefaultVessel = <cfqueryparam cfsqltype="cf_sql_tinyint" value="0">
                            WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                              AND vesselId <> <cfqueryparam cfsqltype="cf_sql_integer" value="#vesselId#">
                        </cfquery>
                    </cfif>
                    <cfquery datasource="fpw">
                        UPDATE vessels
                        SET vesselName = <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselName#">,
                            registration = <cfqueryparam cfsqltype="cf_sql_varchar" value="#registration#">,
                            typeOfVessel = <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselType#">,
                            make = <cfqueryparam cfsqltype="cf_sql_varchar" value="#make#">,
                            model = <cfqueryparam cfsqltype="cf_sql_varchar" value="#model#">,
                            lengthOfVessel = <cfqueryparam cfsqltype="cf_sql_varchar" value="#length#">,
                            max_speed = <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasMaxSpeed ? val(maxSpeedRaw) : 0#" null="#NOT hasMaxSpeed#" scale="2" maxlength="6">,
                            most_efficient_speed = <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasMostEfficientSpeed ? val(mostEfficientSpeedRaw) : 0#" null="#NOT hasMostEfficientSpeed#" scale="2" maxlength="6">,
                            gallons_per_hour = <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasGallonsPerHour ? val(gallonsPerHourRaw) : 0#" null="#NOT hasGallonsPerHour#" scale="2" maxlength="8">,
                            gph_at_max_speed = <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasGphAtMaxSpeed ? val(gphAtMaxSpeedRaw) : 0#" null="#NOT hasGphAtMaxSpeed#" scale="2" maxlength="8">,
                            fuel_capacity = <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasFuelCapacity ? val(fuelCapacityRaw) : 0#" null="#NOT hasFuelCapacity#" scale="2" maxlength="10">,
                            isDefaultVessel = <cfqueryparam cfsqltype="cf_sql_tinyint" value="#isDefaultVessel#">,
                            hullColor = <cfqueryparam cfsqltype="cf_sql_varchar" value="#color#">,
                            hailingPort = <cfqueryparam cfsqltype="cf_sql_varchar" value="#homePort#">
                            <cfif hasHin>, hin = <cfqueryparam cfsqltype="cf_sql_varchar" value="#hin#" null="#NOT len(hin)#" maxlength="255"></cfif>
                            <cfif hasYearBuilt>, yearBuilt = <cfqueryparam cfsqltype="cf_sql_varchar" value="#yearBuilt#" null="#NOT len(yearBuilt)#" maxlength="45"></cfif>
                            <cfif hasDraft>, draft = <cfqueryparam cfsqltype="cf_sql_varchar" value="#draft#" null="#NOT len(draft)#" maxlength="45"></cfif>
                            <cfif hasHullMaterial>, hullMaterial = <cfqueryparam cfsqltype="cf_sql_varchar" value="#hullMaterial#" null="#NOT len(hullMaterial)#" maxlength="155"></cfif>
                            <cfif hasProminentFeatures>, prominentFeatures = <cfqueryparam cfsqltype="cf_sql_varchar" value="#prominentFeatures#" null="#NOT len(prominentFeatures)#" maxlength="255"></cfif>
                            <cfif hasCallSignNumber>, callSignNumber = <cfqueryparam cfsqltype="cf_sql_varchar" value="#callSignNumber#" null="#NOT len(callSignNumber)#" maxlength="255"></cfif>
                            <cfif hasDscMmsi>, DSCMMSI = <cfqueryparam cfsqltype="cf_sql_varchar" value="#dscMmsi#" null="#NOT len(dscMmsi)#" maxlength="150"></cfif>
                            <cfif hasRadio1Type>, radio_1_type = <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio1Type#" null="#NOT len(radio1Type)#" maxlength="45"></cfif>
                            <cfif hasRadio1Channel>, radio_1_channel = <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio1Channel#" null="#NOT len(radio1Channel)#" maxlength="255"></cfif>
                            <cfif hasRadio2Type>, radio_2_type = <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio2Type#" null="#NOT len(radio2Type)#" maxlength="45"></cfif>
                            <cfif hasRadio2Channel>, radio_2_channel = <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio2Channel#" null="#NOT len(radio2Channel)#" maxlength="255"></cfif>
                            <cfif hasMobilePhone>, mobilePhone = <cfqueryparam cfsqltype="cf_sql_varchar" value="#mobilePhone#" null="#NOT len(mobilePhone)#" maxlength="45"></cfif>
                            <cfif hasSattelite>, sattelite = <cfqueryparam cfsqltype="cf_sql_varchar" value="#sattelite#" null="#NOT len(sattelite)#" maxlength="45"></cfif>
                            <cfif hasPrimaryPropulsion>, primaryPropulsion = <cfqueryparam cfsqltype="cf_sql_varchar" value="#primaryPropulsion#" null="#NOT len(primaryPropulsion)#" maxlength="45"></cfif>
                            <cfif hasPrimaryPropulsionType>, primaryPropulsionType = <cfqueryparam cfsqltype="cf_sql_varchar" value="#primaryPropulsionType#" null="#NOT len(primaryPropulsionType)#" maxlength="45"></cfif>
                            <cfif hasNumberPrimary>, numberPrimary = <cfqueryparam cfsqltype="cf_sql_varchar" value="#numberPrimary#" null="#NOT len(numberPrimary)#" maxlength="45"></cfif>
                            <cfif hasPrimaryFuelCapacity>, primaryFuelCapacity = <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasPrimaryFuelCapacityValue ? val(primaryFuelCapacityRaw) : 0#" null="#NOT hasPrimaryFuelCapacityValue#" scale="2" maxlength="10"></cfif>
                            <cfif hasAuxPropulsion>, auxPropulsion = <cfqueryparam cfsqltype="cf_sql_varchar" value="#auxPropulsion#" null="#NOT len(auxPropulsion)#" maxlength="45"></cfif>
                            <cfif hasAuxPropulsionType>, auxPropulsionType = <cfqueryparam cfsqltype="cf_sql_varchar" value="#auxPropulsionType#" null="#NOT len(auxPropulsionType)#" maxlength="45"></cfif>
                            <cfif hasNumberAux>, numberAux = <cfqueryparam cfsqltype="cf_sql_varchar" value="#numberAux#" null="#NOT len(numberAux)#" maxlength="45"></cfif>
                            <cfif hasAuxFuelCapacity>, auxFuelCapacity = <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasAuxFuelCapacityValue ? val(auxFuelCapacityRaw) : 0#" null="#NOT hasAuxFuelCapacityValue#" scale="2" maxlength="10"></cfif>
                            <cfif hasNavigation>, navigation = <cfqueryparam cfsqltype="cf_sql_varchar" value="#navigation#" null="#NOT len(navigation)#" maxlength="255"></cfif>
                            <cfif hasOtherNavigation>, otherNavigation = <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherNavigation#" null="#NOT len(otherNavigation)#" maxlength="255"></cfif>
                            <cfif hasVisualDistressSignals>, visualDistressSignals = <cfqueryparam cfsqltype="cf_sql_varchar" value="#visualDistressSignals#" null="#NOT len(visualDistressSignals)#" maxlength="255"></cfif>
                            <cfif hasAudibleDistressSignals>, audibleDistressSignals = <cfqueryparam cfsqltype="cf_sql_varchar" value="#audibleDistressSignals#" null="#NOT len(audibleDistressSignals)#" maxlength="255"></cfif>
                            <cfif hasAepirb>, aepirb = <cfqueryparam cfsqltype="cf_sql_varchar" value="#aepirb#" null="#NOT len(aepirb)#" maxlength="150"></cfif>
                            <cfif hasAnchor>, anchor = <cfqueryparam cfsqltype="cf_sql_varchar" value="#anchor#" null="#NOT len(anchor)#" maxlength="150"></cfif>
                            <cfif hasAnchorLineLength>, anchorLineLength = <cfqueryparam cfsqltype="cf_sql_varchar" value="#anchorLineLength#" null="#NOT len(anchorLineLength)#" maxlength="150"></cfif>
                            <cfif hasAdditionalGear>, additionalGear = <cfqueryparam cfsqltype="cf_sql_varchar" value="#additionalGear#" null="#NOT len(additionalGear)#" maxlength="255"></cfif>
                            <cfif hasOtherEquipment>, otherEquipment = <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipment#" null="#NOT len(otherEquipment)#" maxlength="255"></cfif>
                            <cfif hasOtherEquipmentB>, otherEquipment_b = <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipmentB#" null="#NOT len(otherEquipmentB)#" maxlength="255"></cfif>
                            <cfif hasOtherEquipmentC>, otherEquipment_c = <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipmentC#" null="#NOT len(otherEquipmentC)#" maxlength="255"></cfif>
                            <cfif hasOtherEquipmentD>, otherEquipment_d = <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipmentD#" null="#NOT len(otherEquipmentD)#" maxlength="255"></cfif>
                        WHERE vesselId = <cfqueryparam cfsqltype="cf_sql_integer" value="#vesselId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                <cfelse>
                    <cfset insertResult = {}>
                    <cfif isDefaultVessel EQ 1>
                        <cfquery datasource="fpw">
                            UPDATE vessels
                            SET isDefaultVessel = <cfqueryparam cfsqltype="cf_sql_tinyint" value="0">
                            WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                        </cfquery>
                    </cfif>
                    <cfquery datasource="fpw" result="insertResult">
                        INSERT INTO vessels (
                            userId, vesselName, registration, typeOfVessel, make, model, lengthOfVessel,
                            max_speed, most_efficient_speed, gallons_per_hour, gph_at_max_speed, fuel_capacity,
                            isDefaultVessel, hullColor, hailingPort,
                            hin, yearBuilt, draft, hullMaterial, prominentFeatures,
                            callSignNumber, DSCMMSI, radio_1_type, radio_1_channel, radio_2_type, radio_2_channel,
                            mobilePhone, sattelite,
                            primaryPropulsion, primaryPropulsionType, numberPrimary, primaryFuelCapacity,
                            auxPropulsion, auxPropulsionType, numberAux, auxFuelCapacity,
                            navigation, otherNavigation, visualDistressSignals, audibleDistressSignals,
                            aepirb, anchor, anchorLineLength, additionalGear,
                            otherEquipment, otherEquipment_b, otherEquipment_c, otherEquipment_d
                        )
                        VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselName#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#registration#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#vesselType#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#make#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#model#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#length#">,
                            <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasMaxSpeed ? val(maxSpeedRaw) : 0#" null="#NOT hasMaxSpeed#" scale="2" maxlength="6">,
                            <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasMostEfficientSpeed ? val(mostEfficientSpeedRaw) : 0#" null="#NOT hasMostEfficientSpeed#" scale="2" maxlength="6">,
                            <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasGallonsPerHour ? val(gallonsPerHourRaw) : 0#" null="#NOT hasGallonsPerHour#" scale="2" maxlength="8">,
                            <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasGphAtMaxSpeed ? val(gphAtMaxSpeedRaw) : 0#" null="#NOT hasGphAtMaxSpeed#" scale="2" maxlength="8">,
                            <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasFuelCapacity ? val(fuelCapacityRaw) : 0#" null="#NOT hasFuelCapacity#" scale="2" maxlength="10">,
                            <cfqueryparam cfsqltype="cf_sql_tinyint" value="#isDefaultVessel#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#color#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#homePort#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#hin#" null="#NOT len(hin)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#yearBuilt#" null="#NOT len(yearBuilt)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#draft#" null="#NOT len(draft)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#hullMaterial#" null="#NOT len(hullMaterial)#" maxlength="155">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#prominentFeatures#" null="#NOT len(prominentFeatures)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#callSignNumber#" null="#NOT len(callSignNumber)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#dscMmsi#" null="#NOT len(dscMmsi)#" maxlength="150">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio1Type#" null="#NOT len(radio1Type)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio1Channel#" null="#NOT len(radio1Channel)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio2Type#" null="#NOT len(radio2Type)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#radio2Channel#" null="#NOT len(radio2Channel)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#mobilePhone#" null="#NOT len(mobilePhone)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#sattelite#" null="#NOT len(sattelite)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#primaryPropulsion#" null="#NOT len(primaryPropulsion)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#primaryPropulsionType#" null="#NOT len(primaryPropulsionType)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#numberPrimary#" null="#NOT len(numberPrimary)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasPrimaryFuelCapacityValue ? val(primaryFuelCapacityRaw) : 0#" null="#NOT hasPrimaryFuelCapacityValue#" scale="2" maxlength="10">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#auxPropulsion#" null="#NOT len(auxPropulsion)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#auxPropulsionType#" null="#NOT len(auxPropulsionType)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#numberAux#" null="#NOT len(numberAux)#" maxlength="45">,
                            <cfqueryparam cfsqltype="cf_sql_decimal" value="#hasAuxFuelCapacityValue ? val(auxFuelCapacityRaw) : 0#" null="#NOT hasAuxFuelCapacityValue#" scale="2" maxlength="10">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#navigation#" null="#NOT len(navigation)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherNavigation#" null="#NOT len(otherNavigation)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#visualDistressSignals#" null="#NOT len(visualDistressSignals)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#audibleDistressSignals#" null="#NOT len(audibleDistressSignals)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#aepirb#" null="#NOT len(aepirb)#" maxlength="150">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#anchor#" null="#NOT len(anchor)#" maxlength="150">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#anchorLineLength#" null="#NOT len(anchorLineLength)#" maxlength="150">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#additionalGear#" null="#NOT len(additionalGear)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipment#" null="#NOT len(otherEquipment)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipmentB#" null="#NOT len(otherEquipmentB)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipmentC#" null="#NOT len(otherEquipmentC)#" maxlength="255">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#otherEquipmentD#" null="#NOT len(otherEquipmentD)#" maxlength="255">
                        )
                    </cfquery>
                    <cfif structKeyExists(insertResult, "generatedKey")>
                        <cfset vesselId = insertResult.generatedKey>
                    </cfif>
                    <cfif vesselId GT 0>
                        <cftry>
                            <cfset createObject("component", "fpw.includes.ProductEventService").init("fpw").recordEvent(
                                userId = userId,
                                eventName = "vessel_created",
                                entityType = "vessel",
                                entityId = vesselId,
                                eventSource = "member_api",
                                metadata = {
                                    creation_source = "member"
                                },
                                idempotencyKey = "vessel_created:vessel:" & vesselId,
                                requestCorrelationId = structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : ""
                            )>
                        <cfcatch type="any">
                            <cflog file="fpw_product_events" type="error" text="vessel.cfc PRODUCT_EVENT_CALL_FAILED | event=vessel_created">
                        </cfcatch>
                        </cftry>
                    </cfif>
                </cfif>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    VESSELID = vesselId
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "removeimage">
                <cfset vesselId = 0>
                <cfif structKeyExists(body, "vesselId")>
                    <cfset vesselId = val(body.vesselId)>
                <cfelseif structKeyExists(body, "VESSELID")>
                    <cfset vesselId = val(body.VESSELID)>
                <cfelseif structKeyExists(url, "vesselId")>
                    <cfset vesselId = val(url.vesselId)>
                </cfif>

                <cfif vesselId LTE 0>
                    <cfthrow message="Vessel id is required.">
                </cfif>

                <cfset imageResult = getVesselImageService().removeVesselImage(vesselId, userId)>
                <cfset response = {
                    SUCCESS = imageResult.SUCCESS,
                    AUTH    = true,
                    MESSAGE = imageResult.MESSAGE
                }>
                <cfif NOT imageResult.SUCCESS>
                    <cfset response.ERROR = "IMAGE_REMOVE_FAILED">
                </cfif>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "candelete">
                <cfset vesselId = 0>
                <cfif structKeyExists(body, "vesselId")>
                    <cfset vesselId = val(body.vesselId)>
                <cfelseif structKeyExists(body, "VESSELID")>
                    <cfset vesselId = val(body.VESSELID)>
                <cfelseif structKeyExists(url, "vesselId")>
                    <cfset vesselId = val(url.vesselId)>
                </cfif>

                <cfif vesselId LTE 0>
                    <cfthrow message="Vessel id is required.">
                </cfif>

                <cfquery name="qVesselUsage" datasource="fpw">
                    SELECT floatPlanName
                    FROM floatplans
                    WHERE vesselId = <cfqueryparam cfsqltype="cf_sql_integer" value="#vesselId#">
                      AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qVesselUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qVesselUsage">
                        <cfset arrayAppend(planNames, qVesselUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = false,
                        MESSAGE = "This vessel is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                <cfelse>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = true
                    }>
                </cfif>

                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "delete">
                <cfset vesselId = 0>
                <cfif structKeyExists(body, "vesselId")>
                    <cfset vesselId = val(body.vesselId)>
                <cfelseif structKeyExists(body, "VESSELID")>
                    <cfset vesselId = val(body.VESSELID)>
                <cfelseif structKeyExists(url, "vesselId")>
                    <cfset vesselId = val(url.vesselId)>
                </cfif>

                <cfif vesselId LTE 0>
                    <cfthrow message="Vessel id is required.">
                </cfif>

                <cfquery name="qVesselUsage" datasource="fpw">
                    SELECT floatPlanName
                    FROM floatplans
                    WHERE vesselId = <cfqueryparam cfsqltype="cf_sql_integer" value="#vesselId#">
                      AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qVesselUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qVesselUsage">
                        <cfset arrayAppend(planNames, qVesselUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "IN_USE",
                        MESSAGE = "This vessel is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfquery datasource="fpw">
                    DELETE FROM vessels
                    WHERE vesselId = <cfqueryparam cfsqltype="cf_sql_integer" value="#vesselId#">
                      AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>
                <cfset getVesselImageService().deleteVesselImageFiles(vesselId, userId)>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset response = {
                SUCCESS = false,
                AUTH    = true,
                ERROR   = "INVALID_ACTION",
                MESSAGE = "Unknown action."
            }>
            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Vessel API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
	    </cffunction>

        <cffunction name="hasPayloadKey" access="private" returntype="boolean" output="false">
            <cfargument name="source" type="struct" required="true">
            <cfargument name="keys" type="array" required="true">
            <cfset var keyName = "">
            <cfloop array="#arguments.keys#" index="keyName">
                <cfif structKeyExists(arguments.source, keyName)>
                    <cfreturn true>
                </cfif>
            </cfloop>
            <cfreturn false>
        </cffunction>

        <cffunction name="readPayloadValue" access="private" returntype="any" output="false">
            <cfargument name="source" type="struct" required="true">
            <cfargument name="keys" type="array" required="true">
            <cfset var keyName = "">
            <cfloop array="#arguments.keys#" index="keyName">
                <cfif structKeyExists(arguments.source, keyName)>
                    <cfif isNull(arguments.source[keyName])>
                        <cfreturn "">
                    </cfif>
                    <cfreturn arguments.source[keyName]>
                </cfif>
            </cfloop>
            <cfreturn "">
        </cffunction>

        <cffunction name="normalizeAllowedValue" access="private" returntype="string" output="false">
            <cfargument name="value" type="any" required="true">
            <cfargument name="allowedValues" type="array" required="true">
            <cfargument name="fieldLabel" type="string" required="true">
            <cfset var rawValue = trim(toString(arguments.value))>
            <cfset var allowedValue = "">
            <cfif NOT len(rawValue)>
                <cfreturn "">
            </cfif>
            <cfloop array="#arguments.allowedValues#" index="allowedValue">
                <cfif compareNoCase(rawValue, allowedValue) EQ 0>
                    <cfreturn allowedValue>
                </cfif>
            </cfloop>
            <cfthrow message="#arguments.fieldLabel# has an invalid value.">
        </cffunction>

        <cffunction name="normalizeTokenList" access="private" returntype="string" output="false">
            <cfargument name="value" type="any" required="true">
            <cfargument name="allowedValues" type="array" required="true">
            <cfargument name="fieldLabel" type="string" required="true">
            <cfset var rawValues = []>
            <cfset var rawValue = "">
            <cfset var allowedValue = "">
            <cfset var matchedValue = "">
            <cfset var normalizedValues = []>
            <cfset var seenValues = {}>
            <cfset var seenKey = "">
            <cfif isArray(arguments.value)>
                <cfset rawValues = arguments.value>
            <cfelseif len(trim(toString(arguments.value)))>
                <cfset rawValues = listToArray(toString(arguments.value), ",")>
            </cfif>
            <cfloop array="#rawValues#" index="rawValue">
                <cfset rawValue = trim(toString(rawValue))>
                <cfif len(rawValue)>
                    <cfset matchedValue = "">
                    <cfloop array="#arguments.allowedValues#" index="allowedValue">
                        <cfif compareNoCase(rawValue, allowedValue) EQ 0>
                            <cfset matchedValue = allowedValue>
                            <cfbreak>
                        </cfif>
                    </cfloop>
                    <cfif NOT len(matchedValue)>
                        <cfthrow message="#arguments.fieldLabel# contains an invalid value.">
                    </cfif>
                    <cfset seenKey = lcase(matchedValue)>
                    <cfif NOT structKeyExists(seenValues, seenKey)>
                        <cfset seenValues[seenKey] = true>
                        <cfset arrayAppend(normalizedValues, matchedValue)>
                    </cfif>
                </cfif>
            </cfloop>
            <cfreturn arrayToList(normalizedValues, ",")>
        </cffunction>

        <cffunction name="normalizeOptionalFlag" access="private" returntype="string" output="false">
            <cfargument name="value" type="any" required="true">
            <cfargument name="fieldLabel" type="string" required="true">
            <cfset var rawValue = lcase(trim(toString(arguments.value)))>
            <cfif NOT len(rawValue)>
                <cfreturn "">
            </cfif>
            <cfif listFindNoCase("1,true,yes,on", rawValue)>
                <cfreturn "1">
            </cfif>
            <cfif listFindNoCase("0,false,no,off", rawValue)>
                <cfreturn "0">
            </cfif>
            <cfthrow message="#arguments.fieldLabel# has an invalid value.">
        </cffunction>

        <cffunction name="enforceMaxLength" access="private" returntype="boolean" output="false">
            <cfargument name="value" type="string" required="true">
            <cfargument name="maximumLength" type="numeric" required="true">
            <cfargument name="fieldLabel" type="string" required="true">
            <cfif len(arguments.value) GT arguments.maximumLength>
                <cfthrow message="#arguments.fieldLabel# must be #arguments.maximumLength# characters or fewer.">
            </cfif>
            <cfreturn true>
        </cffunction>

	    <cffunction name="getVesselImageService" access="private" returntype="any" output="false">
	        <cftry>
	            <cfreturn createObject("component", "fpw.api.v1.VesselImageService").init("fpw")>
	            <cfcatch>
	                <cfreturn createObject("component", "api.v1.VesselImageService").init("fpw")>
	            </cfcatch>
	        </cftry>
	    </cffunction>

	    <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
	        <cftry>
	            <cfreturn createObject("component", "fpw.api.v1.MemberAccessGateService").init("fpw")>
	            <cfcatch>
	                <cfreturn createObject("component", "api.v1.MemberAccessGateService").init("fpw")>
	            </cfcatch>
	        </cftry>
	    </cffunction>

</cfcomponent>
