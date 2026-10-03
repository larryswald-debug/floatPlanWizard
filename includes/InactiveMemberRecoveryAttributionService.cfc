component output=false {
  variables.datasource="fpw";
  public any function init(string datasource="fpw") {variables.datasource=arguments.datasource;return this;}

  // Optional post-commit observation. Failures never alter the member's completed action.
  public void function observeRequest(required numeric userId,boolean authenticatedPageReturn=false) {
    if(arguments.userId LTE 0 OR arguments.userId NEQ fix(arguments.userId)) return;
    try {
      if(arguments.authenticatedPageReturn) recordPageReturn(arguments.userId);
      reconcileMember(arguments.userId,100);
    } catch(any observationUnavailable) {
      writeLog(file="fpw-recovery",type="warning",text="RECOVERY_ATTRIBUTION_UNAVAILABLE");
    }
  }

  public numeric function reconcileMember(required numeric userId,numeric maxEvents=100) {
    var events=queryExecute("SELECT e.id FROM product_events e
      WHERE e.user_id=:user AND e.occurred_at_utc<=UTC_TIMESTAMP() AND " & qualifyingSourceSql("e") & "
      AND EXISTS (SELECT 1 FROM inactive_member_recovery_messages m WHERE m.user_id=e.user_id
        AND m.message_kind='AUTOMATED' AND m.status='SEND_ACCEPTED'
        AND e.occurred_at_utc>=m.accepted_at_utc AND e.occurred_at_utc<=m.attribution_deadline_utc)
      AND NOT EXISTS (SELECT 1 FROM product_events attributed
        WHERE attributed.idempotency_key=CONCAT('recovery_returned_source:',e.id))
      ORDER BY e.occurred_at_utc,e.id LIMIT " & min(500,max(1,fix(arguments.maxEvents))),
      {user={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
    var count=0;
    for(var row in events) if(attributeSource(row.id,arguments.userId)) count++;
    return count;
  }

  public numeric function reconcileBatch(numeric maxMembers=100) {
    var users=queryExecute("SELECT DISTINCT m.user_id FROM inactive_member_recovery_messages m
      JOIN product_events e ON e.user_id=m.user_id AND e.occurred_at_utc>=m.accepted_at_utc
        AND e.occurred_at_utc<=m.attribution_deadline_utc
      WHERE m.message_kind='AUTOMATED' AND m.status='SEND_ACCEPTED' AND e.occurred_at_utc<=UTC_TIMESTAMP() AND " & qualifyingSourceSql("e") & "
        AND NOT EXISTS (SELECT 1 FROM product_events a WHERE a.idempotency_key=CONCAT('recovery_returned_source:',e.id))
      ORDER BY m.user_id LIMIT " & min(100,max(1,fix(arguments.maxMembers))),{}, {datasource=variables.datasource});
    var count=0;
    for(var member in users) count+=reconcileMember(member.user_id,100);
    return count;
  }

  private void function recordPageReturn(required numeric userId) {
    // One durable authenticated-page source per accepted contact. It is never engagement.
    var message=queryExecute("SELECT id,returned_at_utc FROM inactive_member_recovery_messages WHERE user_id=:user
      AND message_kind='AUTOMATED' AND status='SEND_ACCEPTED' AND accepted_at_utc<=UTC_TIMESTAMP()
      AND attribution_deadline_utc>=UTC_TIMESTAMP()
      ORDER BY accepted_at_utc DESC,id DESC LIMIT 1",
      {user={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
    if(!message.recordCount OR isDate(message.returned_at_utc[1])) return;
    new fpw.includes.ProductEventService().init(variables.datasource).recordEvent(
      userId=arguments.userId,eventName="recovery_authenticated_return",entityType="user",entityId=arguments.userId,
      eventSource="authenticated_page",metadata={},idempotencyKey="recovery_page_return:" & message.id[1]);
  }

  private boolean function attributeSource(required numeric sourceEventId,required numeric userId) {
    var attributed=false;
    transaction isolation="read_committed" {
      // The original member-owned source row serializes concurrent reconcilers.
      var source=queryExecute("SELECT e.id,e.user_id,e.event_name,e.event_source,
          DATE_FORMAT(e.occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS occurred_at
        FROM product_events e WHERE e.id=:id AND e.user_id=:user AND e.occurred_at_utc<=UTC_TIMESTAMP() AND " & qualifyingSourceSql("e") & " FOR UPDATE",
        {id={value=arguments.sourceEventId,cfsqltype="cf_sql_bigint"},user={value=arguments.userId,cfsqltype="cf_sql_integer"}},
        {datasource=variables.datasource});
      if(source.recordCount) {
        var seen=queryExecute("SELECT id FROM product_events WHERE idempotency_key=:key LIMIT 1",
          {key={value="recovery_returned_source:" & arguments.sourceEventId,cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource});
        if(!seen.recordCount) {
          var at=replace(replace(source.occurred_at[1],"T"," "),"Z","");
          var message=queryExecute("SELECT id,contact_number,destination_stage FROM inactive_member_recovery_messages
            WHERE user_id=:user AND message_kind='AUTOMATED' AND status='SEND_ACCEPTED'
              AND accepted_at_utc<=CAST(:at AS DATETIME) AND attribution_deadline_utc>=CAST(:at AS DATETIME)
            ORDER BY accepted_at_utc DESC,id DESC LIMIT 1 FOR UPDATE",
            {user={value=arguments.userId,cfsqltype="cf_sql_integer"},at={value=at,cfsqltype="cf_sql_varchar"}},
            {datasource=variables.datasource});
          if(message.recordCount) {
            var engaged=source.event_source[1] EQ "member_api"
              OR listFind("basic_send_completed,premium_send_completed,recovery_share_succeeded",source.event_name[1]) GT 0;
            var params={id={value=message.id[1],cfsqltype="cf_sql_bigint"},at={value=at,cfsqltype="cf_sql_varchar"},
              source={value=arguments.sourceEventId,cfsqltype="cf_sql_bigint"}};
            queryExecute("UPDATE inactive_member_recovery_messages
              SET return_source_event_id=CASE WHEN returned_at_utc IS NULL OR returned_at_utc>CAST(:at AS DATETIME)
                THEN :source ELSE return_source_event_id END,
                returned_at_utc=CASE WHEN returned_at_utc IS NULL OR returned_at_utc>CAST(:at AS DATETIME)
                THEN CAST(:at AS DATETIME) ELSE returned_at_utc END WHERE id=:id",params,{datasource=variables.datasource});
            if(engaged) queryExecute("UPDATE inactive_member_recovery_messages
              SET engagement_source_event_id=CASE WHEN engaged_at_utc IS NULL OR engaged_at_utc>CAST(:at AS DATETIME)
                THEN :source ELSE engagement_source_event_id END,
                engaged_at_utc=CASE WHEN engaged_at_utc IS NULL OR engaged_at_utc>CAST(:at AS DATETIME)
                THEN CAST(:at AS DATETIME) ELSE engaged_at_utc END WHERE id=:id",params,{datasource=variables.datasource});
            var metadata={source_event_id=toString(arguments.sourceEventId),contact_number=toString(message.contact_number[1]),
              destination_stage=toString(message.destination_stage[1])};
            var eventService=new fpw.includes.ProductEventService().init(variables.datasource);
            var recorded=eventService.recordEvent(arguments.userId,"recovery_returned","recovery_message",message.id[1],
              "recovery_attribution",metadata,"recovery_returned_source:" & arguments.sourceEventId);
            if(!recorded.SUCCESS) throw(type="FPW.Recovery.AttributionUnconfirmed",message="ATTRIBUTION_EVENT_UNCONFIRMED");
            if(engaged) {
              recorded=eventService.recordEvent(arguments.userId,"recovery_engaged","recovery_message",message.id[1],
                "recovery_attribution",metadata,"recovery_engaged_source:" & arguments.sourceEventId);
              if(!recorded.SUCCESS) throw(type="FPW.Recovery.AttributionUnconfirmed",message="ATTRIBUTION_EVENT_UNCONFIRMED");
            }
            attributed=true;
          }
        }
      }
    }
    return attributed;
  }

  private string function qualifyingSourceSql(required string alias) {
    // Sources are existing committed, authoritative activity contracts; page views and logins are return only.
    var e=arguments.alias & ".";
    return "((" & e & "event_name='login' AND " & e & "event_source='password_auth' AND " & e & "entity_type='user' AND " & e & "entity_id=" & e & "user_id)
      OR (" & e & "event_name='recovery_authenticated_return' AND " & e & "event_source='authenticated_page' AND " & e & "entity_type='user' AND " & e & "entity_id=" & e & "user_id)
      OR (" & e & "event_source='member_api' AND (
        (" & e & "event_name IN ('vessel_created','vessel_updated') AND " & e & "entity_type='vessel') OR
        (" & e & "event_name IN ('shore_contact_created','shore_contact_updated') AND " & e & "entity_type='shore_contact') OR
        (" & e & "event_name IN ('operator_created','operator_updated') AND " & e & "entity_type='operator') OR
        (" & e & "event_name IN ('passenger_created','passenger_updated') AND " & e & "entity_type='passenger') OR
        (" & e & "event_name IN ('waypoint_created','waypoint_updated') AND " & e & "entity_type='waypoint') OR
        (" & e & "event_name IN ('user_route_created','user_route_updated') AND " & e & "entity_type='user_route') OR
        (" & e & "event_name IN ('route_created','route_updated') AND " & e & "entity_type='route_instance') OR
        (" & e & "event_name='route_segment_updated' AND " & e & "entity_type='user_segment_override') OR
        (" & e & "event_name IN ('float_plan_created','float_plan_updated') AND " & e & "entity_type='float_plan')))
      OR (" & e & "entity_type='float_plan' AND (
        (" & e & "event_name='basic_send_completed' AND " & e & "event_source IN ('basic_save_send','basic_review_send')) OR
        (" & e & "event_name='premium_send_completed' AND " & e & "event_source='premium_save_send') OR
        (" & e & "event_name='recovery_share_succeeded' AND " & e & "event_source IN ('basic_save_send','basic_review_send','premium_save_send')))))";
  }
}
