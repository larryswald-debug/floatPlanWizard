component output=false {
  variables.datasource="fpw";
  public any function init(string datasource="fpw") {variables.datasource=arguments.datasource;return this;}

  // The token contains only a random public reference and a purpose-bound HMAC.
  public struct function decorate(required struct message,required string publicId,required string signingSecret) {
    var result=duplicate(arguments.message);
    var destination=toString(result.destinationUrl ?: result.ctaUrl ?: "");
    var marker=find("/app/dashboard.cfm?",destination);
    if(marker LTE 1) throw(type="FPW.Recovery.InvalidTrackingDestination",message="TRACKING_DESTINATION_INVALID");
    var base=left(destination,marker-1);
    var relative=mid(destination,marker,len(destination));
    if(!reFind("^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9_-]+)*$",base)
      OR !len(new fpw.includes.InactiveMemberRecoveryActionPathService().validatePath(relative)))
      throw(type="FPW.Recovery.InvalidTrackingDestination",message="TRACKING_DESTINATION_INVALID");
    var openUrl=base & "/app/recovery-open.cfm?t=" & token(arguments.publicId,arguments.signingSecret,"open");
    var clickUrl=base & "/app/recovery-click.cfm?t=" & token(arguments.publicId,arguments.signingSecret,"click");
    result.textBody=replace(result.textBody,destination,clickUrl,"all");
    result.htmlBody=replace(result.htmlBody,encodeForHtmlAttribute(destination),encodeForHtmlAttribute(clickUrl),"all");
    // A renderer may use a literal URL instead of attribute encoding.
    result.htmlBody=replace(result.htmlBody,destination,encodeForHtmlAttribute(clickUrl),"all");
    var pixel='<img src="' & encodeForHtmlAttribute(openUrl) & '" width="1" height="1" alt="" style="display:block;border:0;" />';
    if(findNoCase("</body>",result.htmlBody)) result.htmlBody=replaceNoCase(result.htmlBody,"</body>",pixel & "</body>");
    else result.htmlBody &= pixel;
    result.destinationUrl=destination;
    result.ctaUrl=clickUrl;
    return {message=result,openUrl=openUrl,clickUrl=clickUrl};
  }

  public boolean function recordOpen(required string candidate) {
    try {
      var row=verified(arguments.candidate,"open");
      if(!row.recordCount) return false;
      return signal(row,"open");
    } catch(any unavailableTracking) {return false;}
  }

  // Called only by the public click page. It never establishes an authenticated session.
  public string function resolveClick(required string candidate,required string basePath) {
    var fallback=arguments.basePath & "/index.cfm";
    try {
      var row=verified(arguments.candidate,"click");
      if(!row.recordCount) return fallback;
      if(!signal(row,"click")) return fallback;
      var paths=new fpw.includes.InactiveMemberRecoveryActionPathService();
      var safe=paths.validatePath(toString(row.destination_path[1]));
      if(!len(safe)) return fallback;
      var values={};
      for(var pair in listToArray(listRest(safe,"?"),"&")) values[listFirst(pair,"=")]=listRest(pair,"=");
      var destination=new fpw.includes.InactiveMemberRecoveryDestinationService().init(variables.datasource)
        .resolveRequest(val(row.user_id[1]),values);
      if(!len(destination.action)) return fallback;
      var context={};
      if(destination.action EQ "route") {
        if(destination.routeId GT 0) context.routeId=destination.routeId;
        else if(destination.routeInstanceId GT 0) context.routeInstanceId=destination.routeInstanceId;
        else return fallback;
      } else if(destination.action EQ "draft") context.floatPlanId=destination.floatPlanId;
      var authenticatedUser=structKeyExists(session,"user") AND isStruct(session.user)
        ? val(session.user.userId ?: session.user.id ?: 0) : 0;
      if(authenticatedUser GT 0 AND authenticatedUser NEQ val(row.user_id[1])) return fallback;
      var continuation=new fpw.includes.AuthContinuationService();
      var intent=continuation.createIntent(destination.action,context);
      if(authenticatedUser GT 0) {
        var resolved=continuation.resolve(intent.token,authenticatedUser);
        return resolved.redirectUrl ?: fallback;
      }
      return arguments.basePath & "/app/login.cfm?authIntent=" & intent.token;
    } catch(any invalidOrUnavailableTracking) {return fallback;}
  }

  private string function token(required string publicId,required string signingSecret,required string purpose) {
    if(!reFind("^[a-f0-9]{64}$",arguments.publicId) OR !reFind("^[a-f0-9]{64}$",arguments.signingSecret)
      OR !listFind("open,click",arguments.purpose)) throw(type="FPW.Recovery.InvalidToken",message="INVALID_TRACKING_TOKEN");
    return arguments.publicId & "." & lCase(hmac("recovery:" & arguments.purpose & ":" & arguments.publicId,
      arguments.signingSecret,"HMACSHA256","UTF-8"));
  }

  private query function verified(required string candidate,required string purpose) {
    if(len(arguments.candidate) NEQ 129 OR !reFind("^[a-f0-9]{64}[.][a-f0-9]{64}$",arguments.candidate)) return queryNew("");
    var row=queryExecute("SELECT id,user_id,public_id,signing_secret,destination_path,attribution_deadline_utc
      FROM inactive_member_recovery_messages WHERE public_id=:publicId AND message_kind='AUTOMATED'
      AND status='SEND_ACCEPTED' AND accepted_at_utc IS NOT NULL AND accepted_at_utc<=UTC_TIMESTAMP()
      AND UTC_TIMESTAMP()<=DATE_ADD(accepted_at_utc,INTERVAL 90 DAY) LIMIT 1",
      {publicId={value=listFirst(arguments.candidate,"."),cfsqltype="cf_sql_char"}},{datasource=variables.datasource});
    if(!row.recordCount) return row;
    var expected=listLast(token(row.public_id[1],row.signing_secret[1],arguments.purpose),".");
    var actual=listLast(arguments.candidate,".");
    if(!createObject("java","java.security.MessageDigest").isEqual(binaryDecode(expected,"hex"),binaryDecode(actual,"hex")))
      return queryNew("");
    return row;
  }

  private boolean function signal(required query row,required string purpose) {
    var column=arguments.purpose;
    if(!listFind("open,click",column)) return false;
    transaction {
      queryExecute("UPDATE inactive_member_recovery_messages SET first_" & column & "_at_utc=COALESCE(first_" & column & "_at_utc,UTC_TIMESTAMP()),
        latest_" & column & "_at_utc=UTC_TIMESTAMP()," & column & "_count=LEAST(" & column & "_count+1,2147483647),
        late_" & column & "_count=LEAST(late_" & column & "_count+CASE WHEN UTC_TIMESTAMP()>attribution_deadline_utc THEN 1 ELSE 0 END,2147483647)
        WHERE id=:id AND status='SEND_ACCEPTED' AND accepted_at_utc<=UTC_TIMESTAMP()
          AND UTC_TIMESTAMP()<=DATE_ADD(accepted_at_utc,INTERVAL 90 DAY)",
        {id={value=arguments.row.id[1],cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource});
      // Expiry can pass between verification and mutation. Never write an event when
      // the guarded counter update did not accept this signal.
      var changed=queryExecute("SELECT ROW_COUNT() AS changed_count",{}, {datasource=variables.datasource});
      if(val(changed.changed_count[1]) NEQ 1) return false;
      // One immutable first-signal event; repeat/late counts stay bounded on the message.
      new fpw.includes.ProductEventService().init(variables.datasource).recordEvent(
        userId=arguments.row.user_id[1],eventName=column EQ "open" ? "recovery_opened" : "recovery_clicked",
        entityType="recovery_message",entityId=arguments.row.id[1],eventSource="recovery_tracking",
        metadata={},idempotencyKey="recovery_" & column & ":" & arguments.row.id[1]);
    }
    return true;
  }
}
