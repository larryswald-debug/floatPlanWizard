(function () {
  "use strict";
  var root = document.getElementById("recoveryCenter");
  if (!root) return;
  var endpoint = root.dataset.endpoint;
  var state = {tab:"dashboard",pages:{queue:1,runs:1,members:1},memberId:0,memberPages:{messages:1,evaluations:1,history:1},runId:0,runPage:1,auditPage:1,reviews:{},busy:false};
  var stages = {A:"Add Vessel",B:"Trip Planner",C:"Saved / Planned Route",D:"Draft Editor"};
  function byId(id) { return document.getElementById(id); }
  function val(object,key,fallback) {
    if (!object || typeof object !== "object") return fallback === undefined ? "" : fallback;
    var found=Object.keys(object).find(function (name) { return name.toLowerCase().replace(/_/g,"")===key.toLowerCase().replace(/_/g,""); });
    return found===undefined || object[found]===null || object[found]==="" ? (fallback===undefined ? "" : fallback) : object[found];
  }
  function yes(value) { return value===true || value===1 || String(value).toLowerCase()==="true"; }
  function text(value, fallback) { return value===undefined || value===null || value==="" ? (fallback===undefined ? "Unknown" : fallback) : String(value); }
  function node(tag,content,cls) { var el=document.createElement(tag); if(content!==undefined) el.textContent=text(content,""); if(cls)el.className=cls; return el; }
  function empty(id) { var el=typeof id==="string"?byId(id):id; el.replaceChildren(); return el; }
  function notice(message,error) { var el=byId("rcStatus");el.textContent=message;el.hidden=!message;el.className="rc-notice"+(error?" is-error":""); }
  function button(label,action,cls) { var b=node("button",label,cls);b.type="button";b.addEventListener("click",action);return b; }
  function fields(formId) { return Object.fromEntries(new FormData(byId(formId)).entries()); }
  async function api(action,params,post) {
    var data=Object.assign({action:action},params||{}),options={credentials:"same-origin",cache:"no-store",headers:{Accept:"application/json"}};
    var address=endpoint;
    if(post) { data.adminCsrfToken=window.FPW_ADMIN_CSRF_TOKEN||"";options.method="POST";options.body=new URLSearchParams(data); }
    else address+="?"+new URLSearchParams(data);
    var response=await fetch(address,options),reply;
    try { reply=await response.json(); } catch(e) { throw new Error("The server response could not be verified. Refresh your administrative session before retrying."); }
    if(!response.ok || !yes(val(reply,"SUCCESS"))) throw new Error((val(reply,"CODE")?val(reply,"CODE")+": ":"")+(val(reply,"MESSAGE")||"The recovery request could not be verified."));
    return val(reply,"DATA",reply);
  }
  async function work(fn) {
    if(state.busy)return;
    state.busy=true;root.setAttribute("aria-busy","true");notice("");
    try { await fn(); } catch(error) { notice(error.message||"The request could not be verified.",true); }
    finally { state.busy=false;root.removeAttribute("aria-busy"); }
  }
  function table(target,columns,rows) {
    var container=empty(target);
    if(!Array.isArray(rows)||!rows.length) { container.append(node("p","No matching records.","rc-empty"));return; }
    var wrap=node("div",undefined,"rc-table-wrap"),tableEl=node("table"),head=node("thead"),headRow=node("tr"),body=node("tbody");
    columns.forEach(function(c){headRow.append(node("th",c[0]));});head.append(headRow);tableEl.append(head);
    rows.forEach(function(row) {var tr=node("tr");columns.forEach(function(c){var td=node("td"),value=typeof c[1]==="function"?c[1](row):text(val(row,c[1]));if(value instanceof Node)td.append(value);else td.textContent=text(value);tr.append(td);});body.append(tr);});
    tableEl.append(body);wrap.append(tableEl);container.append(wrap);
  }
  function kv(target,pairs) { var list=node("dl",undefined,"rc-kv");pairs.forEach(function(pair){list.append(node("dt",pair[0]),node("dd",text(pair[1])));});empty(target).append(list); }
  function metrics(target,data,definitions) {var container=empty(target);definitions.forEach(function(item){var tile=node("div",undefined,"rc-metric");tile.append(node("strong",text(val(data,item[1]))),node("span",item[0]));container.append(tile);});}
  function destination(row) {var stage=val(row,"destinationStage");return stage?stage+" — "+(val(row,"destinationLabel")||stages[stage]||"Unknown"):"Unknown";}
  function contact(row) {return yes(val(row,"sequenceComplete"))?"Automated sequence complete":val(row,"contactNumber")?"#"+val(row,"contactNumber")+" of "+val(row,"contactTotal",3):"Unknown";}
  function memberLink(row) {return button(val(row,"email")||("Member "+val(row,"userId")),function(){openMember(val(row,"userId"));},"rc-inline-link");}
  function pager(name,data) {var el=empty("rc"+name[0].toUpperCase()+name.slice(1)+"Pager"),page=Number(val(data,"page",1)),size=Number(val(data,"pageSize",25)),total=Number(val(data,"total",0));
    var previous=button("Previous",function(){state.pages[name]=page-1;work(loadView);}),next=button("Next",function(){state.pages[name]=page+1;work(loadView);});
    previous.disabled=page<=1;next.disabled=page*size>=total;el.append(previous,node("span","Page "+page+" · "+total+" records"),next);
  }
  function detailPager(target,data,label,onPage) {
    var container=typeof target==="string"?byId(target):target,page=Number(val(data,"page",1)),size=Number(val(data,"pageSize",25)),total=Number(val(data,"total",0)),totalPages=Number(val(data,"totalPages",Math.max(1,Math.ceil(total/size))));
    var controls=node("div",undefined,"rc-pager");controls.setAttribute("role","group");controls.setAttribute("aria-label",label+" pagination");
    var previous=button("Previous "+label,function(){work(function(){return onPage(page-1);});}),next=button("Next "+label,function(){work(function(){return onPage(page+1);});});
    previous.disabled=page<=1;next.disabled=page>=totalPages;controls.append(previous,node("span","Page "+page+" of "+totalPages+" · "+total+" records"),next);container.append(controls);
  }
  function memberColumns() {return [["Member",memberLink],["Recovery contact",contact],["Current destination",destination],["Decision","decision"],["Reason","reason"],["Eligible UTC","eligibleAtUtc"],["Response",function(r){return "Returned: "+text(val(r,"returned"))+" · Engaged: "+text(val(r,"engaged"));}]];}
  function switchTab(name) {state.tab=name;document.querySelectorAll("[data-tab]").forEach(function(b){var active=b.dataset.tab===name;b.setAttribute("aria-selected",String(active));b.tabIndex=active?0:-1;byId(b.getAttribute("aria-controls")).hidden=!active;});}
  async function loadView() {
    var data;
    if(state.tab==="dashboard") {
      data=await api("dashboard");
      metrics("rcMetrics",val(data,"metrics",{}),[["Enrolled","enrolled"],["Eligible now","eligible"],["Waiting","waiting"],["Held","held"],["Paused","paused"],["Excluded","excluded"],["Sequence complete","sequenceComplete"],["Needs attention","needsAttention"]]);
      kv("rcFunnel",["accepted","opened","clicked","returned","engaged"].map(function(k){return [k[0].toUpperCase()+k.slice(1),val(val(data,"funnel",{}),k)];}));
      var timing=val(data,"settings",{});
      kv("rcTimingSummary",[["First delay",text(val(timing,"firstDelayHours"))+" hours"],["Contact interval",text(val(timing,"stageIntervalHours"))+" hours"],["Attribution window",text(val(timing,"attributionWindowHours"))+" hours"]]);
      var run=val(data,"lastRun",{});
      kv("rcLastRun",[["Last run",val(run,"runId")],["Status",val(run,"status")],["Started UTC",val(run,"startedAtUtc")],["Mode",val(run,"mode")]]);
      table("rcAttention",memberColumns(),val(data,"attention",[]));
    } else if(state.tab==="queue" || state.tab==="members") {
      var name=state.tab;
      data=await api(name,Object.assign(fields(name==="queue"?"rcQueueFilter":"rcMemberFilter"),{page:state.pages[name],pageSize:25}));
      table(name==="queue"?"rcQueueTable":"rcMembersTable",memberColumns(),val(data,"rows",[]));pager(name,data);
      if(name==="queue")byId("rcQueueEvaluated").textContent="Eligibility evaluated at: "+text(val(data,"evaluatedAtUtc"))+" UTC.";
    } else if(state.tab==="runs") {
      data=await api("runs",{page:state.pages.runs,pageSize:25});
      table("rcRunsTable",[["Run",function(r){return button(val(r,"runId"),function(){work(function(){return openRun(val(r,"runId"));});},"rc-inline-link");}],["Source","source"],["Mode","mode"],["Status","status"],["Started UTC","startedAtUtc"],["Finished UTC","finishedAtUtc"],["Evaluated","evaluated"],["Eligible","eligible"],["Accepted","accepted"],["Failed","failed"],["Unknown outcome","unknown"]],val(data,"rows",[]));pager("runs",data);
    } else if(state.tab==="performance") {
      data=await api("performance",fields("rcPerformanceFilter"));
      metrics("rcPerformanceSummary",val(data,"summary",{}),[["Accepted messages","accepted"],["Observed opens","opened"],["Observed clicks","clicked"],["Returned","returned"],["Engaged","engaged"]]);
      table("rcPerformanceTable",[["Contact",function(r){return val(r,"contactNumber")?"#"+val(r,"contactNumber"):"Personal";}],["Destination stage","destinationStage"],["Template","templateId"],["Accepted","accepted"],["Open rate",function(r){return rate(r,"opened");}],["Click rate",function(r){return rate(r,"clicked");}],["Return rate",function(r){return rate(r,"returned");}],["Engaged rate",function(r){return rate(r,"engaged");}],["Late opens","lateOpens"],["Late clicks","lateClicks"]],val(data,"rows",[]));
      kv("rcPeriodActivity",["opened","clicked","returned","engaged"].map(function(k){return [k[0].toUpperCase()+k.slice(1),val(val(data,"periodActivity",{}),k)];}).concat([["Counting basis",val(val(data,"periodActivity",{}),"basis")],["Accepted messages without tracking",val(val(data,"summary",{}),"missingTracking")],["All-time accepted ledger contacts without message telemetry (all contacts/destinations)",val(val(data,"summary",{}),"untrackedAcceptedLedgerContacts")]]));
    } else if(state.tab==="settings") {
      data=await api("settings",{auditPage:state.auditPage,pageSize:25});
      ["firstDelayHours","stageIntervalHours","attributionWindowHours"].forEach(function(k){byId("rcSettingsForm").elements[k].value=val(data,k);});
      state.settingsRevision=val(data,"revision");
      byId("rcResetState").textContent=val(data,"resetAtUtc")?"Completed at "+val(data,"resetAtUtc")+" UTC for "+val(data,"resetCohortCount")+" enrollments.":"No completed reset is recorded.";
      byId("rcResetPreview").disabled=!!val(data,"resetAtUtc");
      table("rcSettingsAudit",[["UTC","createdAtUtc"],["Administrator",function(r){return val(r,"actorUserId",val(r,"adminUserId"));}],["Action","action"],["Before","previousValuesJson"],["After","newValuesJson"]],val(data,"audit",[]));
      detailPager("rcSettingsAudit",val(data,"auditPagination",{}),"audit",function(page){state.auditPage=page;return loadView();});
    }
  }
  function rate(row,key) {var amount=val(row,key,null),denominator=val(row,"accepted",null);if(amount===null||denominator===null)return "Unknown";return Number(denominator)>0?amount+"/"+denominator+" ("+(100*Number(amount)/Number(denominator)).toFixed(1)+"%)":amount+"/0 (no accepted messages)";}
  async function openRun(id) {
    if(state.runId!==Number(id)){state.runId=Number(id);state.runPage=1;}
    var data=await api("runs",{runId:id,evaluationsPage:state.runPage,pageSize:25}),run=val(data,"run",{}),el=empty("rcRunDetail");el.hidden=false;el.append(node("h3","Run "+id));
    var context=node("div"),rows=node("div");el.append(context,rows);
    kv(context,[["Status",val(run,"status")],["Source",val(run,"source")],["Mode",val(run,"mode")],["Error",val(run,"errorSummary",val(run,"errorCode","None recorded"))]]);
    table(rows,[["Member","userId"],["Contact","contactNumber"],["Destination","destinationStage"],["Initial decision","initialDecision"],["Final decision","finalDecision"],["Reason",function(r){return val(r,"finalReason")||val(r,"initialReason");}],["Outcome",function(r){return val(r,"outcome",val(r,"finalDecision"));}],["Evaluated UTC","evaluatedAtUtc"]],val(data,"evaluations",[]));
    detailPager(rows,val(data,"evaluationsPagination",{}),"run evaluations",function(page){state.runPage=page;return openRun(id);});
    el.scrollIntoView({block:"nearest"});
  }
  async function renderMember(id) {
    if(state.memberId!==Number(id))state.memberPages={messages:1,evaluations:1,history:1};
    var data=await api("member",{userId:id,messagesPage:state.memberPages.messages,evaluationsPage:state.memberPages.evaluations,historyPage:state.memberPages.history,pageSize:25}),member=val(data,"member",{});if(state.memberId!==Number(id))byId("rcPersonalForm").reset();state.memberId=Number(id);state.reviews.personal=null;
    byId("rcPersonalReview").hidden=true;byId("rcMemberDetail").hidden=false;byId("rcMemberHeading").textContent=val(member,"email")||"Member "+id;
    kv("rcMemberContext",[["Member ID",id],["Next recovery contact",contact(member)],["Current destination stage",destination(member)],["Last accepted contact",val(member,"lastAcceptedContact")?"#"+val(member,"lastAcceptedContact"):"None recorded"],["Last accepted destination",val(member,"lastAcceptedDestination","None recorded")],["Decision",val(member,"decision")],["Reason",val(member,"reason")],["Eligible UTC",val(member,"eligibleAtUtc")],["Paused",val(member,"paused")],["Excluded",val(member,"excluded")],["Returned",val(member,"returned")],["Engaged",val(member,"engaged")]]);
    var controls=empty("rcMemberControls");
    [["pause","Pause recovery"],["resume","Resume recovery"],["exclude","Exclude member"],["remove_exclusion","Remove exclusion"],["refresh","Refresh eligibility"]].forEach(function(item) {
      var b=button(item[1],function(){work(async function(){await api(item[0],{userId:state.memberId,confirmed:"YES"},true);await renderMember(state.memberId);notice(item[1]+" completed.");});});
      if(item[0]==="pause")b.disabled=yes(val(member,"paused"));if(item[0]==="resume")b.disabled=!yes(val(member,"paused"));
      if(item[0]==="exclude")b.disabled=yes(val(member,"excluded"));if(item[0]==="remove_exclusion")b.disabled=!yes(val(member,"excluded"));
      controls.append(b);
    });
    byId("rcPreviewCurrent").disabled=yes(val(member,"sequenceComplete"));
    table("rcMemberMessages",[["Contact",function(r){return val(r,"messageKind")==="PERSONAL"?"Personal":val(r,"contactNumber")?"#"+val(r,"contactNumber")+" of 3":"Unknown";}],["Destination","destinationStage"],["Transport attempt","transportAttemptNumber"],["Result","status"],["Accepted UTC","acceptedAtUtc"],["Attribution deadline UTC","attributionDeadlineUtc"],["Opened","openCount"],["Clicked","clickCount"],["Returned UTC","returnedAtUtc"],["Engaged UTC","engagedAtUtc"],["Preview",function(r){return button("Preview",function(){work(async function(){showPreview(await api("preview",{messageId:val(r,"messageId")}));});},"rc-inline-link");}]],val(data,"messages",[]));
    table("rcMemberEvaluations",[["Evaluated UTC","evaluatedAtUtc"],["Contact","contactNumber"],["Destination stage","destinationStage"],["Initial decision","initialDecision"],["Final decision","finalDecision"],["Reason",function(r){return val(r,"finalReason")||val(r,"initialReason");}],["Outcome",function(r){return val(r,"outcome",val(r,"finalDecision"));}]],val(data,"evaluations",[]));
    var history=val(data,"history",[]),timeline=empty("rcTimeline");
    if(!history.length)timeline.append(node("p","No recorded timeline events.","rc-empty"));
    else {var list=node("ol",undefined,"rc-timeline");history.forEach(function(r){list.append(node("li",text(val(r,"occurredAtUtc"))+" · "+text(val(r,"eventName"))+(val(r,"description",val(r,"reason",""))?" · "+val(r,"description",val(r,"reason","")):"")));});timeline.append(list);}
    ["messages","evaluations","history"].forEach(function(kind){
      var target=kind==="messages"?"rcMemberMessages":kind==="evaluations"?"rcMemberEvaluations":"rcTimeline";
      detailPager(target,val(data,kind+"Pagination",{}),kind,function(page){state.memberPages[kind]=page;return renderMember(state.memberId);});
    });
    byId("rcPersonalForm").querySelector("button").disabled=yes(val(member,"paused"))||yes(val(member,"excluded"));
  }
  function openMember(id) {work(async function(){switchTab("members");await renderMember(id);byId("rcMemberDetail").scrollIntoView({block:"start"});});}
  function showPreview(data) {
    byId("rcPreviewTitle").textContent=val(data,"subject")||"Email preview";
    byId("rcPreviewText").textContent=val(data,"textBody");
    kv("rcPreviewMeta",[["Template",val(data,"templateId")],["Contact",val(data,"contactNumber")],["Destination",val(data,"destinationStage")]]);
    // Defense in depth: the server redacts secrets; this sandbox also forbids navigation and every network fetch.
    var parsed=new DOMParser().parseFromString(String(val(data,"htmlBody")),"text/html");
    parsed.querySelectorAll("script,img,iframe,frame,object,embed,link,base,form,meta,video,audio,source").forEach(function(el){el.remove();});
    parsed.querySelectorAll("*").forEach(function(el){Array.from(el.attributes).forEach(function(attr){if(/^on/i.test(attr.name)||/^(href|src|srcset|action|formaction|poster)$/i.test(attr.name))el.removeAttribute(attr.name);});});
    var csp=parsed.createElement("meta");csp.httpEquiv="Content-Security-Policy";csp.content="default-src 'none'; style-src 'unsafe-inline'; img-src 'none'; form-action 'none'; base-uri 'none'";parsed.head.prepend(csp);
    byId("rcPreviewFrame").srcdoc="<!doctype html>"+parsed.documentElement.outerHTML;
    if(!byId("rcPreviewDialog").open)byId("rcPreviewDialog").showModal();
  }
  function reviewImpact(target,data) {
    var value=val(data,"impact",data),pairs=[];
    Object.keys(value).forEach(function(k){if(!/token|html|body|preview|confirmation|fingerprint/i.test(k)&&typeof value[k]!=="object")pairs.push([k.replace(/([A-Z])/g," $1"),value[k]]);});
    kv(target,pairs.length?pairs:[["Review",val(data,"message","Review prepared.")]]);
    if(Number(val(value,"newlyImmediate",0))>0)byId(target).prepend(node("p","Warning: "+val(value,"newlyImmediate")+" members become immediately eligible under these settings.","rc-notice is-error"));
    var rows=val(value,"rows",[]);
    if(rows.length){var details=node("div");byId(target).append(details);table(details,[["Member","userId"],["Contact","contactNumber"],["Destination","destinationStage"],["Before UTC","before"],["After UTC","after"],["Current decision","priorDecision"],["Proposed decision","nextDecision"]],rows);}
  }
  document.querySelectorAll("[data-tab]").forEach(function(b){b.addEventListener("click",function(){if(state.busy)return;switchTab(b.dataset.tab);work(loadView);});b.addEventListener("keydown",function(e){if(e.key!=="ArrowLeft"&&e.key!=="ArrowRight")return;e.preventDefault();var tabs=Array.from(document.querySelectorAll("[data-tab]")),index=tabs.indexOf(b),next=tabs[(index+(e.key==="ArrowRight"?1:tabs.length-1))%tabs.length];next.focus();next.click();});});
  byId("rcRefresh").addEventListener("click",function(){work(loadView);});
  [["rcQueueFilter","queue"],["rcMemberFilter","members"],["rcPerformanceFilter","performance"]].forEach(function(item){byId(item[0]).addEventListener("submit",function(e){e.preventDefault();state.pages[item[1]]=1;work(loadView);});});
  byId("rcPreviewCurrent").addEventListener("click",function(){work(async function(){showPreview(await api("preview",{userId:state.memberId}));});});
  byId("rcPreviewClose").addEventListener("click",function(){byId("rcPreviewDialog").close();byId("rcPreviewFrame").srcdoc="";});
  byId("rcSettingsForm").addEventListener("input",function(){state.reviews.settings=null;byId("rcSettingsReview").hidden=true;});
  byId("rcSettingsForm").addEventListener("submit",function(e){e.preventDefault();work(async function(){var data=await api("settingsPreview",Object.assign(fields("rcSettingsForm"),{revision:state.settingsRevision}),true);state.reviews.settings=val(data,"reviewToken");reviewImpact("rcSettingsImpact",data);byId("rcSettingsReview").hidden=false;byId("rcSettingsConfirm").checked=false;byId("rcSettingsSave").disabled=true;});});
  byId("rcSettingsConfirm").addEventListener("change",function(){byId("rcSettingsSave").disabled=!this.checked;});
  byId("rcSettingsSave").addEventListener("click",function(){if(!state.reviews.settings||!byId("rcSettingsConfirm").checked)return;work(async function(){var token=state.reviews.settings;state.reviews.settings=null;byId("rcSettingsSave").disabled=true;await api("settingsSave",{reviewToken:token,confirmed:"YES"},true);byId("rcSettingsReview").hidden=true;await loadView();notice("Reviewed timing settings saved. No mail was sent.");});});
  byId("rcResetPreview").addEventListener("click",function(){work(async function(){var data=await api("resetPreview",{},true);state.reviews.reset=val(data,"reviewToken");reviewImpact("rcResetImpact",data);byId("rcResetReview").hidden=false;byId("rcResetConfirm").checked=false;byId("rcResetCommit").disabled=true;});});
  byId("rcResetConfirm").addEventListener("change",function(){byId("rcResetCommit").disabled=!this.checked;});
  byId("rcResetCommit").addEventListener("click",function(){if(!state.reviews.reset||!byId("rcResetConfirm").checked)return;work(async function(){var token=state.reviews.reset;state.reviews.reset=null;byId("rcResetCommit").disabled=true;var result=await api("resetCommit",{reviewToken:token,confirmed:"YES"},true);byId("rcResetReview").hidden=true;await loadView();notice("Recovery start reset recorded. "+text(val(result,"count",val(result,"resetCohortCount")))+" enrollments; UTC "+text(val(result,"resetAtUtc"))+".");});});
  byId("rcPersonalForm").addEventListener("input",function(){state.reviews.personal=null;byId("rcPersonalReview").hidden=true;});
  byId("rcPersonalForm").addEventListener("submit",function(e){e.preventDefault();work(async function(){var data=await api("personalPreview",Object.assign(fields("rcPersonalForm"),{userId:state.memberId}),true);state.reviews.personal=val(data,"reviewToken");var preview=val(data,"preview",data);byId("rcPersonalReviewSummary").textContent="Recipient: "+text(val(data,"recipient",val(preview,"recipient",val(preview,"toEmail"))))+" · Subject: "+text(val(preview,"subject"));showPreview(preview);byId("rcPersonalReview").hidden=false;byId("rcPersonalConfirm").checked=false;byId("rcPersonalSend").disabled=true;});});
  byId("rcPersonalConfirm").addEventListener("change",function(){byId("rcPersonalSend").disabled=!this.checked;});
  byId("rcPersonalSend").addEventListener("click",function(){if(!state.reviews.personal||!byId("rcPersonalConfirm").checked)return;work(async function(){var token=state.reviews.personal;state.reviews.personal=null;byId("rcPersonalSend").disabled=true;var result=await api("personalSend",{reviewToken:token,confirmed:"YES"},true);await renderMember(state.memberId);notice("Personal follow-up result: "+text(val(result,"status",val(result,"code")))+". No automatic retry was attempted.");});});
  work(loadView);
}());
