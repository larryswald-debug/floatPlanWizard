#!/usr/bin/env python3
"""Run the Phase 3 TestBox suite in a private, disposable CF + MySQL sandbox.

From FPW: python3 tests/support/run-arrival-delivery-phase3-isolated.py
Prerequisites: local Docker engine, cfdev-cf and cfdev-mysql, cached ColdFusion,
MySQL and MailHog images listed below, and the installed FPW testbox/system.
In-memory captures and routine and arrival SMTP submissions to an isolated MailHog are
verified. No external mail, image pulls or published ports. Drop the sandbox on exit.
"""
from email import policy
from email.parser import Parser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid

REPO = Path(__file__).resolve().parents[2]
MIGRATIONS = ("20261101_001_arrival_overdue_monitoring", "20261101_002_arrival_overdue_delivery",
              "20261102_001_shore_arrival_time_change", "20261103_001_routine_checkpoint_kind")
TABLES = ("rollout", "watches", "revisions", "events", "dispatch_control", "notices", "deliveries", "attempts")
CF_IMAGE = "cfdev-coldfusion-mysql:latest"
DB_IMAGE = "mysql:8.0"
MAILHOG_IMAGE = "mailhog/mailhog:v1.0.1"


def call(*argv, data=None, env=None, required=True, timeout=150):
    result = subprocess.run(argv, input=data, env=env, capture_output=True, timeout=timeout)
    if required and result.returncode:
        # Never include argument/environment dumps or fixture SQL credentials in errors.
        raise RuntimeError(f"Command failed ({result.returncode}): {argv[0]} {argv[1]}")
    return result


def wait_for(ready, what, timeout=120):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        if ready():
            return
        time.sleep(1)
    raise RuntimeError(f"Timed out waiting for {what}")


def main():
    context = call("docker", "context", "show").stdout.decode().strip()
    context_endpoint = json.loads(call("docker", "context", "inspect", context).stdout)[0]["Endpoints"]["docker"]["Host"]
    endpoints = [context_endpoint, os.environ.get("DOCKER_HOST", context_endpoint)]
    if not all(endpoint.startswith("unix://") for endpoint in endpoints):
        raise RuntimeError("A local Unix-socket Docker engine is required")
    if not (REPO / "testbox/system").is_dir():
        raise RuntimeError("Install the local FPW TestBox framework first")
    for image in (CF_IMAGE, DB_IMAGE, MAILHOG_IMAGE):
        call("docker", "image", "inspect", image)
    for name, image in (("cfdev-cf", CF_IMAGE), ("cfdev-mysql", DB_IMAGE)):
        image_id = call("docker", "image", "inspect", image, "--format", "{{.Id}}").stdout.strip()
        source_id = call("docker", "inspect", name, "--format", "{{.Image}}").stdout.strip()
        if source_id != image_id:
            raise RuntimeError(f"{name} does not use the expected cached dev image {image}")
    tag = uuid.uuid4().hex[:12]
    network, db, cf, mailhog = ("fpw-arrival-" + kind + "-" + tag for kind in ("net", "db", "cf", "mailhog"))
    secret = uuid.uuid4().hex + uuid.uuid4().hex
    nonce = str(uuid.uuid4())
    env = dict(os.environ, MYSQL_ROOT_PASSWORD=secret, password=secret, FPW_ARRIVAL_RECIPIENT_KEY=uuid.uuid4().hex)
    sandbox_label = "fpw.arrival.test=" + tag

    def dbsql(statement):
        payload = statement.encode() if isinstance(statement, str) else statement
        return call("docker", "exec", "-i", db, "sh", "-c",
                    'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot --protocol=socket FPW',
                    data=payload).stdout.decode()

    def get(path):
        return call("docker", "exec", cf, "curl", "-sS", "--max-time", "110",
                    "http://localhost:8500/" + path, required=False)

    with tempfile.TemporaryDirectory(prefix="fpw-arrival-p3-") as directory:
        temp = Path(directory)
        app = temp / "site/fpw"
        (temp / "site/testbox").mkdir(parents=True)
        app.mkdir()
        # Copy CF source only. API logs, real app config, uploads, secrets and mail spools are excluded.
        for folder in ("api/v1", "includes"):
            (app / folder).mkdir(parents=True)
            for source in (REPO / folder).glob("*.cfc"):
                shutil.copyfile(source, app / folder / source.name)
        for rel in ("tests/arrival-delivery-phase3-runner.cfm", "tests/specs/ArrivalDeliveryPhase3Spec.cfc",
                    "tests/support/CompletedContactFixture.cfc", "tests/support/ArrivalCaptureTransport.cfc"):
            dest = app / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / rel, dest)
        checked_files = ("api/v1/AdminScheduledTaskConfig.cfc","api/v1/ArrivalHandoffGate.cfc","api/v1/ArrivalOverdueDeliveryService.cfc",
                         "api/v1/ArrivalOverdueMailService.cfc","api/v1/ArrivalOverdueService.cfc","api/v1/floatplan.cfc","api/v1/monitor.cfc",
                         "api/v1/RouteProgressService.cfc","tests/arrival-delivery-phase3-runner.cfm",
                         "tests/specs/ArrivalDeliveryPhase3Spec.cfc","tests/support/ArrivalCaptureTransport.cfc")
        digests = {rel:hashlib.sha256((app/rel).read_bytes()).hexdigest() for rel in checked_files}
        (app / "Application.cfc").write_text(
            'component {this.name="ArrivalP3' + tag + '";this.sessionManagement=true;this.datasource="fpw";'
            'this.mappings={"/fpw"="/app/fpw","/testbox"="/app/testbox","/CFIDE"="/opt/coldfusion/cfusion/wwwroot/CFIDE"};'
            'function onApplicationStart(){application.env="dev";application.dsn="fpw";'
            'application.arrivalPhase3SandboxId="' + nonce + '";return true;}}')
        (temp / "site/index.cfm").write_text("<cfoutput>ARRIVAL_PRIVATE_READY</cfoutput>")
        (app / "setup-db.cfm").write_text(
            '<cfsetting showdebugoutput="false"><cfscript>try {'
            'pw=createObject("java","java.lang.System").getenv("password");'
            'createObject("component","CFIDE.adminapi.administrator").login(pw);'
            'createObject("component","CFIDE.adminapi.datasource").setOther(name="fpw",'
            'url="jdbc:mysql://db:3306/FPW?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC",'
            'driver="com.mysql.cj.jdbc.Driver",class="com.mysql.cj.jdbc.Driver",username="root",password=pw);'
            'q=queryExecute("SELECT DATABASE() AS db",{}, {datasource="fpw"});writeOutput(q.db[1]);'
            '}catch(any e){writeOutput("SETUP_FAILED");}</cfscript>')
        temp.chmod(0o755)
        call("docker", "network", "create", "--internal", "--label", sandbox_label, network)
        try:
            call("docker","run","--pull","never","-d","--name",mailhog,"--network",network,
                 "--network-alias","mailhog","--label",sandbox_label,MAILHOG_IMAGE)
            call("docker","run","--pull","never","-d","--name",db,"--network",network,"--network-alias","db",
                 "--label",sandbox_label,"--tmpfs","/var/lib/mysql","-e","MYSQL_ROOT_PASSWORD",
                 "-e","MYSQL_ROOT_HOST=%","-e","MYSQL_DATABASE=FPW",DB_IMAGE,env=env)
            call("docker","run","--pull","never","-d","--name",cf,"--network",network,"--label",sandbox_label,
                 "-e","acceptEULA=YES","-e","password","-e","enableSecureProfile=false",
                 # Conflicting legacy process settings must never enable transport without the site's scheduler JSON.
                 "-e","FPW_ARRIVAL_EMAIL_ENABLED=true","-e","FPW_ARRIVAL_RECIPIENT_KEY",
                 "-v",str(temp/"site")+":/app:ro","-v",str(REPO/"testbox")+":/app/testbox:ro",CF_IMAGE,env=env)
            wait_for(lambda: call("docker","exec",db,"sh","-c",
                'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h127.0.0.1 -uroot FPW -e "SELECT 1"',
                required=False).returncode==0,"private SQL")
            # Read schema from the named local dev container. No table rows or routines are exported.
            ignored = ["--ignore-table=FPW.fpw_arrival_"+t for t in TABLES]
            ddl = call("docker","exec","cfdev-mysql","sh","-c",
                       'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --no-data --skip-triggers '
                       '--no-tablespaces --set-gtid-purged=OFF --skip-add-drop-table "$@"',
                       "arrival-schema",*ignored,"FPW").stdout
            dbsql(ddl)
            for prefix in MIGRATIONS:
                for stage in ("preflight","up","verify"):
                    out=dbsql((REPO/"database/migrations"/(prefix+"."+stage+".sql")).read_bytes())
                    if stage!="up" and "PASS" not in out:
                        raise RuntimeError(f"Migration {prefix} {stage} did not pass")
            dbsql("CREATE TABLE fpw_arrival_test_sandbox(run_nonce CHAR(36) PRIMARY KEY); "
                  "INSERT INTO fpw_arrival_test_sandbox VALUES ('"+nonce+"');")
            wait_for(lambda: b"ARRIVAL_PRIVATE_READY" in get("index.cfm").stdout,"private ColdFusion")
            if get("fpw/setup-db.cfm").stdout.strip()!=b"FPW":
                raise RuntimeError("Private ColdFusion datasource setup failed")
            (app/"setup-db.cfm").unlink()
            # Install Adobe's mail tag offline. Both explicit arrival SMTP and
            # the routine cfmail default point to the sandbox's private MailHog.
            bundles=json.loads(call("docker","exec",cf,"cat","/opt/coldfusion/bundles/bundlesdependency.json").stdout)
            mail=next(b for b in bundles if b.get("bundle")=="mail")
            jar_names=["mail-"+mail["version"]+".jar"]
            jar_names += [x["name"]+"-"+x["version"]+".jar" for x in mail.get("dependencies",[])]
            for name in jar_names:
                if not re.fullmatch(r"[a-zA-Z0-9_.-]+\.jar",name):
                    raise RuntimeError("Unexpected offline package name")
                matches=call("docker","exec","cfdev-cf","find","/opt/coldfusion/bundles","-type","f","-name",name).stdout.decode().splitlines()
                if not matches:
                    raise RuntimeError(f"Required local CF package file is absent: {name}")
                call("docker","cp","cfdev-cf:"+matches[0],str(temp/name))
                call("docker","cp",str(temp/name),cf+":"+matches[0])
            call("docker","exec",cf,"/opt/coldfusion/cfusion/bin/cfpm.sh","install","mail:"+mail["version"])
            mail_setup = app / "setup-mail.cfm"
            mail_setup.write_text('<cfsetting showdebugoutput="false"><cfscript>'
                'createObject("component","CFIDE.adminapi.administrator").login(createObject("java","java.lang.System").getenv("password"));'
                'createObject("component","CFIDE.adminapi.mail").setMailServer("mailhog",1025);writeOutput("MAIL_READY");</cfscript>')
            if get("fpw/setup-mail.cfm").stdout.strip() != b"MAIL_READY":
                raise RuntimeError("Private ColdFusion mail setup failed")
            mail_setup.unlink()
            mailbox_url = "http://mailhog:8025/api/v2/messages?limit=5"
            wait_for(lambda: call("docker","exec",cf,"curl","-fsS","--max-time","3",mailbox_url,
                                  required=False).returncode==0, "private MailHog")
            response=get("fpw/tests/arrival-delivery-phase3-runner.cfm?confirm=RUN_ARRIVAL_DELIVERY_PHASE3_TESTS")
            document=json.loads(response.stdout)
            summary=document.get("RESULTS",{})
            cases=[{"name":r["NAME"],"status":r["STATUS"],"message":r["MESSAGE"]} for r in summary.get("SPECS",[])]
            residue=dbsql("SELECT (SELECT COUNT(*) FROM users) AS users,(SELECT COUNT(*) FROM floatplans) AS plans,"
                "(SELECT COUNT(*) FROM fpw_arrival_notices) AS notices,(SELECT COUNT(*) FROM fpw_arrival_deliveries) AS deliveries,"
                "(SELECT COUNT(*) FROM fpw_arrival_attempts) AS attempts,(SELECT COUNT(*) FROM floatplan_alert_history) AS routine_alerts,"
                "(SELECT COUNT(*) FROM fpw_arrival_dispatch_control WHERE plan_id<>0 AND mode<>'OFF') AS enabled_fixture_scopes,"
                "(SELECT mode FROM fpw_arrival_dispatch_control WHERE plan_id=0) AS global_mode").splitlines()
            cleanup_counts=dict(zip(residue[0].split("\t"),residue[1].split("\t")))
            ok=document.get("SUCCESS")==True and cleanup_counts.pop("global_mode",None)=="OFF" and all(v=="0" for v in cleanup_counts.values())
            audit=dbsql("SELECT VERSION() AS mysql_version,(SELECT COUNT(*) FROM fpw_arrival_watches) AS watches,"
                "(SELECT COUNT(*) FROM fpw_arrival_revisions) AS revisions,(SELECT COUNT(*) FROM fpw_arrival_events) AS events,"
                "(SELECT COUNT(*) FROM fpw_arrival_dispatch_control WHERE plan_id>0 AND mode='OFF') AS retired_synthetic_scopes").splitlines()
            audit_counts=dict(zip(audit[0].split("\t"),audit[1].split("\t")))
            ok=ok and all(audit_counts[k]=="0" for k in ("watches","revisions","events"))
            def read_mailbox():
                return json.loads(call("docker","exec",cf,"curl","-fsS","--max-time","5",mailbox_url).stdout)
            if ok:
                wait_for(lambda: read_mailbox()["total"] >= 5, "five private SMTP messages", timeout=60)
            mailbox=read_mailbox()
            verified_notices={}
            for item in mailbox["items"]:
                message=Parser(policy=policy.default).parsestr(item["Raw"]["Data"])
                recipients=item["Raw"]["To"]
                if len(recipients)!=1:
                    continue
                fixture=re.fullmatch(r"(ccv-[a-f0-9]+)(-shore|-updated)?@example\.test",recipients[0])
                part=message.get_body(preferencelist=("plain",))
                if not fixture or not part:
                    continue
                body=part.get_content()
                if "Float Plan: "+fixture.group(1) not in body:
                    continue
                if message["Subject"] == "FPW Automated Notice: Scheduled Check-In Not Recorded - "+fixture.group(1) and not fixture.group(2):
                    verified_notices["routine_captain"]=fixture.group(1)
                    continue
                if message["Subject"] == "FPW Automated Notice: Check-In Still Unresolved - "+fixture.group(1) and fixture.group(2) == "-shore":
                    verified_notices["routine_shore"]=fixture.group(1)
                    continue
                if fixture.group(2)=="-updated":
                    if (message["Subject"]=="FloatPlanWizard Update: Expected Arrival Time Changed"
                        and re.search(r"Previous expected arrival: .*3:00 PM \(America/New_York\).*19:00:00 UTC",body)
                        and re.search(r"New expected arrival: .*1:00 PM \(America/Chicago\).*18:00:00 UTC",body)):
                        verified_notices["arrival_change"]=fixture.group(1)
                    continue
                if "Scheduled final arrival:" not in body:
                    continue
                if fixture.group(2) and message["Subject"]=="FloatPlanWizard Alert: Expected Arrival Time Has Passed":
                    verified_notices["shore"]=fixture.group(1)
                elif not fixture.group(2) and message["Subject"]=="FloatPlanWizard Reminder: Close Your Float Plan" and "close your float plan" in body:
                    verified_notices["captain"]=fixture.group(1)
            verified_mail=(mailbox["total"]==5 and len(verified_notices)==5
                           and verified_notices["captain"]==verified_notices["shore"]
                           and verified_notices["routine_captain"]==verified_notices["routine_shore"])
            ok=ok and verified_mail
            print(json.dumps({"synthetic_capture_only":True,"mailhog_messages":mailbox["total"],
                              "mailhog_notice_verified":verified_mail,"mailhog_recipient_roles":sorted(verified_notices),
                              "cf_version":summary.get("CFVERSION"),
                              "source_sha256":digests,"disposable_db":audit_counts,"passed":summary.get("TOTALPASS"),"failed":summary.get("TOTALFAIL"),
                              "errors":summary.get("TOTALERROR"),"cases":cases,"residue":residue,"ok":ok},indent=2))
            if not ok:
                raise RuntimeError("Isolated behavioral validation failed")
        finally:
            # Nothing in a named dev container or volume is removed.
            for name in (cf,db,mailhog):
                owner=call("docker","inspect",name,"--format",'{{index .Config.Labels "fpw.arrival.test"}}',required=False)
                if owner.stdout.decode().strip()==tag:
                    call("docker","rm","-fv",name)
            call("docker","network","rm",network)


if __name__=="__main__":
    main()
