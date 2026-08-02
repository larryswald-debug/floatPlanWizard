<cfcomponent displayname="floatPlanUtils" output="false" hint="Generate Float Plan PDFs">
    <cffunction name="init" access="public" output="false" returntype="any">
        <cfreturn this>
    </cffunction>

    <cffunction name="createPDF" access="public" output="false" returntype="any" hint="Populate an owner-authorized float plan PDF and save it outside the public web root">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var ds = "fpw";
            var baseDir = getDirectoryFromPath(getCurrentTemplatePath());
            var templatePath = baseDir & "USCGFloatPlan_new.pdf";
            var continuationTemplatePath = baseDir & "USCGFloatPlan_itinerary_continuation.pdf";
            var outputDir = getPdfOutputDirectory();

            if (arguments.floatPlanId LTE 0 OR arguments.userId LTE 0) {
                appendFpwPdfLog("warning", "createPDF rejected invalid owner context floatPlanId=#arguments.floatPlanId# userId=#arguments.userId#");
                return false;
            }

            appendFpwPdfLog("information", "createPDF start floatPlanId=#arguments.floatPlanId# userId=#arguments.userId# baseDir=#baseDir# templatePath=#templatePath# outputDir=#outputDir#");

            var preparationStage = "output-directory-check";
            var plan = {};
            var planName = "";
            var safePlanName = "";
            var stamp = "";
            var requestToken = "";
            var fileName = "";
            var destinationPath = "";
            var readonlyFileName = "";
            var readonlyPath = "";
            var vessel = {};
            var operatorInfo = {};
            var passengers = [];
            var contacts = [];
            var waypoints = [];
            var basicDetails = {};

            try {
                preparationStage = "output-directory-check";
                if (!directoryExists(outputDir)) {
                    appendFpwPdfLog("information", "createPDF outputDir missing; creating #outputDir#");
                    preparationStage = "output-directory-create";
                    directoryCreate(outputDir);
                }

                preparationStage = "template-check";
                if (!fileExists(templatePath)) {
                    appendFpwPdfLog("error", "createPDF template missing at #templatePath#");
                }

                preparationStage = "plan-load";
                plan = loadFloatPlan(arguments.floatPlanId, arguments.userId, ds);
                if (structIsEmpty(plan)) {
                    appendFpwPdfLog("error", "createPDF no owner-scoped plan found for floatPlanId=#arguments.floatPlanId# userId=#arguments.userId#");
                    return false;
                }

                preparationStage = "output-path-build";
                planName = getString(plan, "floatPlanName", "floatplan");
                safePlanName = reReplace(planName, "[^A-Za-z0-9_-]+", "_", "all");
                stamp = dateFormat(now(), "yyyymmdd") & "_" & timeFormat(now(), "HHmmss");
                requestToken = left(lCase(replace(createUUID(), "-", "", "all")), 12);
                fileName = safePlanName & "_" & stamp & "_" & requestToken & ".pdf";
                destinationPath = outputDir & "/" & fileName;
                readonlyFileName = reReplace(fileName, "\.pdf$", "_readonly.pdf", "all");
                if (readonlyFileName EQ fileName) {
                    readonlyFileName = fileName & "_readonly";
                }
                readonlyPath = outputDir & "/" & readonlyFileName;

                preparationStage = "vessel-load";
                vessel = loadVessel(getNumeric(plan, "vesselId", 0), arguments.userId, ds);
                preparationStage = "operator-load";
                operatorInfo = loadOperator(getNumeric(plan, "operatorId", 0), arguments.userId, ds);
                preparationStage = "passenger-load";
                passengers = loadPassengers(arguments.floatPlanId, arguments.userId, ds);
                preparationStage = "contact-load";
                contacts = loadContacts(arguments.floatPlanId, arguments.userId, ds);
                preparationStage = "waypoint-load";
                waypoints = loadWaypoints(arguments.floatPlanId, arguments.userId, ds);
                preparationStage = "basic-details-load";
                basicDetails = loadBasicDetails(arguments.floatPlanId, ds);
            } catch (any preparationError) {
                var preparationErrorType = "";
                var preparationErrorMessage = "";
                var preparationErrorDetail = "";
                var preparationErrorTemplate = "";
                var preparationErrorLine = 0;
                if (structKeyExists(preparationError, "type") AND !isNull(preparationError.type)) {
                    preparationErrorType = toString(preparationError.type);
                }
                if (structKeyExists(preparationError, "message") AND !isNull(preparationError.message)) {
                    preparationErrorMessage = toString(preparationError.message);
                }
                if (structKeyExists(preparationError, "detail") AND !isNull(preparationError.detail)) {
                    preparationErrorDetail = toString(preparationError.detail);
                }
                if (
                    structKeyExists(preparationError, "tagContext")
                    AND isArray(preparationError.tagContext)
                    AND arrayLen(preparationError.tagContext)
                ) {
                    if (
                        structKeyExists(preparationError.tagContext[1], "template")
                        AND !isNull(preparationError.tagContext[1].template)
                    ) {
                        preparationErrorTemplate = toString(preparationError.tagContext[1].template);
                    }
                    if (
                        structKeyExists(preparationError.tagContext[1], "line")
                        AND isNumeric(preparationError.tagContext[1].line)
                    ) {
                        preparationErrorLine = val(preparationError.tagContext[1].line);
                    }
                }
                appendFpwPdfLog(
                    "error",
                    "createPDF preparation ERROR floatPlanId=#arguments.floatPlanId# userId=#arguments.userId# stage=#preparationStage# type=#left(preparationErrorType, 250)# msg=#left(preparationErrorMessage, 1000)# detail=#left(preparationErrorDetail, 1000)# template=#left(preparationErrorTemplate, 500)# line=#preparationErrorLine#"
                );
                rethrow;
            }
            var routeItinerary = {};
            var itineraryFields = {};
            var continuationPaths = [];
            var continuationPageLegs = [];
            var continuationFieldValues = {};
            var continuationPageIndex = 0;
            var cleanupIndex = 0;
            var continuationPath = "";
            var assembledPath = "";
            var protectionSourcePath = destinationPath;

            appendFpwPdfLog("information", "createPDF writing destinationPath=#destinationPath# readonlyPath=#readonlyPath#");

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

	            if (!structIsEmpty(basicDetails)) {
	                vesselName = getString(basicDetails, "vessel_name", vesselName);
	                oprName = getString(basicDetails, "operator_name", oprName);
	                email = getString(basicDetails, "captain_email", email);
	                tripDepartLocation = getString(basicDetails, "launch_location", tripDepartLocation);
	                tripReturnLocation = getString(basicDetails, "launch_location", tripReturnLocation);
	                rescueAuthority = getString(basicDetails, "authority_name_snapshot", rescueAuthority);
	                rescueAuthorityPhone = getString(basicDetails, "authority_phone_snapshot", rescueAuthorityPhone);
	                contacts = [{
	                    name = getString(basicDetails, "notification_contact_name", ""),
	                    phone = getString(basicDetails, "notification_contact_phone", "")
	                }];
	                if (len(getString(basicDetails, "destination_location", ""))) {
	                    var basicDestinationWaypoint = {
	                        name = getString(basicDetails, "destination_location", ""),
	                        reason = "Destination / turnaround point",
	                        departType = "planned",
	                        arrival = "",
	                        departure = ""
	                    };
	                    if (arrayLen(waypoints)) {
	                        arrayInsertAt(waypoints, 1, basicDestinationWaypoint);
	                    } else {
	                        arrayAppend(waypoints, basicDestinationWaypoint);
	                    }
	                }
	            }

            try {
                routeItinerary = createFloatPlanPdfItineraryService(ds).getItinerary(arguments.floatPlanId);
            } catch (any itineraryErr) {
                appendFpwPdfLog(
                    "error",
                    "createPDF itinerary ERROR floatPlanId=#arguments.floatPlanId# msg=#itineraryErr.message# detail=#itineraryErr.detail#"
                );
                rethrow;
            }

            for (var itineraryWarningIndex = 1; itineraryWarningIndex LTE arrayLen(routeItinerary.warnings); itineraryWarningIndex++) {
                var itineraryWarning = routeItinerary.warnings[itineraryWarningIndex];
                appendFpwPdfLog(
                    "warning",
                    "createPDF itinerary warning floatPlanId=#arguments.floatPlanId# routeInstanceId=#getNumeric(routeItinerary, 'routeInstanceId', 0)# code=#getString(itineraryWarning, 'code', '')# routeLegOrder=#getNumeric(itineraryWarning, 'routeLegOrder', 0)# message=#getString(itineraryWarning, 'message', '')#"
                );
            }

            itineraryFields = buildOfficialItineraryFields(
                routeItinerary = routeItinerary,
                waypoints = waypoints,
                tripDepartureDate = tripDepartureDate,
                tripDepartTime = tripDepartTime,
                tripDepartLocation = tripDepartLocation,
                tripReturnDate = tripReturnDate,
                tripReturnTime = tripReturnTime,
                tripReturnLocation = tripReturnLocation
            );
	        </cfscript>

        <cftry>
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

            <!-- Canonical itinerary fields are initialized blank before any route or legacy values are applied. -->
            <cfloop collection="#itineraryFields#" item="itineraryFieldName">
                <cfpdfformparam name="#itineraryFieldName#" value="#itineraryFields[itineraryFieldName]#">
            </cfloop>
        </cfpdfform>

        <cfif routeItinerary.isRouteBacked AND arrayLen(routeItinerary.continuationPages)>
            <cfif NOT fileExists(continuationTemplatePath)>
                <cfthrow
                    type="FloatPlanPdfItinerary.ContinuationTemplateMissing"
                    message="The itinerary continuation PDF template is missing."
                    detail="templatePath=#continuationTemplatePath#">
            </cfif>

            <cfloop from="1" to="#arrayLen(routeItinerary.continuationPages)#" index="continuationPageIndex">
                <cfset continuationPageLegs = routeItinerary.continuationPages[continuationPageIndex]>
                <cfset continuationFieldValues = buildContinuationFieldValues(
                    routeItinerary = routeItinerary,
                    pageLegs = continuationPageLegs,
                    pageNumber = continuationPageIndex,
                    pageCount = arrayLen(routeItinerary.continuationPages)
                )>
                <cfset continuationPath = outputDir & "/." & safePlanName & "_" & replace(createUUID(), "-", "", "all") & "_continuation_" & continuationPageIndex & ".pdf">

                <cfpdfform
                    action="populate"
                    source="#continuationTemplatePath#"
                    destination="#continuationPath#"
                    overwrite="true">
                    <cfloop collection="#continuationFieldValues#" item="continuationFieldName">
                        <cfpdfformparam name="#continuationFieldName#" value="#continuationFieldValues[continuationFieldName]#">
                    </cfloop>
                </cfpdfform>
                <cfset arrayAppend(continuationPaths, continuationPath)>
            </cfloop>

            <cfset assembledPath = outputDir & "/." & safePlanName & "_" & replace(createUUID(), "-", "", "all") & "_assembled.pdf">
            <cfpdf action="merge" destination="#assembledPath#" overwrite="true">
                <cfpdfparam source="#destinationPath#" pages="1-2">
                <cfloop from="1" to="#arrayLen(continuationPaths)#" index="continuationPageIndex">
                    <cfpdfparam source="#continuationPaths[continuationPageIndex]#">
                </cfloop>
                <cfpdfparam source="#destinationPath#" pages="3">
            </cfpdf>
            <cfset protectionSourcePath = assembledPath>
        </cfif>

        <cfpdf
            action="protect"
            source="#protectionSourcePath#"
            destination="#readonlyPath#"
            overwrite="true"
            newownerpassword="#createUUID()#"
            permissions="AllowPrinting,AllowCopy,AllowScreenReaders">

        <cfscript>
            if (len(assembledPath) AND fileExists(assembledPath)) {
                if (fileExists(destinationPath)) {
                    fileDelete(destinationPath);
                }
                fileMove(assembledPath, destinationPath);
                assembledPath = "";
            }
            if (fileExists(destinationPath)) {
                fileDelete(destinationPath);
            }
            appendFpwPdfLog(
                "information",
                "createPDF complete readonlyFile=#readonlyFileName# routeLegCount=#arrayLen(routeItinerary.legs)# continuationPageCount=#arrayLen(routeItinerary.continuationPages)# sourceExists=#fileExists(destinationPath)# readonlyExists=#fileExists(readonlyPath)#"
            );
        </cfscript>
        <cfcatch type="any">
            <cfscript>
                appendFpwPdfLog("error", "createPDF ERROR floatPlanId=#arguments.floatPlanId# msg=#cfcatch.message# detail=#cfcatch.detail#");
            </cfscript>
            <cfthrow message="#cfcatch.message#" detail="#cfcatch.detail#">
        </cfcatch>
        <cffinally>
            <cfif len(assembledPath) AND fileExists(assembledPath)>
                <cffile action="delete" file="#assembledPath#">
            </cfif>
            <cfloop from="1" to="#arrayLen(continuationPaths)#" index="cleanupIndex">
                <cfif fileExists(continuationPaths[cleanupIndex])>
                    <cffile action="delete" file="#continuationPaths[cleanupIndex]#">
                </cfif>
            </cfloop>
        </cffinally>
        </cftry>

        <cfreturn readonlyFileName>
    </cffunction>

    <cffunction name="createFloatPlanPdfItineraryService" access="private" output="false" returntype="any">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            try {
                return createObject("component", "fpw.api.api_assets.FloatPlanPdfItineraryService").init(arguments.datasource);
            } catch (any primaryPathErr) {
                return createObject("component", "api.api_assets.FloatPlanPdfItineraryService").init(arguments.datasource);
            }
        </cfscript>
    </cffunction>

    <cffunction name="buildOfficialItineraryFields" access="private" output="false" returntype="struct">
        <cfargument name="routeItinerary" type="struct" required="true">
        <cfargument name="waypoints" type="array" required="true">
        <cfargument name="tripDepartureDate" type="string" required="true">
        <cfargument name="tripDepartTime" type="string" required="true">
        <cfargument name="tripDepartLocation" type="string" required="true">
        <cfargument name="tripReturnDate" type="string" required="true">
        <cfargument name="tripReturnTime" type="string" required="true">
        <cfargument name="tripReturnLocation" type="string" required="true">
        <cfscript>
            var fields = initializeOfficialItineraryFields();
            var i = 0;
            var stopNumber = 0;
            var stopPrefix = "";
            var leg = {};
            var nextLeg = {};
            var waypoint = {};
            var lastStopNumber = 1;

            if (
                arguments.routeItinerary.isRouteBacked
                AND arrayLen(arguments.routeItinerary.legs)
            ) {
                fields["01DepartDate"] = arguments.routeItinerary.legs[1].departureDate;
                fields["01DepartTime"] = arguments.routeItinerary.legs[1].departureTime;
                fields["01DepartLocation"] = arguments.routeItinerary.legs[1].origin;

                for (i = 1; i LTE arrayLen(arguments.routeItinerary.officialLegs); i++) {
                    leg = arguments.routeItinerary.officialLegs[i];
                    stopNumber = i + 1;
                    stopPrefix = numberFormat(stopNumber, "00");
                    fields[stopPrefix & "ArriveDate"] = leg.arrivalDate;
                    fields[stopPrefix & "ArriveTime"] = leg.arrivalTime;
                    fields[stopPrefix & "ArriveLocation"] = leg.destination;

                    if (
                        stopNumber LTE 20
                        AND i LT arrayLen(arguments.routeItinerary.legs)
                    ) {
                        nextLeg = arguments.routeItinerary.legs[i + 1];
                        fields[stopPrefix & "DepartDate"] = nextLeg.departureDate;
                        fields[stopPrefix & "DepartTime"] = nextLeg.departureTime;
                    }
                }
                return fields;
            }

            fields["01DepartDate"] = arguments.tripDepartureDate;
            fields["01DepartTime"] = arguments.tripDepartTime;
            fields["01DepartLocation"] = arguments.tripDepartLocation & " - Start of Trip";

            for (i = 1; i LTE min(19, arrayLen(arguments.waypoints)); i++) {
                waypoint = arguments.waypoints[i];
                stopNumber = i + 1;
                stopPrefix = numberFormat(stopNumber, "00");
                fields[stopPrefix & "ArriveDate"] = formatDate(getAny(waypoint, "arrival", ""));
                fields[stopPrefix & "ArriveTime"] = formatTime(getAny(waypoint, "arrival", ""));
                fields[stopPrefix & "ArriveLocation"] = getString(waypoint, "name", "");
                fields[stopPrefix & "ArriveReason"] = getString(waypoint, "reason", "");
                fields[stopPrefix & "DepartDate"] = formatDate(getAny(waypoint, "departure", ""));
                fields[stopPrefix & "DepartTime"] = formatTime(getAny(waypoint, "departure", ""));
                fields[stopPrefix & "DepartMode"] = getString(waypoint, "departType", "");
                lastStopNumber = stopNumber;
            }

            if (lastStopNumber LT 21) {
                stopNumber = lastStopNumber + 1;
                stopPrefix = numberFormat(stopNumber, "00");
                fields[stopPrefix & "ArriveDate"] = arguments.tripReturnDate;
                fields[stopPrefix & "ArriveTime"] = arguments.tripReturnTime;
                fields[stopPrefix & "ArriveLocation"] = arguments.tripReturnLocation & " - End of Trip";
            }
            return fields;
        </cfscript>
    </cffunction>

    <cffunction name="initializeOfficialItineraryFields" access="private" output="false" returntype="struct">
        <cfscript>
            var fields = {
                "01DepartDate" = "",
                "01DepartTime" = "",
                "01DepartLocation" = "",
                "01DepartMode" = ""
            };
            var stopNumber = 0;
            var stopPrefix = "";

            for (stopNumber = 2; stopNumber LTE 21; stopNumber++) {
                stopPrefix = numberFormat(stopNumber, "00");
                fields[stopPrefix & "ArriveDate"] = "";
                fields[stopPrefix & "ArriveTime"] = "";
                fields[stopPrefix & "ArriveLocation"] = "";
                fields[stopPrefix & "ArriveReason"] = "";
                fields[stopPrefix & "ArriveCheckinTime"] = "";
                if (stopNumber LTE 20) {
                    fields[stopPrefix & "DepartDate"] = "";
                    fields[stopPrefix & "DepartTime"] = "";
                    fields[stopPrefix & "DepartMode"] = "";
                }
            }
            return fields;
        </cfscript>
    </cffunction>

    <cffunction name="buildContinuationFieldValues" access="private" output="false" returntype="struct">
        <cfargument name="routeItinerary" type="struct" required="true">
        <cfargument name="pageLegs" type="array" required="true">
        <cfargument name="pageNumber" type="numeric" required="true">
        <cfargument name="pageCount" type="numeric" required="true">
        <cfscript>
            var fields = {
                "CONT-PlanName" = arguments.routeItinerary.planName,
                "CONT-FloatPlanId" = toString(arguments.routeItinerary.floatPlanId),
                "CONT-RouteInstanceId" = toString(arguments.routeItinerary.routeInstanceId),
                "CONT-Timezone" = arguments.routeItinerary.timezone,
                "CONT-PageNumber" = toString(arguments.pageNumber),
                "CONT-PageCount" = toString(arguments.pageCount)
            };
            var rowIndex = 0;
            var rowPrefix = "";
            var leg = {};

            for (rowIndex = 1; rowIndex LTE 20; rowIndex++) {
                rowPrefix = "CONT-" & numberFormat(rowIndex, "00") & "-";
                fields[rowPrefix & "Leg"] = "";
                fields[rowPrefix & "Origin"] = "";
                fields[rowPrefix & "DepartDate"] = "";
                fields[rowPrefix & "DepartTime"] = "";
                fields[rowPrefix & "Destination"] = "";
                fields[rowPrefix & "ArriveDate"] = "";
                fields[rowPrefix & "ArriveTime"] = "";

                if (rowIndex LTE arrayLen(arguments.pageLegs)) {
                    leg = arguments.pageLegs[rowIndex];
                    fields[rowPrefix & "Leg"] = toString(leg.routeLegOrder);
                    fields[rowPrefix & "Origin"] = leg.origin;
                    fields[rowPrefix & "DepartDate"] = leg.departureDate;
                    fields[rowPrefix & "DepartTime"] = leg.departureTime;
                    fields[rowPrefix & "Destination"] = leg.destination;
                    fields[rowPrefix & "ArriveDate"] = leg.arrivalDate;
                    fields[rowPrefix & "ArriveTime"] = leg.arrivalTime;
                }
            }
            return fields;
        </cfscript>
    </cffunction>

    <cffunction name="getPdfPath" access="public" output="false" returntype="string" hint="Return absolute path to a generated float plan PDF">
        <cfargument name="fileName" type="string" required="true">
        <cfscript>
            var requestedName = trim(arguments.fileName);
            var safeName = getFileFromPath(replace(requestedName, "\", "/", "all"));
            if (!len(safeName) OR safeName NEQ requestedName) {
                throw(type = "FPW.InvalidPdfFileName", message = "Invalid generated PDF file name.");
            }
            return getPdfOutputDirectory() & "/" & safeName;
        </cfscript>
    </cffunction>

    <cffunction name="getPdfOutputDirectory" access="private" output="false" returntype="string">
        <cfscript>
            // Production Java policy blocks ColdFusion's Catalina temp directory.
            // Reuse the established application-owned PDF directory.
            var outputDir = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\", "/", "all");
            if (right(outputDir, 1) NEQ "/") {
                outputDir &= "/";
            }
            return outputDir & "floatPlans/user_float_plans";
        </cfscript>
    </cffunction>

    <cffunction name="appendFpwPdfLog" access="private" output="false" returntype="void">
        <cfargument name="type" type="string" required="true">
        <cfargument name="text" type="string" required="true">
        <cfscript>
            var componentDir = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\", "/", "all");
            var logDirectory = reReplace(componentDir, "/api/api_assets/?$", "/logs", "one");
            var logFile = logDirectory & "/fpw_pdf.log";
            var logLine = "FPW_PDF_LOG ts=#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')# type=#trim(arguments.type)# message=#trim(arguments.text)#";
        </cfscript>
        <cftry>
            <cfif NOT directoryExists(logDirectory)>
                <cfdirectory action="create" directory="#logDirectory#">
            </cfif>
            <cffile action="append" file="#logFile#" output="#logLine#" addnewline="true" charset="utf-8">
            <cfcatch type="any">
                <cflog file="fpw-errors" type="error" text="FPW_PDF_LOG_FAILED message=#toString(cfcatch.message)# detail=#toString(cfcatch.detail)# originalType=#arguments.type# originalText=#left(arguments.text, 1000)#">
            </cfcatch>
        </cftry>
    </cffunction>

	    <cffunction name="loadFloatPlan" access="private" output="false" returntype="struct">
	        <cfargument name="floatPlanId" type="numeric" required="true">
	        <cfargument name="userId" type="numeric" required="true">
	        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var qPlan = queryExecute(
                "SELECT fp.*
                   FROM floatplans fp
                   LEFT JOIN route_instances ri
                     ON ri.id = fp.route_instance_id
                    AND ri.user_id = :routeUserId
                  WHERE fp.floatplanId = :planId
                    AND fp.userId = :planUserId
                    AND (fp.route_instance_id IS NULL OR ri.id IS NOT NULL)
                  LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    planUserId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
                    routeUserId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = arguments.datasource }
            );
            return queryRowToStruct(qPlan);
	        </cfscript>
	    </cffunction>

	    <cffunction name="loadBasicDetails" access="private" output="false" returntype="struct">
	        <cfargument name="floatPlanId" type="numeric" required="true">
	        <cfargument name="datasource" type="string" required="true">
	        <cfscript>
	            var qDetails = queryNew("");
	        </cfscript>
	        <cftry>
	            <cfquery name="qDetails" datasource="#arguments.datasource#">
	                SELECT *
	                  FROM floatplan_basic_details
	                 WHERE floatplan_id = <cfqueryparam value="#arguments.floatPlanId#" cfsqltype="cf_sql_integer">
	                 LIMIT 1
	            </cfquery>
	            <cfreturn queryRowToStruct(qDetails)>
	            <cfcatch type="any">
	                <cfreturn {}>
	            </cfcatch>
	        </cftry>
	    </cffunction>

	    <cffunction name="loadVessel" access="private" output="false" returntype="struct">
        <cfargument name="vesselId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            if (arguments.vesselId LTE 0) {
                return {};
            }
            var qVessel = queryExecute(
                "SELECT *
                   FROM vessels
                  WHERE vesselId = :vesselId
                    AND userId = :userId
                  LIMIT 1",
                {
                    vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = arguments.datasource }
            );
            return queryRowToStruct(qVessel);
        </cfscript>
    </cffunction>

    <cffunction name="loadOperator" access="private" output="false" returntype="struct">
        <cfargument name="operatorId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            if (arguments.operatorId LTE 0) {
                return {};
            }
            var qOperator = queryExecute(
                "SELECT *
                   FROM operators
                  WHERE opId = :operatorId
                    AND userId = :userId
                  LIMIT 1",
                {
                    operatorId = { value = arguments.operatorId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = arguments.datasource }
            );
            return queryRowToStruct(qOperator);
        </cfscript>
    </cffunction>

    <cffunction name="loadPassengers" access="private" output="false" returntype="array">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var passengers = [];
            var qPassengers = queryExecute(
                "SELECT fp.passId, fp.hasPdf, p.name, p.phone, p.age, p.gender, p.notes, p.plbuin
                 FROM floatplan_passengers fp
                 INNER JOIN passengers p
                   ON p.passId = fp.passId
                  AND p.userId = :userId
                 INNER JOIN floatplans ownerPlan
                   ON ownerPlan.floatplanId = fp.floatplanId
                  AND ownerPlan.userId = :userId
                 WHERE fp.floatplanId = :planId
                 ORDER BY fp.recId ASC",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
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
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var contacts = [];
            var qContacts = queryExecute(
                "SELECT fc.contactId, c.name, c.phone
                 FROM floatplan_contacts fc
                 INNER JOIN contacts c
                   ON c.contactId = fc.contactId
                  AND c.userId = :userId
                 INNER JOIN floatplans ownerPlan
                   ON ownerPlan.floatplanId = fc.floatplanId
                  AND ownerPlan.userId = :userId
                 WHERE fc.floatplanId = :planId
                 ORDER BY fc.recId ASC",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
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
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var waypoints = [];
            var qWaypoints = queryExecute(
                "SELECT fw.wayPointId, fw.reason, fw.departType, fw.arrival, fw.departure, w.name
                 FROM floatplan_waypoints fw
                 INNER JOIN waypoints w
                   ON w.wpId = fw.wayPointId
                  AND w.userId = :userId
                 INNER JOIN floatplans ownerPlan
                   ON ownerPlan.floatplanId = fw.floatplanId
                  AND ownerPlan.userId = :userId
                 WHERE fw.floatplanId = :planId
                 ORDER BY fw.recId ASC",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
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
