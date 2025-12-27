<cfcomponent displayname="floatPlanUtils" output="false" hint="Generate Float Plan PDFs">
    <cffunction name="init" access="public" output="false" returntype="any">
        <cfreturn this>
    </cffunction>

    <cffunction name="createPDF" access="remote" output="false" returnformat="plain" hint="Populate the float plan PDF and save it locally">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var ds = "fpw";
            var baseDir = getDirectoryFromPath(getCurrentTemplatePath());
            var apiDir = getDirectoryFromPath(baseDir);
            var rootDir = getDirectoryFromPath(apiDir);
            var templatePath = baseDir & "USCGFloatPlan_new.pdf";
            var outputDir = rootDir & "floatPlans/user_float_plans";

            if (!directoryExists(outputDir)) {
                directoryCreate(outputDir);
            }

            var plan = loadFloatPlan(arguments.floatPlanId, ds);
            if (structIsEmpty(plan)) {
                return false;
            }

            var planName = getString(plan, "floatPlanName", "floatplan");
            var safePlanName = reReplace(planName, "[^A-Za-z0-9_-]+", "_", "all");
            var stamp = dateFormat(now(), "yyyymmdd") & "_" & timeFormat(now(), "HHmmss");
            var fileName = safePlanName & "_" & stamp & ".pdf";
            var destinationPath = outputDir & "/" & fileName;
            var readonlyFileName = reReplace(fileName, "\.pdf$", "_readonly.pdf", "all");
            if (readonlyFileName EQ fileName) {
                readonlyFileName = fileName & "_readonly";
            }
            var readonlyPath = outputDir & "/" & readonlyFileName;

            var vessel = loadVessel(getNumeric(plan, "vesselId", 0), ds);
            var operatorInfo = loadOperator(getNumeric(plan, "operatorId", 0), ds);
            var passengers = loadPassengers(arguments.floatPlanId, ds);
            var contacts = loadContacts(arguments.floatPlanId, ds);
            var waypoints = loadWaypoints(arguments.floatPlanId, ds);

            // Plan values
            var tripDepartureDate = formatDate(getAny(plan, "departureTime", ""));
            var tripDepartTime = formatTime(getAny(plan, "departureTime", ""));
            var tripDepartLocation = getString(plan, "departing", "");
            var tripReturnDate = formatDate(getAny(plan, "returnTime", ""));
            var tripReturnTime = formatTime(getAny(plan, "returnTime", ""));
            var tripReturnLocation = getString(plan, "returning", "");
            var email = getString(plan, "floatPlanEmail", "");
            var food = getString(plan, "food", "");
            var water = getString(plan, "water", "");
            var floatPlanNote = getString(plan, "notes", "");
            var rescueAuthority = getString(plan, "rescueAuthority", "");
            var rescueAuthorityPhone = getString(plan, "rescueAuthorityPhone", "");
            var opHasPfd = isTrueValue(getAny(plan, "opHasPfd", ""));

            // Vessel values
            var vesselName = getString(vessel, "vesselName", "");
            var docRegNum = getString(vessel, "registration", "");
            var draft = getString(vessel, "draft", "");
            var hin = getString(vessel, "hin", "");
            var hullMat = getString(vessel, "hullMaterial", "");
            var hullTrimColors = getString(vessel, "hullColor", "");
            var length = getString(vessel, "lengthOfVessel", "");
            var prominentFeatures = getString(vessel, "prominentFeatures", "");
            var vesselType = getString(vessel, "typeOfVessel", "");
            var yearMakeModel = buildYearMakeModel(vessel);
            var navigationList = getString(vessel, "navigation", "");
            var otherNavigation = getString(vessel, "otherNavigation", "");
            var navHasOther = ListFindNoCase(navigationList, "other") GT 0;
            var navOtherDesc = navHasOther ? otherNavigation : "";
            var radioCallSign = getString(vessel, "callSignNumber", "");
            var dscNo = getString(vessel, "dscmmsi", "");
            var radio1Type = getString(vessel, "radio_1_type", "");
            var radio1FreqMon = getString(vessel, "radio_1_channel", "");
            var radio2Type = getString(vessel, "radio_2_type", "");
            var radio2FreqMon = getString(vessel, "radio_2_channel", "");
            var cellSatPhone = joinNonEmpty([getString(vessel, "mobilePhone", ""), getString(vessel, "sattelite", "")], " | ");
            var primEngType = getString(vessel, "primaryPropulsionType", "");
            var primNumEngines = getString(vessel, "numberPrimary", "");
            var primFuelCapacity = getString(vessel, "primaryFuelCapacity", "");
            var auxEngType = getString(vessel, "auxPropulsionType", "");
            if (auxEngType EQ "None") {
                auxEngType = "none";
            }
            var auxNumEng = getString(vessel, "numberAux", "");
            var auxFuelCapacity = getString(vessel, "auxFuelCapacity", "");
            var vdsList = getString(vessel, "visualDistressSignals", "");
            var adsList = getString(vessel, "audibleDistressSignals", "");
            var anchor = isTrueValue(getAny(vessel, "anchor", ""));
            var anchorLineLength = getString(vessel, "anchorLineLength", "");
            var agList = getString(vessel, "additionalGear", "");
            var uin = getString(vessel, "aepirb", "");
            var otherAvail1 = getString(vessel, "otherEquipment", "");
            var otherAvailB = getString(vessel, "otherEquipment_b", "");
            var otherAvailC = getString(vessel, "otherEquipment_c", "");
            var otherAvailD = getString(vessel, "otherEquipment_d", "");
            var trailer = isTrueValue(getAny(vessel, "trailer", ""));

            // Operator values
            var oprName = getString(operatorInfo, "name", "");
            var oprAddress = getString(operatorInfo, "address", "");
            var oprCity = getString(operatorInfo, "city", "");
            var oprState = getString(operatorInfo, "state", "");
            var oprZip = getString(operatorInfo, "zip", "");
            var oprAge = getString(operatorInfo, "age", "");
            var oprGender = normalizeGender(getString(operatorInfo, "gender", ""));
            var oprPlbuin = getString(operatorInfo, "plbuin", "");
            var oprVesselExperience = getString(operatorInfo, "expWithVessel", "");
            var oprAreaExperience = getString(operatorInfo, "expWithBoatingArea", "");
            var oprPhone = getString(operatorInfo, "phone", "");
            var oprVehicleYearMakeModel = getString(operatorInfo, "vehicle", "");
            var oprVehicleLicenseNum = getString(operatorInfo, "vehicleLicense", "");
            var oprVehicleParkedAt = getString(operatorInfo, "vehicleParkedAt", "");
            var oprNotes = getString(operatorInfo, "notes", "");
        </cfscript>

        <cfpdfform action="populate" source="#templatePath#" destination="#destinationPath#" overwrite="true">
            <!-- Vessel -->
            <cfpdfformparam name="ID-VesselName" value="#vesselName#">
            <cfpdfformparam name="ID-DocRegNum" value="#docRegNum#">
            <cfpdfformparam name="ID-Draft" value="#draft#">
            <cfpdfformparam name="ID-HIN" value="#hin#">
            <cfpdfformparam name="ID-HullMat" value="#hullMat#">
            <cfpdfformparam name="ID-HullTrimColors" value="#hullTrimColors#">
            <cfpdfformparam name="ID-Length" value="#length#">
            <cfpdfformparam name="ID-ProminentFeatures" value="#prominentFeatures#">
            <cfpdfformparam name="ID-Type" value="#vesselType#">
            <cfpdfformparam name="ID-YearMakeModel" value="#yearMakeModel#">
            <cfpdfformparam name="PRO-PrimEngType" value="#primEngType#">
            <cfpdfformparam name="PRO-PrimNumEngines" value="#primNumEngines#">
            <cfpdfformparam name="PRO-PrimFuelCapacity" value="#primFuelCapacity#">
            <cfpdfformparam name="PRO-AuxEngType" value="#auxEngType#">
            <cfpdfformparam name="PRO-AuxNumEng" value="#auxNumEng#">
            <cfpdfformparam name="PRO-AuxFuelCapacity" value="#auxFuelCapacity#">

            <cfpdfformparam name="NAV-Compass" value="#yesNo(ListFindNoCase(navigationList, 'compass'))#">
            <cfpdfformparam name="NAV-Radar" value="#yesNo(ListFindNoCase(navigationList, 'radar'))#">
            <cfpdfformparam name="NAV-GPS" value="#yesNo(ListFindNoCase(navigationList, 'gps_dgps'))#">
            <cfpdfformparam name="NAV-DepthSounder" value="#yesNo(ListFindNoCase(navigationList, 'depthSounder'))#">
            <cfpdfformparam name="NAV-Charts" value="#yesNo(ListFindNoCase(navigationList, 'charts'))#">
            <cfpdfformparam name="NAV-Maps" value="#yesNo(ListFindNoCase(navigationList, 'maps'))#">
            <cfpdfformparam name="NAV-OtherAvail" value="#yesNo(navHasOther)#">
            <cfpdfformparam name="NAV-UserDesc" value="#navOtherDesc#">

            <cfpdfformparam name="COM-RadioCallSign" value="#radioCallSign#">
            <cfpdfformparam name="COM-DSCNo" value="#dscNo#">
            <cfpdfformparam name="COM-Radio1Type" value="#radio1Type#">
            <cfpdfformparam name="COM-Radio1FreqMon" value="#radio1FreqMon#">
            <cfpdfformparam name="COM-Radio2Type" value="#radio2Type#">
            <cfpdfformparam name="COM-Radio2FreqMon" value="#radio2FreqMon#">
            <cfpdfformparam name="COM-CellSatPhone" value="#cellSatPhone#">
            <cfpdfformparam name="COM-Email" value="#email#">

            <!-- Safety & survival -->
            <cfpdfformparam name="VDS-EDL" value="#yesNo(ListFindNoCase(vdsList, 'ElectricDistressLight'))#">
            <cfpdfformparam name="VDS-Flag" value="#yesNo(ListFindNoCase(vdsList, 'Flag'))#">
            <cfpdfformparam name="VDS-FlareAerial" value="#yesNo(ListFindNoCase(vdsList, 'FlareAerial'))#">
            <cfpdfformparam name="VDS-FlareHandheld" value="#yesNo(ListFindNoCase(vdsList, 'FlareHandheld'))#">
            <cfpdfformparam name="VDS-SignalMirror" value="#yesNo(ListFindNoCase(vdsList, 'SignalMirror'))#">
            <cfpdfformparam name="VDS-Smoke" value="#yesNo(ListFindNoCase(vdsList, 'Smoke'))#">
            <cfpdfformparam name="ADS-Bell" value="#yesNo(ListFindNoCase(adsList, 'Bell'))#">
            <cfpdfformparam name="ADS-Horn" value="#yesNo(ListFindNoCase(adsList, 'Horn'))#">
            <cfpdfformparam name="ADS-Whistle" value="#yesNo(ListFindNoCase(adsList, 'Whistle'))#">
            <cfpdfformparam name="ADD-Anchor" value="#yesNo(anchor)#">
            <cfpdfformparam name="ADD-AnchorLineLength" value="#anchorLineLength#">
            <cfpdfformparam name="ADD-Dewatering" value="#yesNo(ListFindNoCase(agList, 'DewateringDevice'))#">
            <cfpdfformparam name="ADD-ExposureSuit" value="#yesNo(ListFindNoCase(agList, 'ExposureSuits'))#">
            <cfpdfformparam name="ADD-FireExtinguisher" value="#yesNo(ListFindNoCase(agList, 'FireExtinguisher'))#">
            <cfpdfformparam name="ADD-Flashlight" value="#yesNo(ListFindNoCase(agList, 'FlashlightSearchLight'))#">
            <cfpdfformparam name="ADD-Raft" value="#yesNo(ListFindNoCase(agList, 'RaftDinghy'))#">
            <cfpdfformparam name="EPIRB-UIN" value="#uin#">

            <cfpdfformparam name="ADD-FoodAvail" value="#yesNo(isNumeric(food) AND val(food) GT 0)#">
            <cfpdfformparam name="ADD-FoodDays" value="#food#">
            <cfpdfformparam name="ADD-Water" value="#yesNo(isNumeric(water) AND val(water) GT 0)#">
            <cfpdfformparam name="ADD-WaterDays" value="#water#">
            <cfpdfformparam name="ADD-OtherAvail1" value="#yesNo(len(trim(otherAvail1)))#">
            <cfpdfformparam name="ADD-OtherDesc1" value="#otherAvail1#">
            <cfpdfformparam name="ADD-OtherAvail2" value="#yesNo(len(trim(otherAvailB)))#">
            <cfpdfformparam name="ADD-OtherDesc2" value="#otherAvailB#">
            <cfpdfformparam name="ADD-OtherAvail3" value="#yesNo(len(trim(otherAvailC)))#">
            <cfpdfformparam name="ADD-OtherDesc3" value="#otherAvailC#">
            <cfpdfformparam name="ADD-OtherAvail4" value="#yesNo(len(trim(otherAvailD)))#">
            <cfpdfformparam name="ADD-OtherDesc4" value="#otherAvailD#">

            <!-- Operator -->
            <cfpdfformparam name="OPR-Name" value="#oprName#">
            <cfpdfformparam name="OPR-Address" value="#oprAddress#">
            <cfpdfformparam name="OPR-City" value="#oprCity#">
            <cfpdfformparam name="OPR-State" value="#oprState#">
            <cfpdfformparam name="OPR-ZipCode" value="#oprZip#">
            <cfpdfformparam name="OPR-PLBUIN" value="#oprPlbuin#">
            <cfpdfformparam name="OPR-VesselExperience" value="#yesNo(oprVesselExperience EQ 'expWithVessel')#">
            <cfpdfformparam name="OPR-AreaExperience" value="#yesNo(oprAreaExperience EQ 'expWithBoatingArea')#">
            <cfpdfformparam name="OPR-Age" value="#oprAge#">
            <cfpdfformparam name="OPR-Home Phone" value="#oprPhone#">
            <cfpdfformparam name="OPR-Gender" value="#oprGender#">
            <cfpdfformparam name="OPR-VehicleYearMakeModel" value="#oprVehicleYearMakeModel#">
            <cfpdfformparam name="OPR-VehicleLicenseNum" value="#oprVehicleLicenseNum#">
            <cfpdfformparam name="OPR-VehicleParkedAt" value="#oprVehicleParkedAt#">
            <cfpdfformparam name="OPR-VesselTrailored" value="#yesNo(trailer)#">
            <cfpdfformparam name="OPR-Note" value="#oprNotes#">
            <cfpdfformparam name="OPR-Float Plan Note" value="#floatPlanNote#">
            <cfpdfformparam name="OPR-PFD" value="#yesNo(opHasPfd)#">

            <!-- Passengers / crew -->
            <cfset passCnt = 0>
            <cfloop from="1" to="#arrayLen(passengers)#" index="pIdx">
                <cfset passCnt = passCnt + 1>
                <cfset passenger = passengers[pIdx]>
                <cfset num = NumberFormat(passCnt, "00")>
                <cfpdfformparam name="POB-#num#Name" value="#getString(passenger, 'name', '')#">
                <cfpdfformparam name="POB-#num#HomePhone" value="#getString(passenger, 'phone', '')#">
                <cfpdfformparam name="POB-#num#Age" value="#getString(passenger, 'age', '')#">
                <cfpdfformparam name="POB-#num#Gender" value="#Left(getString(passenger, 'gender', ''), 1)#">
                <cfpdfformparam name="POB-#num#PFD" value="#yesNo(isTrueValue(getAny(passenger, 'hasPdf', '')))#">
                <cfpdfformparam name="POB-#num#Note" value="#getString(passenger, 'notes', '')#">
                <cfpdfformparam name="POB-#num#PLBnum" value="#getString(passenger, 'plbuin', '')#">
            </cfloop>

            <!-- Contacts -->
            <cfset contactCnt = 0>
            <cfloop from="1" to="#arrayLen(contacts)#" index="cIdx">
                <cfset contactCnt = contactCnt + 1>
                <cfset contact = contacts[cIdx]>
                <cfpdfformparam name="Contact#contactCnt#" value="#getString(contact, 'name', '')#">
                <cfpdfformparam name="Contact#contactCnt#-Phone" value="#getString(contact, 'phone', '')#">
            </cfloop>

            <cfpdfformparam name="RescueAuthority" value="#rescueAuthority#">
            <cfpdfformparam name="RescueAuthority-Phone" value="#rescueAuthorityPhone#">

            <!-- Waypoints -->
            <cfpdfformparam name="01DepartDate" value="#tripDepartureDate#">
            <cfpdfformparam name="01DepartTime" value="#tripDepartTime#">
            <cfpdfformparam name="01DepartLocation" value="#tripDepartLocation# - Start of Trip">
            <cfpdfformparam name="01DepartMode" value="">

            <cfset waypointCnt = 1>
            <cfloop from="1" to="#arrayLen(waypoints)#" index="wIdx">
                <cfset waypointCnt = waypointCnt + 1>
                <cfset waypoint = waypoints[wIdx]>
                <cfset wpNum = NumberFormat(waypointCnt, "00")>
                <cfset arriveTime = formatTime(getAny(waypoint, "arrival", ""))>
                <cfset departTime = formatTime(getAny(waypoint, "departure", ""))>
                <cfpdfformparam name="#wpNum#ArriveDate" value="#formatDate(getAny(waypoint, 'arrival', ''))#">
                <cfpdfformparam name="#wpNum#ArriveTime" value="#arriveTime#">
                <cfpdfformparam name="#wpNum#DepartDate" value="#formatDate(getAny(waypoint, 'departure', ''))#">
                <cfpdfformparam name="#wpNum#DepartTime" value="#departTime#">
                <cfpdfformparam name="#wpNum#ArriveLocation" value="#getString(waypoint, 'name', '')#">
                <cfpdfformparam name="#wpNum#DepartMode" value="#getString(waypoint, 'departType', '')#">
                <cfpdfformparam name="#wpNum#ArriveReason" value="#getString(waypoint, 'reason', '')#">
            </cfloop>
            <cfset waypointCnt = waypointCnt + 1>
            <cfset endNum = NumberFormat(waypointCnt, "00")>
            <cfpdfformparam name="#endNum#ArriveDate" value="#tripReturnDate#">
            <cfpdfformparam name="#endNum#ArriveTime" value="#tripReturnTime#">
            <cfpdfformparam name="#endNum#ArriveLocation" value="#tripReturnLocation# - End of Trip">
        </cfpdfform>

        <cfpdf
            action="protect"
            source="#destinationPath#"
            destination="#readonlyPath#"
            overwrite="true"
            newownerpassword="#createUUID()#"
            permissions="AllowPrinting,AllowCopy,AllowScreenReaders">

        <cfreturn readonlyFileName>
    </cffunction>

    <cffunction name="loadFloatPlan" access="private" output="false" returntype="struct">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var qPlan = queryExecute(
                "SELECT * FROM floatplans WHERE floatplanId = :planId LIMIT 1",
                { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } },
                { datasource = arguments.datasource }
            );
            return queryRowToStruct(qPlan);
        </cfscript>
    </cffunction>

    <cffunction name="loadVessel" access="private" output="false" returntype="struct">
        <cfargument name="vesselId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            if (arguments.vesselId LTE 0) {
                return {};
            }
            var qVessel = queryExecute(
                "SELECT * FROM vessels WHERE vesselId = :vesselId LIMIT 1",
                { vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" } },
                { datasource = arguments.datasource }
            );
            return queryRowToStruct(qVessel);
        </cfscript>
    </cffunction>

    <cffunction name="loadOperator" access="private" output="false" returntype="struct">
        <cfargument name="operatorId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            if (arguments.operatorId LTE 0) {
                return {};
            }
            var qOperator = queryExecute(
                "SELECT * FROM operators WHERE opId = :operatorId LIMIT 1",
                { operatorId = { value = arguments.operatorId, cfsqltype = "cf_sql_integer" } },
                { datasource = arguments.datasource }
            );
            return queryRowToStruct(qOperator);
        </cfscript>
    </cffunction>

    <cffunction name="loadPassengers" access="private" output="false" returntype="array">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var passengers = [];
            var qPassengers = queryExecute(
                "SELECT fp.passId, fp.hasPdf, p.name, p.phone, p.age, p.gender, p.notes, p.plbuin
                 FROM floatplan_passengers fp
                 LEFT JOIN passengers p ON p.passId = fp.passId
                 WHERE fp.floatplanId = :planId
                 ORDER BY fp.recId ASC",
                { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } },
                { datasource = arguments.datasource }
            );

            for (var i = 1; i LTE qPassengers.recordCount; i++) {
                arrayAppend(passengers, queryRowToStruct(qPassengers, i));
            }
            return passengers;
        </cfscript>
    </cffunction>

    <cffunction name="loadContacts" access="private" output="false" returntype="array">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var contacts = [];
            var qContacts = queryExecute(
                "SELECT fc.contactId, c.name, c.phone
                 FROM floatplan_contacts fc
                 LEFT JOIN contacts c ON c.contactId = fc.contactId
                 WHERE fc.floatplanId = :planId
                 ORDER BY fc.recId ASC",
                { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } },
                { datasource = arguments.datasource }
            );

            for (var i = 1; i LTE qContacts.recordCount; i++) {
                arrayAppend(contacts, queryRowToStruct(qContacts, i));
            }
            return contacts;
        </cfscript>
    </cffunction>

    <cffunction name="loadWaypoints" access="private" output="false" returntype="array">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var waypoints = [];
            var qWaypoints = queryExecute(
                "SELECT fw.wayPointId, fw.reason, fw.departType, fw.arrival, fw.departure, w.name
                 FROM floatplan_waypoints fw
                 LEFT JOIN waypoints w ON w.wpId = fw.wayPointId
                 WHERE fw.floatplanId = :planId
                 ORDER BY fw.recId ASC",
                { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } },
                { datasource = arguments.datasource }
            );

            for (var i = 1; i LTE qWaypoints.recordCount; i++) {
                arrayAppend(waypoints, queryRowToStruct(qWaypoints, i));
            }
            return waypoints;
        </cfscript>
    </cffunction>

    <cffunction name="queryRowToStruct" access="private" output="false" returntype="struct">
        <cfargument name="qry" type="query" required="true">
        <cfargument name="row" type="numeric" required="false" default="1">
        <cfscript>
            var result = {};
            if (arguments.qry.recordCount LT arguments.row) {
                return result;
            }
            var cols = listToArray(arguments.qry.columnList);
            for (var i = 1; i LTE arrayLen(cols); i++) {
                var col = cols[i];
                result[col] = arguments.qry[col][arguments.row];
            }
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getString" access="private" output="false" returntype="string">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="string" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.source, arguments.key) AND NOT isNull(arguments.source[arguments.key])) {
                return toString(arguments.source[arguments.key]);
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="getNumeric" access="private" output="false" returntype="numeric">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="numeric" required="false" default="0">
        <cfscript>
            if (structKeyExists(arguments.source, arguments.key) AND isNumeric(arguments.source[arguments.key])) {
                return val(arguments.source[arguments.key]);
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="getAny" access="private" output="false" returntype="any">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.source, arguments.key)) {
                return arguments.source[arguments.key];
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="formatDate" access="private" output="false" returntype="string">
        <cfargument name="value" required="true">
        <cfscript>
            if (isDate(arguments.value)) {
                return dateFormat(arguments.value, "mm/dd/yyyy");
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="formatTime" access="private" output="false" returntype="string">
        <cfargument name="value" required="true">
        <cfscript>
            if (isDate(arguments.value)) {
                return timeFormat(arguments.value, "HH:mm");
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="normalizeGender" access="private" output="false" returntype="string">
        <cfargument name="gender" type="string" required="true">
        <cfscript>
            var value = lcase(trim(arguments.gender));
            if (value EQ "male") {
                return "M";
            }
            if (value EQ "female") {
                return "F";
            }
            if (len(arguments.gender) EQ 1) {
                return ucase(arguments.gender);
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="yesNo" access="private" output="false" returntype="string">
        <cfargument name="value" required="true">
        <cfscript>
            return isTrueValue(arguments.value) ? "Yes" : "No";
        </cfscript>
    </cffunction>

    <cffunction name="isTrueValue" access="private" output="false" returntype="boolean">
        <cfargument name="value" required="true">
        <cfscript>
            if (isBoolean(arguments.value)) {
                return arguments.value;
            }
            if (isNumeric(arguments.value)) {
                return val(arguments.value) GT 0;
            }
            if (isSimpleValue(arguments.value)) {
                var text = lcase(trim(toString(arguments.value)));
                return listFindNoCase("yes,true,1,y", text) GT 0;
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="buildYearMakeModel" access="private" output="false" returntype="string">
        <cfargument name="vessel" type="struct" required="true">
        <cfscript>
            var yearBuilt = getString(arguments.vessel, "yearBuilt", "");
            var make = getString(arguments.vessel, "make", "");
            var model = getString(arguments.vessel, "model", "");
            var combined = joinNonEmpty([yearBuilt, make, model], " - ");
            return combined;
        </cfscript>
    </cffunction>

    <cffunction name="joinNonEmpty" access="private" output="false" returntype="string">
        <cfargument name="values" type="array" required="true">
        <cfargument name="separator" type="string" required="true">
        <cfscript>
            var cleaned = [];
            for (var i = 1; i LTE arrayLen(arguments.values); i++) {
                var item = trim(toString(arguments.values[i]));
                if (len(item)) {
                    arrayAppend(cleaned, item);
                }
            }
            return arrayLen(cleaned) ? arrayToList(cleaned, arguments.separator) : "";
        </cfscript>
    </cffunction>
</cfcomponent>
