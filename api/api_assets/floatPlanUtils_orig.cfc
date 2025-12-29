<cfcomponent displayname="floatPlanUtils" output="false" hint="I create the float plan pdf">
	<cfset datasource = 'floatPlan'>
	<cffunction name="init" access="remote" output="false" hint="I am the class constructor">		
		<cfreturn this>		
	</cffunction>
	
	<cffunction name="optOutOfFloatPlan" access="remote" output="false" >
		<cfargument name="fpid" required="true" > 
		<cfargument name="email" required="true" > 
		<cfset var boolSuccess = true>
		<!--- we need to get the contact id --->		
		<cfset contactId = getContactId(arguments.email, arguments.fpid)>
		<cfset contactId = contactId.contactId>
		<!--- now that we have the contact Id we need to delte them from floatPlan_contacts using contactId and float plan id --->
		<cfset fpDAO = createObject('component','data.dataAccess.floatPlanDAO').init() />
		<cfset deleteFloatPlanContact= fpDAO.deleteFloatPlanContact(fpid = arguments.fpid, contactId = contactId)>	
		<!--- now we will send an email to the float plan owner to let them know of the opt out --->
		<cfset optout = sendFloatPlan(floatPlanId = arguments.fpid, whenToSend = 'now', messageType = 'optOutContact', email = '#arguments.email#')>	
		<cfif NOT optout>
			<cfset var boolSuccess = false>
		</cfif>		
		<cfreturn boolSuccess>		
	</cffunction>
	
	<cffunction name="checkFloatPlanStatus" access="remote" output="false" >
		<cfargument name="fpid" required="true" >
		<cfset objFpDAO = createObject('component','data.dataAccess.floatPlanDAO').init() />
		<cfreturn  objFpDAO.getFloatPlanStatus(arguments.fpid)>		
	</cffunction>
	
	<cffunction name="getContactId" access="remote" output="false" >
		<cfargument name="emailAddress" required="true" />
		<cfargument name="fpid" required="true" />
		<!--- get the contacts id from te dao --->
		<cfset contactDAO = createObject('component','data.dataAccess.contactDAO').init() />
		<cfreturn  contactDAO.getContactIDbyEmail(arguments.emailAddress, arguments.fpid)>	
	</cffunction>
	
	<cffunction name="convertToServerTime" access="remote" output="false" hint="converts a valid date object to server time" >
		<cfargument name="tStamp" type="date" required="true" hint="The date to be converted">
		<cfargument name="tZone" type="string" required="true" hint="the time zone of the date to be converted">	
		<cfscript>
			var objFloatPlanSvc = createObject('component','data.dataAccess.floatPlanService').init();			
		</cfscript>
		<cfswitch expression="#arguments.tZone#" >
			<cfcase value="Eastern" >
				<cfset offset = -1>				
			</cfcase>
			<cfcase value="Central" >
				<cfset offset = 0>				
			</cfcase>
			<cfcase value="Mountain" >
				<cfset offset = +1>				
			</cfcase>
			<cfcase value="Pacific" >
				<cfset offset = +2>				
			</cfcase>
			<cfcase value="Hawaii-Aleutian" >
				<cfset offset = +5>				
			</cfcase>
			<cfcase value="Alaskan" >
				<cfset offset = +3>				
			</cfcase>			
			<cfcase value="Puerto Rico" >
				<cfset offset = -1>				
			</cfcase>			
			<cfcase value="American Samoa" >
				<cfset offset = +6>				
			</cfcase>
			<cfcase value="Guam" >
				<cfset offset = +9>				
			</cfcase>
			<cfcase value="Northern Mariana Islands" >
				<cfset offset = +9>				
			</cfcase>
			<cfdefaultcase>
				<cfset offset = 0>	
			</cfdefaultcase>		      	
		</cfswitch>		
		<cfif isDateObject(arguments.tStamp)>
			<cfset serverDT = DateAdd("h",offset, arguments.tStamp)>
		<cfelseif isDate(arguments.tStamp)>
			<cfset newDate = CreateODBCDateTime(arguments.tStamp)>
			<cfset serverDT = DateAdd("h",offset, newDate)>
		<cfelse>
			<cfreturn false>
			<cfabort>
		</cfif>		
		<cfreturn serverDT>
	</cffunction>
	
	<cffunction name="populatFloatPlanGrid" access="remote" output="false" returnformat="JSON" >
		<cfargument name="userId" required="true" /> 
		<cfset objFloatPlanSvc = createObject('component','data.dataAccess.floatPlanService').init() />
		<cfset qFloatPlans = objFloatPlanSvc.filterByUserId(arguments.userId)>		
		<!--- Define variables --->
		<cfset var data="">
		<cfset var result=ArrayNew(1)>	
		<!--- Build result array --->
		<cfloop query="qFloatPlans">
			<cfset returnStruct = StructNew() />
			<cfset returnStruct["floatPlanId"] = qFloatPlans.floatPlanId />
			<cfset returnStruct["Float Plan Name"] = qFloatPlans.floatPlanName />		
			<cfset returnStruct["Departing"] = qFloatPlans.departureTime />	
			<cfset returnStruct["Returning"] = qFloatPlans.returnTime />	
			<cfset returnStruct["Status"] = qFloatPlans.status />	
			<cfset ArrayAppend(result,returnStruct) />
		</cfloop>		
		<!--- And return it --->
		<cfreturn result />	
	</cffunction>
	
	<cffunction name="cloneFloatPlan" access="remote" output="false" hint="clones an existing float plan">
		<cfargument name="floatPlanId" required="true" />
		<cfargument name="floatPlanName" required="false" default="" />
		<cfif arguments.floatPlanName EQ ''>
			<cfset arguments.floatPlanName = '#DateFormat(now(),'yyyymmdd')#_#CreateUUID()#'>
		</cfif>
		<!--- initiate objects --->
		<cfset objFpService = createObject('component','data.dataAccess.floatPlanService').init() />
		<cfset objFpDAO = createObject('component','data.dataAccess.floatPlanDAO').init() />
		<cfset dupFpid = objFpDAO.duplicateFloatPlan(arguments.floatPlanId, arguments.floatPlanName)>
		<cfset openFp =  objFpDAO.updateFloatPlanStatus(dupFpid,'Open')>		
		<cfreturn dupFpid>
	</cffunction>
	
	<cffunction name="closeFloatPlan" access="remote" output="false" >
		<cfargument name="fpid" required="true" />
		<cfset objFpDAO = createObject('component','data.dataAccess.floatPlanDAO').init() />
		<cfset closeFp =  objFpDAO.updateFloatPlanStatus(arguments.fpid,'Open')>
		<cfset sendEmail = sendFloatPlan(floatPlanId = arguments.fpid, whenToSend = 'now', messageType = 'closed')>	
		<cfreturn closeFp>	
	</cffunction>
	
	<cffunction name="cancelFloatPlan" access="remote" output="false" >
		<cfargument name="fpid" required="true" />
		<cfargument name="status" required="true" />
		<cfset objFpDAO = createObject('component','data.dataAccess.floatPlanDAO').init() />
		<cfset setStatus =  objFpDAO.updateFloatPlanStatus(arguments.fpid,'Open')>
		<cfif arguments.status EQ 'Scheduled'>
			<cfset cancelScheduled =  objFpDAO.cancelSheduled(arguments.fpid)>
		</cfif>
		<cfif arguments.status NEQ 'Scheduled'>
			<cfset sendEmail = sendFloatPlan(floatPlanId = arguments.fpid, whenToSend = 'now', messageType = 'cancelled')>		
		</cfif>				
	</cffunction>
	
	<cffunction name="sendFloatPlan" access="remote" output="false" hint="send float plan by email to conatcts" returnformat="plain" >
		<cfargument name="floatPlanId" required="true" />
		<cfargument name="whenToSend" required="true" />
		<cfargument name="messageType" required="false" default="Sent" />
		<cfargument name="email" required="false" default="" />
		<cfargument name="contactName" required="false" default="" />
		<cfset fpStatus = ''>
		<cfscript>
			var schedFP = '';
		</cfscript>
		<cfset objFpDAO = createObject('component','data.dataAccess.floatPlanDAO').init() />
		<cfif arguments.whenToSend EQ 'now'>
			<cfif arguments.email EQ ''>
				<cfset schedFP = deliverFloatPlan(arguments.floatPlanId,'#arguments.messageType#')>
			<cfelse>
				<cfset schedFP = deliverFloatPlan(floatPlanId = arguments.floatPlanId,messageType = '#arguments.messageType#', contactEmail = '#arguments.email#' )>
			</cfif>			
			
			<cfif arguments.messageType EQ 'closed'>
				<cfset fpStatus = 'Open'>
			<cfelseif arguments.messageType EQ 'cancelled'>
				<cfset fpStatus = 'Open'>
			<cfelse>
				<cfset fpStatus = 'Sent'>
			</cfif>					
		<cfelse>
			<!--- schedule the float plan to be delivered  --->
			<cfif isDate(arguments.whenToSend)>				
				<cfset deliveryTime = CreateODBCDateTime(arguments.whenToSend)>
				<!--- create the time zone object --->
				<cfset var objFloatPlanSvc = createObject('component','data.dataAccess.floatPlanService').init()>
				<!--- 
					Set the dateType to 'depart' or 'return' based on the message type. 
					Message types of 'Sent' are 'depart', everything else wold be 'return' since those are missed arrival messages 
				---> 
				<cfif arguments.messageType EQ 'Sent'>
					<cfset dateType = 'depart'>
				<cfelse>
					<cfset dateType = 'return'>
				</cfif>
				<!--- set the time zone --->
				<cfset var dtTimezone = objFloatPlanSvc.getFloatPlanTimeZones(arguments.floatPlanId, dateType)>
				<!--- conever the date to server time --->
				<cfset deliveryTime = convertToServerTime(deliveryTime,dtTimezone)>
			</cfif>	
			<cfset schedFP = objFpDAO.scheduleFloatPlan(arguments.floatPlanId, deliveryTime)>
			<cfset fpStatus = 'Scheduled'>
		</cfif>
		<cfif schedFP EQ false>
			<cfreturn false>
		<cfelse>
			<cfset updStatus = objFpDAO.updateFloatPlanStatus(arguments.floatPlanId,'#fpStatus#')>
			<cfreturn schedFP>
		</cfif>
	</cffunction>
	
	<cffunction name="deliverFloatPlan" access="remote" output="false">
		<cfargument name="floatPlanId" required="true" />
		<cfargument name="messageType" required="false" default="sent" />
		<cfargument name="contactEmail" required="false" default="" /> 
		<cftry>		
			<cfscript>
				var objFloatPlanSvc = createObject('component','data.dataAccess.floatPlanService').init();
				var objFpDAO = createObject('component','data.dataAccess.floatPlanDAO').init();
				var result = '';
				var message = '';
				var subject = '';
				var amtOverdue = '';
				var sendPDF = true;
				var addHistory = false;				
				var objFloatPlan = objFloatPlanSvc.getEmailInfo(arguments.floatPlanId);
				var objFloatPlanBean = objFloatPlanSvc.read(arguments.floatPlanId);
				var floatPlanName = objFloatPlanBean.getFloatPlanName();
				var objContacts = objFloatPlanSvc.getContactForEmail(arguments.floatPlanId);
				var name = objFloatPlan.fname & ' ' & objFloatPlan.lname;
				var firstName = objFloatPlan.fname;				
				var dtTimezone = objFloatPlanSvc.getFloatPlanTimeZones(arguments.floatPlanId, 'return');								
				var userEmail = objFloatPlan.email;
				var emailList = ValueList(objContacts.email);					
				/* convert return time to server time */			
				if(isDate(objFloatPlan.returnTime)){
					var returnTime = convertToServerTime(objFloatPlan.returnTime, dtTimezone);
				}
				else{
					return false;
					abort;
				}				
				if(arguments.messageType == 'sent'){
					message = 'Hello,<p />#name# has sent you the Float Plan for their planned boat trip. Please keep this email on hand until #firstName# returns and closes out this plan, at which time you will receive another email informing you  
					of #firstName#&apos;s safe return. If #firstName# does not return on-time you will start receiving notices beginning at the expected return time ( #returnTime# ) and continuing until #firstName# does return 
					and closes the float plan. If you do not hear back from #firstName# and feel that there may be an emergency, you should follow the instructions on page 3 of the attached Float Plan.<p/> 
					Please Reply to #firstName# at #userEmail# to let them know you have received their float plan.<p />Regards,<br><a href="www.FloatPlanWizard.com" id="">floatPlanWizard.com</a><br><i>Boat Safe !</i>';
					subject = 'Float Plan from #name#';
					addHistory = true;					
				}				
				else if(arguments.messageType == 'overdue'){
					message = 'Hello,<p />This is a reminder message to let you know that #name# is now due back in port. At this time there is no need for concern. <p />If #name# does not check in during the next 4 hours you will begin to receive  overdue messages and will continue to receive  them until #name# does check in and closes out their Float Plan.<p />Instructions are on page 3 of the attached Float Plan.<p />A reminder email has also been sent to #name# at #userEmail#<p />Regards,<br>FloatPlanWizard.com';
					subject = 'Reminder: #name# is now due back in port.';
				}				
				else if(arguments.messageType == 'closed'){
					message = 'Hello,<p />#name# has checked in and is now safely back in port. Thank you for using FloatPlanWizard.com<p />Regards,<br>FloatPlanWizard.com';
					subject = 'Notice: #name# is now back in port.';
					sendPDF = false;
				}				
				else if(arguments.messageType == 'cancelled'){
					message = 'Hello,<p />#name# has cancelled this Float Plan, no further action is neccessary on your part. Thank you for using floatPlanWizard.com<p />Regards,<br>FloatPlanWizard.com';
					subject = 'Notice: #name# has cancelled this Float Plan.';
					sendPDF = false;
				}				
				else{
					amtOverdue = DateDiff('h', returnTime, now());
					message = 'Hello,<p />#name# has not checked in and is now #amtOverdue# hrs. overdue.<p />If you feel that this is an emergency, we strongly suggest that you follow the instructions on page 3 of the attached Float Plan immediately. If you are not sure on how to proceed the rescue authority listed on the float plan can guide you. <p />A reminder email has been sent to #name# at #userEmail#<p />You will continue to receive  these messages until #name# checks in and closes out this Float Plan.<p />Regards,<br>FloatPlanWizard.com';
					subject = 'Warning: #name# is now #amtOverdue# hours Overdue.';					
				}				
				var fpPDF = createPDF(arguments.floatPlanId);													
			</cfscript>		
			<cfif fpPDF EQ false>				
				<cfreturn false>		
			</cfif>	
			<cfif arguments.messageType NEQ 'optOutContact'>
				<cfloop list="#emailList#" index="item" >		
					<cfmail from="noreply@floatplanwizard.com" subject="#subject#" to="#item#" type="html" server="#application.mailServer#" port="#application.mailPort#" usessl="true" username="#application.mailUser#" password="#application.mailUserPass#">
						<cfif sendPDF>
							<cfmailparam type="application/pdf" file="#application.floatPlanPdf_path#\#fpPDF#">
						</cfif>				
						#message#
						<p />
						Scheduled to Return At: #objFloatPlan.returnTime#
						<cfif amtOverdue NEQ ''>
							<br>
							Now #amtOverdue# Hours Overdue.
						</cfif>
						<p />
						If you have received this email by mistake or wish to opt-out of this float plan click this link. - <a href="https://www.floatplanwizard.com/index.cfm/optout/?email=#item#&fpid=#arguments.floatPlanId#&optout" >Opt Out</a>
						<br>
						Or paste this link into your browser: https://www.floatplanwizard.com/index.cfm/optout/?email=#item#&fpid=#arguments.floatPlanId#&optout
					</cfmail>
				</cfloop>
			</cfif>
			<cfif arguments.messageType EQ 'Sent'>
				<cfmail from="noreply@floatplanwizard.com" subject="Your Float Plan: #floatPlanName#" to="#userEmail#" type="html" server="#application.mailServer#" port="#application.mailPort#" usessl="true" username="#application.mailUser#" password="#application.mailUserPass#">
					<cfmailparam type="application/pdf" file="#application.floatPlanPdf_path#\#fpPDF#">	
					Hello #name#, 
					<p>
					An email with your float plan attached has been sent to your contacts (#emailList#), a copy is also attached to this email. 
					Please click the link below to check-in when you return to close your plan and let your contacts know you have returned safely. 
					If you do not check-in, overdue messages be sent until you do.
					<p>
					Click here to Check-in when you return to port: <a href="https://www.floatplanwizard.com/check-In/index.cfm?fpid=#arguments.floatPlanId#" >Check-in</a>
					<p />
					Or paste this URL into your browser: https://www.floatplanwizard.com/check-In/index.cfm?fpid=#arguments.floatPlanId#
					<p>
					Float Plan: #floatPlanName#
					<p />
					Thank you for using FloatPlanWizard.com
					<br />
					<a href="https://www.floatplanwizard.com/" >FloatPlanWizard.com</a>
				</cfmail>
			<cfelseif arguments.messageType EQ 'overdue'>
				<cfmail from="noreply@floatplanwizard.com" subject="Due Back in Port: #floatPlanName#" to="#userEmail#" type="html" server="#application.mailServer#" port="#application.mailPort#" usessl="true" username="#application.mailUser#" password="#application.mailUserPass#">
					Hello #name#, 
					<p>
					It is now past your expected return time. Please check-in when you return to let your contacts know you are back in port. Your contacts will now be
					sent overdue messages and will continue to receive them until you do check in. If you are going to be delayed for more than 4 hours we recommend, if possible, 
					letting your contacts know you will be delayed and when you are now expecting to be back in port. The next message will be sent in 4 hours.
					<p />													
					Click here to Check-in when you return: <a href="https://www.floatplanwizard.com/check-In/index.cfm?fpid=#arguments.floatPlanId#" >Check-in</a>
					<p />
					Or paste this URL into your browser: https://www.floatplanwizard.com/check-In/index.cfm?fpid=#arguments.floatPlanId#
					<p>
					Float Plan: #floatPlanName#
					<p />
					Scheduled to Return At: #objFloatPlan.returnTime#
					<p />
					Thank you for using FloatPlanWizard.com
					<br />
					<a href="https://www.floatplanwizard.com/" >FloatPlanWizard.com</a>
				</cfmail>
			<cfelseif arguments.messageType EQ 'optOutContact'>
				<cfmail from="noreply@floatplanwizard.com" subject="One of your float plan contacts has Opted-Out: #floatPlanName#" to="#userEmail#" type="html" server="#application.mailServer#" port="#application.mailPort#" usessl="true" username="#application.mailUser#" password="#application.mailUserPass#">
					Hello #name#, 
					<p>
					#arguments.contactEmail# has decided to opt-out of your Float Plan and is no longer receiving arrival messages.
					<p />
					Thank you for using FloatPlanWizard.com
					<br />
					<a href="https://www.floatplanwizard.com/" >FloatPlanWizard.com</a>
				</cfmail>
			<cfelse>
				<cfif arguments.messageType NEQ 'cancelled' And arguments.messageType NEQ 'closed'>
					<cfmail from="noreply@floatplanwizard.com" subject="Warning: #name# you are now #amtOverdue# Hours Overdue " to="#userEmail#" type="html" server="#application.mailServer#" port="#application.mailPort#" usessl="true" username="#application.mailUser#" password="#application.mailUserPass#">
						Hello #name#, 
						<p>
						It is now #amtOverdue# hours past your expected check-in time. Please check-in immediately when you return to let your contacts know you are safely back in port. Your contacts are now being
						sent overdue messages and will continue to receive them until you do check-in and close out your float plan. If you do not check-in they will be informed on how proceed and who to call. 
						Detailed instructions on what to do in case of an emergency are included  on page 3 of your float plan.					 
						<p />	
						Please click here to Check-in when you return to port: <a href="https://www.floatplanwizard.com/check-In/index.cfm?fpid=#arguments.floatPlanId#" >Check-in</a>
						<p />
						Or paste this URL into your browser: https://www.floatplanwizard.com/check-In/index.cfm?fpid=#arguments.floatPlanId#
						<p>
						Float Plan: #floatPlanName#
						<p />
						Scheduled to Return At: #objFloatPlan.returnTime#
						<br>
						Now #amtOverdue# Hours Overdue.
						<p />
						Thank you for using FloatPlanWizard.com
						<br />
						<a href="https://www.floatplanwizard.com/" >FloatPlanWizard.com</a>
					</cfmail>
					<cfset arguments.messageType = 'Warning'>	
				</cfif>	
			</cfif>	
			<cfset addSentId = objFpDAO.addSentEmail(floatPlanId = arguments.floatPlanId, messageType = '#arguments.messageType#')>
			<cfif addHistory>
				<cfset addFpHistory =  objFpDAO.addHistory(fpid = arguments.floatPlanId, sentEmailId = addSentId)>			
			</cfif>			
			<cfcatch>				
			<!---	<cflog text="An error has occoured while sending a float plan | floatPlanId: #arguments.floatPlanId# | message: #cfcatch.message# | Detail:#cfcatch.detail#"> --->
				<cfreturn false>			
			</cfcatch>			
		</cftry>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="getNewcontactForFloatPlan" access="remote" output="false" returntype="any" returnformat="json">
		<cfargument name="contactId" required="true" />	
		<cfset objDatasource = createObject('component','data.beans.Datasource').init('floatPlan','root','pass') />
		<!--- Instantiate the passenger service object --->
		<cfset objWpSvc = createObject('component','data.dataAccess.contactService').init() />
		<!--- Define variables --->		
		<cfscript>
			var qContact = objWpSvc.filterByContactId('#arguments.contactId#');
			var result = ArrayNew(1);
		</cfscript>
		<cfoutput query="qContact">
			<cfset returnStruct = StructNew() />
			<cfset returnStruct["contactId"] = qContact.contactId />	
			<cfset returnStruct["name"] = qContact.name />
			<cfset ArrayAppend(result,returnStruct) />
		</cfoutput>
		<cfreturn result />
	</cffunction>
	
	<cffunction name="getNewWpForFloatPlan" access="remote" output="false" returntype="any" returnformat="json">
		<cfargument name="wpId" required="true" />	
		<cfset objDatasource = createObject('component','data.beans.Datasource').init('floatPlan','root','pass') />
		<!--- Instantiate the passenger service object --->
		<cfset objWpSvc = createObject('component','data.dataAccess.waypointService').init() />
		<!--- Define variables --->		
		<cfscript>
			var qWp = objWpSvc.filterByWaypointId('#arguments.wpId#');
			var result = ArrayNew(1);
		</cfscript>
		<cfoutput query="qWp">
			<cfset returnStruct = StructNew() />
			<cfset returnStruct["wpId"] = qWp.wpId />	
			<cfset returnStruct["name"] = qWp.name />
			<cfset ArrayAppend(result,returnStruct) />
		</cfoutput>
		<cfreturn result />
	</cffunction>
	
	<cffunction name="getNewOpForFloatPlan" access="remote" output="false" returntype="any" returnformat="json">
		<cfargument name="opId" required="true" />	
		<cfset objDatasource = createObject('component','data.beans.Datasource').init('floatPlan','root','pass') />
		<!--- Instantiate the passenger service object --->
		<cfset objOpSvc = createObject('component','data.dataAccess.operatorService').init() />
		<!--- Define variables --->		
		<cfscript>
			var qOp = objOpSvc.filterByOperatorId('#arguments.opId#');
			var result = ArrayNew(1);
		</cfscript>
		<cfoutput query="qOp">
			<cfset returnStruct = StructNew() />
			<cfset returnStruct["opId"] = qOp.opId />	
			<cfset returnStruct["name"] = qOp.name />			
			<cfset ArrayAppend(result,returnStruct) />
		</cfoutput>
		<cfreturn result />
	</cffunction>
	
	<cffunction name="getNewVesselForFloatPlan" access="remote" output="false" returntype="any" returnformat="json">
		<cfargument name="vesselId" required="true" />	
		<cfset objDatasource = createObject('component','data.beans.Datasource').init('floatPlan','root','pass') />
		<!--- Instantiate the passenger service object --->
		<cfset objVesselSvc = createObject('component','data.dataAccess.vesselService').init() />
		<!--- Define variables --->		
		<cfscript>
			var qVessel = objVesselSvc.filterByVesselId('#arguments.vesselId#');
			var result = ArrayNew(1);
		</cfscript>
		<cfoutput query="qVessel">
			<cfset returnStruct = StructNew() />
			<cfset returnStruct["vesselId"] = qVessel.vesselId />	
			<cfset returnStruct["vesselName"] = qVessel.vesselName />	
			<cfset returnStruct["hailingPort"] = qVessel.hailingPort />		
			<cfset returnStruct["timezone"] = qVessel.timezone />	
			<cfset ArrayAppend(result,returnStruct) />
		</cfoutput>
		<cfreturn result />			
	</cffunction>
	
	<cffunction name="getNewPassengerForFloatPlan" access="remote" output="false" returntype="any" returnformat="json">		
		<cfargument name="passId" required="true" />		
		<!--- instantiate the Datasourece object --->
		<cfset objDatasource = createObject('component','data.beans.Datasource').init('floatPlan','root','pass') />
		
		<!--- Instantiate the passenger service object --->
		<cfset objPassengerSvc = createObject('component','data.dataAccess.passengerService').init() />
		<!--- Define variables --->		
		<cfscript>
			var qPassengers = objPassengerSvc.filterByPassengerId('#arguments.passId#');
			var result = ArrayNew(1);
		</cfscript>			
		<cfoutput query="qPassengers">
			<cfset returnStruct = StructNew() />
			<cfset returnStruct["passId"] = qPassengers.passId />	
			<cfset returnStruct["userId"] = qPassengers.userId />	
			<cfset returnStruct["name"] = qPassengers.name />
			<cfset returnStruct["phone"] = qPassengers.phone />					
			<cfset returnStruct["age"] = qPassengers.age />	
			<cfset returnStruct["gender"] = qPassengers.gender />
			<cfset returnStruct["notes"] = qPassengers.notes />
			<cfset returnStruct["pfd"] = qPassengers.pfd />
			<cfset returnStruct["plbuin"] = qPassengers.plbuin />
			<cfset ArrayAppend(result,returnStruct) />
		</cfoutput>
		<cfreturn result />
	</cffunction>	
	
	<cffunction name="getFloatPlanForForm" access="remote" output="false" returntype="any" returnformat="json">
		<cfargument name="floatPlanId" required="true" />
		
		<!--- Define variables --->
		<cfset var data="">
		<cfset var result=ArrayNew(1)>		
		<!--- Do search --->
		<cfset objFloatPlanSvc = createObject('component','data.dataAccess.floatPlanService').init() />
		<cfset objPassengerSvc = createObject('component','data.dataAccess.passengerService' ).init() />
		<cfset objWaypointSvc = createObject('component','data.dataAccess.waypointService' ).init() />
		<cfset objContactSvc = createObject('component','data.dataAccess.contactService' ).init() />		
		<cfset qFloatPlan = objFloatPlanSvc.filterByFloatPlanId(arguments.floatPlanId)>			
		<!--- get ids --->
		<cfset qFloatPlanPassengers = objFloatPlanSvc.getFloatPlanPassengers(floatPlanId = arguments.floatPlanId)>
		<cfset qFloatPlanWaypoints = objFloatPlanSvc.getFloatPlanWaypoints(floatPlanId = arguments.floatPlanId)>
		<cfset qFloatPlanContacts = objFloatPlanSvc.getFloatPlanContacts(floatPlanId = arguments.floatPlanId)>
		<cfset passIds = ''>
		<cfset contactIds = ''>
		<cfset waypointIds = ''>		
		<!--- passengers --->
		<cfloop query="qFloatPlanPassengers">
			<cfset passIds = listAppend(passids,qFloatPlanPassengers.passId & '|' & qFloatPlanPassengers.hasPdf)>			
		</cfloop>
		<!--- waypoints --->
		<cfloop query="qFloatPlanWaypoints">
			<cfset waypointIds = listAppend(waypointIds,qFloatPlanWaypoints.waypointId & '|' & qFloatPlanWaypoints.arrival & '|' & qFloatPlanWaypoints.departure & '|' & qFloatPlanWaypoints.reason & '|' & departType & '|' & name)>							
		</cfloop>
		<!--- contacts --->
		<cfloop query="qFloatPlanContacts">
			<cfset contactIds = listAppend(contactIds,qFloatPlanContacts.contactId)>							
		</cfloop>		
        <!--- Build result array --->
		<cfoutput query="qFloatPlan">
			<cfset returnStruct = StructNew() />
			<cfset returnStruct["userId"] = qFloatPlan.userId />	
			<cfset returnStruct["floatPlanName"] = qFloatPlan.floatPlanName />	
			<cfset returnStruct["vesselId"] = qFloatPlan.vesselId />
			<cfset returnStruct["operatorId"] = qFloatPlan.operatorId />					
			<cfset returnStruct["departing"] = qFloatPlan.departing />	
			<cfset returnStruct["returning"] = qFloatPlan.returning />
			<cfset returnStruct["departureTime"] = qFloatPlan.departureTime />
			<cfset returnStruct["returnTime"] = qFloatPlan.returnTime />
			<cfset returnStruct["uhpDeparture"] = qFloatPlan.uhpDeparture />
			<cfset returnStruct["uhpReturn"] = qFloatPlan.uhpReturn />
			<cfset returnStruct["food"] = qFloatPlan.food />
			<cfset returnStruct["water"] = qFloatPlan.water />
			<cfset returnStruct["notes"] = qFloatPlan.notes />
			<cfset returnStruct["passIds"] = passIds />
			<cfset returnStruct["waypointIds"] = waypointIds />
			<cfset returnStruct["contactIds"] = contactIds />
			<cfset returnStruct["floatPlanEmail"] = floatPlanEmail />
			<cfset returnStruct["rescueAuthority"] = rescueAuthority />
			<cfset returnStruct["rescueAuthorityPhone"] = rescueAuthorityPhone />			
			<cfset returnStruct["departTimezone"] = qFloatPlan.departTimezone />
			<cfset returnStruct["returnTimezone"] = qFloatPlan.returnTimezone />			
			<cfset returnStruct["useVesselTimezone"] = qFloatPlan.useVesselTimezone />
			<cfset returnStruct["useDepartTimezone"] = qFloatPlan.useDepartTimezone />			
			<cfset returnStruct["opHasPfd"] = opHasPfd />
			<cfset ArrayAppend(result,returnStruct) />
		</cfoutput>		
		<!--- And return it --->
		<cfreturn result />
	</cffunction>
		
	<cffunction name="createPDF" access="remote" output="false" hint="i create the float plan pdf" returnformat="plain" >
		<cfargument name="fpId" required="true" hint="I am the floatPlan id to use for the pdf" />
		<cftry>			
			<!--- instantiate the Datasourece object --->
			<cfset objDatasource = createObject('component','data.beans.Datasource').init('floatPlan','root','pass') />
			<!--- Instantiate the  service objects --->			
			<cfset objFloatPlanSvc = createObject('component','data.dataAccess.floatPlanService').init() />
			<cfset objVesselSvc = createObject('component','data.dataAccess.vesselService' ).init() />
			<cfset objOperatorSvc = createObject('component','data.dataAccess.OperatorService' ).init() />
			<cfset objPassengerSvc = createObject('component','data.dataAccess.passengerService' ).init() />
			<cfset objWaypointSvc = createObject('component','data.dataAccess.waypointService' ).init() />
			<cfset objContactSvc = createObject('component','data.dataAccess.contactService' ).init() />			
			<!--- set beans --->
			<cfset objFloatPlan = objFloatPlanSvc.read(floatPlanId = '#arguments.fpId#')>			
			<cfset objFloatPlanVessel = objVesselSvc.read(vesselId = objFloatPlan.GetVesselId())>
			<cfset objFloatPlanOperator = objOperatorSvc.read(operatorId = objFloatPlan.GetOperatorId())>
			<!--- get ids --->
			<cfset qFloatPlanPassengers = objFloatPlanSvc.getFloatPlanPassengers(floatPlanId = objFloatPlan.GetFloatPlanId())>
			<cfset qFloatPlanWaypoints = objFloatPlanSvc.getFloatPlanWaypoints(floatPlanId = objFloatPlan.GetFloatPlanId())>
			<cfset qFloatPlanContacts = objFloatPlanSvc.getFloatPlanContacts(floatPlanId = objFloatPlan.GetFloatPlanId())>					
			<cfscript>
				// set float plan values
				floatPlanName = '#objFloatPlan.getFloatPlanName()#_#DateFormat(now(),'mmddyyy')#.pdf';
				// start of trip departure point and time				
				tripDepartureDate = DateFormat(objFloatPlan.getDepartureTime(),'mm/dd/yyy');
				tripDepartLocation = objFloatPlan.getDeparting();
				tripDepartTime = objFloatPlan.getDepartureTime();
				tripDepartTime = CreateODBCDateTime(tripDepartTime);
				tripDepartTime = TimeFormat(tripDepartTime,'HH:MM');
				// end of trip return point and time
				tripReturnDate = DateFormat(objFloatPlan.getReturnTime(),'mm/dd/yyy');
				tripReturnLocation = objFloatPlan.getReturning();
				tripReturnTime = objFloatPlan.getReturnTime();
				tripReturnTime = CreateODBCDateTime(tripReturnTime);
				tripReturnTime = TimeFormat(tripReturnTime,'HH:MM');	
				email = objFloatPlan.getFloatPlanEmail();
				food = objFloatPlan.getFood(); 
				water = objFloatPlan.getWater(); 
				floatPlanNote = objFloatPlan.getNotes(); 
				rescueAuthority = objFloatPlan.getRescueAuthority();
				rescueAuthorityPhone = objFloatPlan.getRescueAuthorityPhone();
				opHasPfd = objFloatPlan.getOpHasPfd();
				// vessel 
				vesselName = objFloatPlanVessel.getVesselName();
				EPIRB_UIN = objFloatPlanVessel.getAepirb();
				DocRegNum = objFloatPlanVessel.getRegistration();
				Draft = objFloatPlanVessel.getDraft();
				hin = objFloatPlanVessel.getHin();
				HullMat = objFloatPlanVessel.getHullMaterial();
				HullTrimColors = objFloatPlanVessel.getHullColor();
				length = objFloatPlanVessel.getLengthOfVessel();
				ProminentFeatures = objFloatPlanVessel.getProminentFeatures();
				Type = objFloatPlanVessel.getTypeOfVessel();
				VesselName = objFloatPlanVessel.getVesselName();
				YearMakeModel = '#objFloatPlanVessel.getYearBuilt()# - ' & '#objFloatPlanVessel.getMake()# - ' & '#objFloatPlanVessel.getModel()#';
				navigationList = objFloatPlanVessel.getNavigation();
				otherNavigation =  objFloatPlanVessel.getOtherNavigation();
				radioCallSign = objFloatPlanVessel.getCallSignNumber();
				DSCNo = objFloatPlanVessel.getDSCMMSI();
				radio1Type = objFloatPlanVessel.getRadio_1_type();
				Radio1FreqMon = objFloatPlanVessel.getRadio_1_channel();
				radio2Type = objFloatPlanVessel.getRadio_2_type();
				radio2FreqMon = objFloatPlanVessel.getRadio_2_channel();
				cellSatPhone = objFloatPlanVessel.getMobilePhone() & ' | ' & objFloatPlanVessel.getSattelite();	
				primEngType = objFloatPlanVessel.getPrimaryPropulsionType();
				primNumEngines = objFloatPlanVessel.getNumberPrimary();
				primFuelCapacity = objFloatPlanVessel.getPrimaryFuelCapacity();
				auxEngType = objFloatPlanVessel.getAuxPropulsionType();
				if(auxEngType == 'None'){
					auxEngType = 'none';
				}
				auxNumEng = objFloatPlanVessel.getNumberAux();
				auxFuelCapacity = objFloatPlanVessel.getAuxFuelCapacity();
				vdsList = objFloatPlanVessel.getVisualDistressSignals();
				adsList = objFloatPlanVessel.getAudibleDistressSignals();
				anchor = objFloatPlanVessel.getAnchor();
				anchorLineLength = objFloatPlanVessel.getAnchorLineLength();
				agList = objFloatPlanVessel.getAdditionalGear();
				UIN = objFloatPlanVessel.getAepirb();
				OtherAvail1 = objFloatPlanVessel.getOtherEquipment();
				OtherAvail_b = objFloatPlanVessel.getOtherEquipment_b();
				OtherAvail_c = objFloatPlanVessel.getOtherEquipment_c();
				OtherAvail_d = objFloatPlanVessel.getOtherEquipment_d();
				trailer = objFloatPlanVessel.getTrailer();
				// operator
				oprName = objFloatPlanOperator.getName();
				oprAddress = objFloatPlanOperator.getAddress();
				oprCity = objFloatPlanOperator.getCity();
				oprState = objFloatPlanOperator.getState();
				oprZip = objFloatPlanOperator.getZip();
				oprAge = objFloatPlanOperator.getAge();
				oprGender = objFloatPlanOperator.getGender();
				if(oprGender == 'Male'){
					oprGender = 'M';
				}
				else if(oprGender == 'Female'){
					oprGender = 'F';
				}
				else{
					oprGender = '';
				}
				oprPlbuin= objFloatPlanOperator.getPlbuin();
				oprVesselExperience= objFloatPlanOperator.getExpWithVessel();
				oprAreaExperience= objFloatPlanOperator.getExpWithBoatingArea();
				oprPhone = objFloatPlanOperator.getPhone();
				oprVehicleYearMakeModel = objFloatPlanOperator.getVehicle();
				oprVehicleLicenseNum = objFloatPlanOperator.getVehicleLicense();
				oprVehicleParkedAt = objFloatPlanOperator.getVehicleParkedAt();
				oprTrailer = objFloatPlanOperator.getVehicleParkedAt();
				oprNotes = objFloatPlanOperator.getNotes();				
			</cfscript>			
			<cfpdfform action="populate" source="#application.file_path#\assets\pdf\USCGFloatPlan_new.pdf" destination="#application.floatPlanPdf_path#\#floatPlanName#" overwrite="true"  >
				<!--- vessel --->	
				<cfpdfformparam name="ID-VesselName" value="#vesselName#">
			    <cfpdfformparam name="ID-DocRegNum" value="#DocRegNum#">
			    <cfpdfformparam name="ID-Draft" value="#Draft#">
			    <cfpdfformparam name="ID-HIN" value="#hin#">
			    <cfpdfformparam name="ID-HullMat" value="#HullMat#">
			    <cfpdfformparam name="ID-HullTrimColors" value="#HullTrimColors#">
			    <cfpdfformparam name="ID-Length" value="#length#">
			    <cfpdfformparam name="ID-ProminentFeatures" value="#ProminentFeatures#">
			    <cfpdfformparam name="ID-Type" value="#Type#">
			    <cfpdfformparam name="ID-VesselName" value="#vesselName#">
			    <cfpdfformparam name="ID-YearMakeModel" value="#YearMakeModel#">
			    <cfpdfformparam name="PRO-PrimEngType" value="Gas IO">
			    <cfpdfformparam name="PRO-PrimEngType" value="#primEngType#">
				<cfpdfformparam name="PRO-PrimNumEngines" value="#primNumEngines#">
				<cfpdfformparam name="PRO-PrimFuelCapacity" value="#primFuelCapacity#">
				<cfpdfformparam name="PRO-AuxEngType" value="#auxEngType#">
				<cfpdfformparam name="PRO-AuxNumEng" value="#auxNumEng#">
				<cfpdfformparam name="PRO-AuxFuelCapacity" value="#auxFuelCapacity#">
			    <cfif ListFindNoCase(navigationList,'compass')>
			        <cfpdfformparam name="NAV-Compass" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="NAV-Compass" value="No">
			    </cfif>
			    <cfif ListFindNoCase(navigationList,'radar')>
			        <cfpdfformparam name="NAV-Radar" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="NAV-Radar" value="No">
			    </cfif>
			    <cfif ListFindNoCase(navigationList,'gps_dgps')>
			        <cfpdfformparam name="NAV-GPS" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="NAV-GPS" value="No">
			    </cfif>
			    <cfif ListFindNoCase(navigationList,'depthSounder')>
			        <cfpdfformparam name="NAV-DepthSounder" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="NAV-DepthSounder" value="No">
			    </cfif>
			    <cfif ListFindNoCase(navigationList,'charts')>
			        <cfpdfformparam name="NAV-Charts" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="NAV-Charts" value="No">
			    </cfif>
			    <cfif ListFindNoCase(navigationList,'maps')>
			        <cfpdfformparam name="NAV-Maps" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="NAV-Maps" value="No">
			    </cfif>
			    <cfif ListFindNoCase(navigationList,'other')>
			        <cfpdfformparam name="NAV-OtherAvail" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="NAV-OtherAvail" value="No">
			    </cfif>
			    <cfif ListFindNoCase(navigationList,'other')>
			        <cfpdfformparam name="NAV-UserDesc" value="#otherNavigation#">
			    <cfelse>
			        <cfpdfformparam name="NAV-UserDesc" value="">
			    </cfif>
				<cfpdfformparam name="COM-RadioCallSign" value="#radioCallSign#">
				<cfpdfformparam name="COM-DSCNo" value="#DSCNo#">	
				<cfpdfformparam name="COM-Radio1Type" value="VHF-FM">
				<cfpdfformparam name="COM-Radio1FreqMon" value="#radio1FreqMon#">
				<cfpdfformparam name="COM-Radio2Type" value="#radio2Type#">
				<cfpdfformparam name="COM-Radio2FreqMon" value="#radio2FreqMon#">
				<cfpdfformparam name="COM-CellSatPhone" value="#cellSatPhone#">
				<cfpdfformparam name="COM-Email" value="#email#">
				<!--- safety & survival --->	
				<cfif ListFindNoCase(vdsList,'ElectricDistressLight')>
			        <cfpdfformparam name="VDS-EDL" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="VDS-EDL" value="No">
			    </cfif>
			    <cfif ListFindNoCase(vdsList,'Flag')>
			        <cfpdfformparam name="VDS-Flag" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="VDS-Flag" value="No">
			    </cfif>
			    <cfif ListFindNoCase(vdsList,'FlareAerial')>
			        <cfpdfformparam name="VDS-FlareAerial" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="VDS-FlareAerial" value="No">
			    </cfif>
			    <cfif ListFindNoCase(vdsList,'FlareHandheld')>
			        <cfpdfformparam name="VDS-FlareHandheld" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="VDS-FlareHandheld" value="No">
			    </cfif>
			    <cfif ListFindNoCase(vdsList,'SignalMirror')>
			        <cfpdfformparam name="VDS-SignalMirror" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="VDS-SignalMirror" value="No">
			    </cfif>
			    <cfif ListFindNoCase(vdsList,'Smoke')>
			        <cfpdfformparam name="VDS-Smoke" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="VDS-Smoke" value="No">
			    </cfif>
			    <cfif ListFindNoCase(adsList,'Bell')>
			        <cfpdfformparam name="ADS-Bell" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADS-Bell" value="No">
			    </cfif>
			    <cfif ListFindNoCase(adsList,'Horn')>
			        <cfpdfformparam name="ADS-Horn" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADS-Horn" value="No">
			    </cfif>
			    <cfif ListFindNoCase(adsList,'Whistle')>
			        <cfpdfformparam name="ADS-Whistle" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADS-Whistle" value="No">
			    </cfif>    
			    <cfif anchor>
			        <cfpdfformparam name="ADD-Anchor" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADD-Anchor" value="No">
			    </cfif>
			    <cfpdfformparam name="ADD-AnchorLineLength" value="#anchorLineLength#">
			    <cfif ListFindNoCase(agList,'DewateringDevice')>
			        <cfpdfformparam name="ADD-Dewatering" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADD-Dewatering" value="No">
			    </cfif>
			    <cfif ListFindNoCase(agList,'ExposureSuits')>
			        <cfpdfformparam name="ADD-ExposureSuit" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADD-ExposureSuit" value="No">
			    </cfif>
			    <cfif ListFindNoCase(agList,'FireExtinguisher')>
			        <cfpdfformparam name="ADD-FireExtinguisher" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADD-FireExtinguisher" value="No">
			    </cfif>
			    <cfif ListFindNoCase(agList,'FlashlightSearchLight')>
			        <cfpdfformparam name="ADD-Flashlight" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADD-Flashlight" value="No">
			    </cfif>
			    <cfif ListFindNoCase(agList,'RaftDinghy')>
			        <cfpdfformparam name="ADD-Raft" value="Yes">
			    <cfelse>
			        <cfpdfformparam name="ADD-Raft" value="No">
			    </cfif>
			    <cfpdfformparam name="EPIRB-UIN" value="#UIN#">
			    <cfif food NEQ '' And food GT 0>
			    	<cfpdfformparam name="ADD-FoodAvail" value="Yes">
			    	<cfpdfformparam name="ADD-FoodDays" value="#food#">
			    <cfelse>
			    	<cfpdfformparam name="ADD-FoodAvail" value="No">
			    </cfif>
			    <cfif water NEQ '' And water GT 0>
			    	<cfpdfformparam name="ADD-Water" value="Yes">
			    	<cfpdfformparam name="ADD-WaterDays" value="#water#">
			    <cfelse>
			    	<cfpdfformparam name="ADD-Water" value="No">
			    </cfif>
			    <cfif OtherAvail1 NEQ '' >
			    	<cfpdfformparam name="ADD-OtherAvail1" value="Yes">
			    	<cfpdfformparam name="ADD-OtherDesc1" value="#OtherAvail1#">
			    <cfelse>
			    	<cfpdfformparam name="ADD-OtherAvail1" value="No">
			    </cfif>			    
			    <cfif OtherAvail_b NEQ '' >
			    	<cfpdfformparam name="ADD-OtherAvail2" value="Yes">
			    	<cfpdfformparam name="ADD-OtherDesc2" value="#OtherAvail_b#">
			    <cfelse>
			    	<cfpdfformparam name="ADD-OtherAvail2" value="No">
			    </cfif>
			    <cfif OtherAvail_c NEQ '' >
			    	<cfpdfformparam name="ADD-OtherAvail3" value="Yes">
			    	<cfpdfformparam name="ADD-OtherDesc3" value="#OtherAvail_c#">
			    <cfelse>
			    	<cfpdfformparam name="ADD-OtherAvail3" value="No">
			    </cfif>
			    <cfif OtherAvail_d NEQ '' >
			    	<cfpdfformparam name="ADD-OtherAvail4" value="Yes">
			    	<cfpdfformparam name="ADD-OtherDesc4" value="#OtherAvail_d#">
			    <cfelse>
			    	<cfpdfformparam name="ADD-OtherAvail4" value="No">
			    </cfif>		    
			    <!--- operator --->
			    <cfpdfformparam name="OPR-Name" value="#oprName#">
				<cfpdfformparam name="OPR-Address" value="#oprAddress#">
				<cfpdfformparam name="OPR-City" value="#oprCity#">
				<cfpdfformparam name="OPR-State" value="#oprState#">
				<cfpdfformparam name="OPR-ZipCode" value="#oprZip#">
				<cfpdfformparam name="OPR-PLBUIN" value="#oprPLBUIN#">
				<cfif oprVesselExperience EQ 'expWithVessel'>
					<cfpdfformparam name="OPR-VesselExperience" value="Yes">
				<cfelse>
					<cfpdfformparam name="OPR-VesselExperience" value="No">
				</cfif>
				<cfif oprAreaExperience EQ 'expWithBoatingArea'>
					<cfpdfformparam name="OPR-AreaExperience" value="Yes">
				<cfelse>
					<cfpdfformparam name="OPR-AreaExperience" value="No">
				</cfif>
				<cfpdfformparam name="OPR-Age" value="#oprAge#">
				<cfpdfformparam name="OPR-Home Phone" value="#oprPhone#">
				<cfpdfformparam name="OPR-Gender" value="#oprGender#">
				<cfpdfformparam name="OPR-VehicleYearMakeModel" value="#oprVehicleYearMakeModel#">
				<cfpdfformparam name="OPR-VehicleLicenseNum" value="#oprVehicleLicenseNum#">
				<cfpdfformparam name="OPR-VehicleParkedAt" value="#oprVehicleParkedAt#">
				<cfif trailer>
					<cfpdfformparam name="OPR-VesselTrailored" value="Yes">
				<cfelse>
					<cfpdfformparam name="OPR-VesselTrailored" value="No">
				</cfif>
				<cfpdfformparam name="OPR-Note" value="#oprNotes#">	
				<cfpdfformparam name="OPR-Float Plan Note" value="#floatPlanNote#">
				<cfif opHasPfd>
			    	<cfpdfformparam name="OPR-PFD" value="Yes">
			    <cfelse>
			    	<cfpdfformparam name="OPR-PFD" value="No">
			    </cfif>
				<!--- passengers / crew --->
				<cfset passCnt = 0>	
				<cfloop query="qFloatPlanPassengers">
					<cfset passCnt += 1>
					<cfset passenger = objPassengerSvc.read(qFloatPlanPassengers.passId)>
					<cfset passenger.setPfd(qFloatPlanPassengers.hasPdf)>
					<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#Name" value="#passenger.getName()#">
					<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#HomePhone" value="#passenger.getPhone()#">
					<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#Age" value="#passenger.getAge()#">
					<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#Gender" value="#Left(passenger.getGender(),1)#">
					<cfif passenger.getPfd()>
						<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#PFD" value="Yes">
					<cfelse>
						<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#PFD" value="No">
					</cfif>
					<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#Note" value="#passenger.getNotes()#">
					<cfpdfformparam name="POB-#NumberFormat(passCnt,'00')#PLBnum" value="#passenger.getPlbuin()#">				
				</cfloop>
				<!--- contacts --->
				<cfset contactCnt = 0>
				<cfloop query="qFloatPlanContacts">
					<cfset contactCnt += 1>
					<cfset contact = objContactSvc.read(qFloatPlanContacts.contactId)>		
					<cfpdfformparam name="Contact#contactCnt#" value="#contact.getName()#">
					<cfpdfformparam name="Contact#contactCnt#-Phone" value="#contact.getPhone()#">				
				</cfloop>
				<cfpdfformparam name="RescueAuthority" value="#rescueAuthority#">
				<cfpdfformparam name="RescueAuthority-Phone" value="#rescueAuthorityPhone#">
				<!--- Waypoints --->
				<cfpdfformparam name="01DepartDate" value="#tripDepartureDate#">
				<cfpdfformparam name="01DepartTime" value="#tripDepartTime#">
				<cfpdfformparam name="01DepartLocation" value="#tripDepartLocation# - Start of Trip">
				<cfpdfformparam name="01DepartMode" value="">
				<cfset waypointCnt = 1>
				<cfset wpDataCnt = 0>
				<!--- waypoints --->
				<cfloop query="qFloatPlanWaypoints">
					<cfset waypointCnt += 1>
					<cfset waypoint = objWaypointSvc.read(qFloatPlanWaypoints.waypointId)>	
					<cfset arriveDate = qFloatPlanWaypoints.arrival>
					<cfif arriveDate NEQ ''>
						<cfset arriveDate = CreateDate(Left(arriveDate,4),mid(arriveDate,6,2),mid(arriveDate,9,2))>
						<cfset arriveDate = DateFormat(arriveDate,'mm/dd/yyyy')>
					</cfif>					
					<cfset departDate = qFloatPlanWaypoints.departure>
					<cfif departDate NEQ ''>
						<cfset departDate = CreateDate(Left(departDate,4),mid(departDate,6,2),mid(departDate,9,2))>
						<cfset departDate = DateFormat(departDate,'mm/dd/yyyy')>
					</cfif>					
					<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#ArriveDate" value="#arriveDate#">
					<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#ArriveTime" value="#Right(qFloatPlanWaypoints.arrival,5)#">
					<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#DepartDate" value="#departDate#">
					<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#DepartTime" value="#Right(qFloatPlanWaypoints.departure,5)#">
					<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#ArriveLocation" value="#waypoint.getName()#">					
					<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#DepartMode" value="#qFloatPlanWaypoints.departType#">	
					<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#ArriveReason" value="#qFloatPlanWaypoints.reason#">		
				</cfloop>
				<!--- End of trip / return to port --->
				<cfset waypointCnt += 1>
				<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#ArriveDate" value="#tripReturnDate#">
				<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#ArriveTime" value="#tripReturnTime#">
				<cfpdfformparam name="#NumberFormat(waypointCnt,'00')#ArriveLocation" value="#tripReturnLocation# - End of Trip">
			</cfpdfform>			
			<!---<cflog text="pdf created - #arguments.fpId#" file="floatPlan_pdfUtils" >--->
			<cfcatch >
				<cflog text="#cfcatch.message# - #cfcatch.detail#" file="floatPlan_pdfUtils" >
				<cfmail from="info@floatPlanWizard.com" subject="error: createPDF" to="larry@floatPlanWizard.com" server="#application.mailServer#" port="#application.mailPort#" usessl="true" username="#application.mailUser#" password="#application.mailUserPass#">
					<cfdump var="#cfcatch#">
				</cfmail>				
				<cfreturn false>
				<cfabort>
			</cfcatch>
		</cftry>
		<cfreturn floatPlanName>
	</cffunction>
</cfcomponent>