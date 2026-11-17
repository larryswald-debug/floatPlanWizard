// Run with MCP Playwright browser_run_code_unsafe(filename=absolute path to this file).
// All browser requests are fulfilled locally or aborted. Only the generic SDK GET
// and read-only localhost fixture GETs use the network; no project event is sent.
async (page) => {
    const base = 'http://localhost:8500/fpw';
    const production = 'https://floatplanwizard.com';
    const key = 'phc_xkD8U29Qbrh7cdnqGTVPDLcjazzUD9ztQCYZNjnjP7vs';
    const sdkResponse = await page.request.get('https://us-assets.i.posthog.com/static/array.js');
    if (!sdkResponse.ok()) throw new Error('Cannot retrieve the generic PostHog SDK');
    const sdk = await sdkResponse.text();
    const fixtureUrl = name => base + '/tests/posthog-render-fixture.cfm?confirm=POSTHOG_LOCAL_TEST&case=' + name;
    const matrix = await (await page.request.get(fixtureUrl('all'))).json();
    const assert = (condition, message) => { if (!condition) throw new Error(message); };
    assert(matrix.SUCCESS && matrix.LOCAL_INCLUDE_SUPPRESSED, 'Server eligibility fixture failed');
    const report = { sdkBytes: sdk.length, liveProjectRequestsSent: 0, serverCases: matrix.CASES.length, browserCases: [], clientRouteCases: [], failures: [] };
    const snippets = {};
    async function snippet(name) {
        if (!(name in snippets)) {
            const response = await page.request.get(fixtureUrl(name));
            const json = await response.json();
            assert(response.ok() && json.SUCCESS, 'Invalid fixture ' + name);
            snippets[name] = json.CASES[0].HTML;
        }
        return snippets[name];
    }
    async function decode(p, bytes) {
        const raw = await p.evaluate(async bytes => {
            const buffer = new Uint8Array(bytes);
            if (buffer[0] === 31 && buffer[1] === 139) {
                return await new Response(new Blob([buffer]).stream().pipeThrough(new DecompressionStream('gzip'))).text();
            }
            return new TextDecoder().decode(buffer);
        }, bytes);
        if (raw.startsWith('data=')) {
            return JSON.parse(Buffer.from(new URLSearchParams(raw).get('data'), 'base64').toString('utf8'));
        }
        return JSON.parse(raw);
    }
    async function checkCase(options) {
        const context = await page.context().browser().newContext();
        const p = await context.newPage();
        const requests = [], errors = [];
        p.on('pageerror', error => errors.push(error.message));
        try {
            const html = '<!doctype html><html><head><link rel="canonical" href="' + (options.canonical || options.url.split('?')[0].split('#')[0]) + '">' +
                await snippet(options.fixture || 'homepage') + '</head><body><button>Public page</button></body></html>';
            if (options.cookie) {
                // Eligibility must not depend on cookies. This is synthetic, not authenticated account proof.
                await context.addCookies([{name:'FPWFixtureMember',value:'true',domain:'floatplanwizard.com',path:'/'}]);
            }
            if (options.poison) {
                await context.addInitScript(({key}) => {
                    if (location.origin !== 'https://floatplanwizard.com') return;
                    localStorage.setItem('ph_' + key + '_posthog', JSON.stringify({
                        distinct_id: '018f0000-0000-7000-8000-000000000001',
                        $device_id: '018f0000-0000-7000-8000-000000000001',
                        $user_state: 'anonymous',
                        member_email:'PRIVATE_SENTINEL@example.test',
                        contact:{name:'PRIVATE_SENTINEL'},
                        tripId:'PRIVATE_SENTINEL',
                        $set:{email:'PRIVATE_SENTINEL@example.test'},
                        $set_once:{follow_token:'PRIVATE_SENTINEL'},
                        $initial_person_info:{r:'https://floatplanwizard.com/follow/?t=PRIVATE_SENTINEL',u:'https://floatplanwizard.com/app/active-cruise.cfm?id=PRIVATE_SENTINEL'},
                        $initial_current_url:'https://floatplanwizard.com/follow/?t=PRIVATE_SENTINEL',
                        $initial_referrer:'https://floatplanwizard.com/follow/?t=PRIVATE_SENTINEL',
                        $session_entry_url:'https://floatplanwizard.com/follow/?t=PRIVATE_SENTINEL',
                        $session_entry_referrer:'https://floatplanwizard.com/follow/?t=PRIVATE_SENTINEL'
                    }));
                }, {key});
            }
            await context.route('**/*', async route => {
                const request = route.request(), url = new URL(request.url());
                if (url.hostname === 'us-assets.i.posthog.com' && url.pathname === '/static/array.js') {
                    requests.push({kind:'sdk',url:request.url(),headers:await request.allHeaders()});
                    await route.fulfill({status:200,contentType:'application/javascript',headers:{'access-control-allow-origin':'*'},body:sdk});
                } else if (/(^|\.)posthog\.com$/.test(url.hostname)) {
                    requests.push({kind:'event',url:request.url(),headers:await request.allHeaders(),bytes:Array.from(request.postDataBuffer() || [])});
                    await route.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:'{}'});
                } else if (url.origin === production || url.origin === 'https://www.floatplanwizard.com') {
                    await route.fulfill({status:200,contentType:'text/html',body:url.pathname === '/follow/' ?
                        '<!doctype html><a id="public" href="' + options.url.replace(/&/g,'&amp;') + '">Public guide</a>' : html});
                } else {
                    await route.abort();
                }
            });
            if (options.follow) {
                await p.goto(production + '/follow/?slug=PRIVATE_SENTINEL&t=PRIVATE_SENTINEL&stream_id=PRIVATE_SENTINEL');
                await p.locator('#public').click();
            } else {
                await p.goto(options.url, {referer:options.referrer});
            }
            await p.waitForFunction(() => window.posthog && posthog.__loaded && !Array.isArray(posthog));
            for (let i=0; i<40 && !requests.some(r=>r.kind==='event'); i++) await p.waitForTimeout(100);
            assert(requests.some(r=>r.kind==='event'), 'Missing pageview');
            const config = await p.evaluate(() => ({
                version:posthog.version, capture_pageview:posthog.config.capture_pageview,
                autocapture:posthog.config.autocapture, disable_session_recording:posthog.config.disable_session_recording,
                person_profiles:posthog.config.person_profiles, capture_pageleave:posthog.config.capture_pageleave,
                advanced_disable_flags:posthog.config.advanced_disable_flags,
                identifiedRejected:posthog.config.before_send({event:'$pageview',properties:{distinct_id:'018f0000-0000-7000-8000-000000000001',$is_identified:true}})===null,
                memberIdRejected:posthog.config.before_send({event:'$pageview',properties:{distinct_id:'member@example.test'}})===null,
                customRejected:posthog.config.before_send({event:'private_beta_event',properties:{distinct_id:'018f0000-0000-7000-8000-000000000001'}})===null
            }));
            if (options.poison) assert(await p.evaluate(() => posthog.get_property('member_email') === 'PRIVATE_SENTINEL@example.test'), 'Persisted private data was not exercised');
            assert(config.capture_pageview===true && config.autocapture===false && config.disable_session_recording===true && config.person_profiles==='never' &&
                config.capture_pageleave===false && config.advanced_disable_flags===true && config.identifiedRejected && config.memberIdRejected && config.customRejected, 'Unexpected config');
            const attribution = await p.evaluate(() => posthog.config.before_send({
                event:'$pageview',
                properties:{
                    distinct_id:'018f0000-0000-7000-8000-000000000001',
                    $initial_current_url:'https://floatplanwizard.com/boating-guides/?utm_source=FirstVisit&token=PRIVATE_SENTINEL#PRIVATE_SENTINEL',
                    $session_entry_url:'https://floatplanwizard.com/?utm_medium=email&authIntent=PRIVATE_SENTINEL',
                    $initial_referrer:'https://floatplanwizard.com/follow/?t=PRIVATE_SENTINEL',
                    $session_entry_referrer:'https://example.test/private?email=PRIVATE_SENTINEL',
                    email:'PRIVATE_SENTINEL', $set:{email:'PRIVATE_SENTINEL'},$set_once:{tripId:'PRIVATE_SENTINEL'}
                }
            }));
            assert(!JSON.stringify(attribution).includes('PRIVATE_SENTINEL'), 'Persisted attribution leak');
            assert(attribution.properties.$initial_utm_source==='FirstVisit' && attribution.properties.$session_entry_utm_medium==='email', 'Attribution lost');
            // Custom captures, DOM clicks and same-document changes must not add events.
            await p.evaluate(() => {
                posthog.capture('private_beta_event',{email:'PRIVATE_SENTINEL'});
                document.querySelector('button').click();
                history.pushState({},'',location.pathname + '?token=PRIVATE_SENTINEL#PRIVATE_SENTINEL');
            });
            await p.waitForTimeout(250);
            const actualReferrer=await p.evaluate(()=>document.referrer);
            if(options.follow) assert(actualReferrer.includes('PRIVATE_SENTINEL'), 'Follow referrer was not exercised');
            await p.goto('about:blank'); // Also exercise page leave.
            await p.waitForTimeout(300);
            const events=[];
            for (const request of requests.filter(r=>r.kind==='event')) {
                assert(new URL(request.url).pathname==='/e/', 'Unexpected flags/replay/other request: '+request.url);
                if (request.bytes.length) {
                    const body=await decode(p,request.bytes);
                    events.push(...(body.batch || (Array.isArray(body)?body:[body])));
                }
            }
            assert(events.length===1 && events[0].event==='$pageview', 'Expected one pageview only; received '+events.length);
            const props=events[0].properties;
            assert(props.$current_url===options.expected, 'Unexpected public URL '+props.$current_url);
            if ('expectedReferrer' in options) assert(props.$referrer===options.expectedReferrer, 'Unexpected referrer '+props.$referrer);
            assert(props.token===key && props.$process_person_profile===false && props.$is_identified===false, 'Missing anonymous event settings');
            assert(!JSON.stringify(events).includes('PRIVATE_SENTINEL'), 'Private value in event');
            assert(requests.filter(r=>r.kind==='sdk').length===1, 'Duplicate SDK');
            assert(requests.filter(r=>r.kind==='sdk').every(r=>!r.headers.referer), 'SDK referrer leak');
            assert(!JSON.stringify(requests.map(r=>({url:r.url,headers:r.headers}))).includes('PRIVATE_SENTINEL'), 'Transport metadata leak');
            assert(errors.length===0, 'Browser errors: '+errors.join(';'));
            report.browserCases.push({name:options.name,passed:true,events:events.length,url:props.$current_url,referrer:props.$referrer,sdkVersion:config.version,scriptReferrer:'absent',eventReferrer:requests.find(r=>r.kind==='event').headers.referer||'',privateFollowReferrerExercised:!!options.follow});
        } catch(error) {
            report.failures.push({name:options.name,error:error.message});
        } finally { await context.close(); }
    }
    const cases = [
        {name:'homepage',url:production+'/',expected:production+'/'},
        {name:'Bahamas guide',fixture:'bahamas',url:production+'/boating-guides/bahamas/',expected:production+'/boating-guides/bahamas/'},
        {name:'Chicago locks',fixture:'locks',url:production+'/great-loop/locks/waterway/chicago-illinois-waterway/',expected:production+'/great-loop/locks/waterway/chicago-illinois-waterway/'},
        {name:'UTM and sensitive query/hash',url:production+'/?utm_source=Newsletter&utm_medium=email&utm_campaign=Winter+Cruise&token=PRIVATE_SENTINEL&authIntent=PRIVATE_SENTINEL&continuationToken=PRIVATE_SENTINEL&resetid=PRIVATE_SENTINEL&tripId=PRIVATE_SENTINEL&email=PRIVATE_SENTINEL#PRIVATE_SENTINEL',expected:production+'/?utm_source=Newsletter&utm_medium=email&utm_campaign=Winter+Cruise'},
        {name:'Private Follow referrer',fixture:'bahamas',url:production+'/boating-guides/bahamas/',expected:production+'/boating-guides/bahamas/',follow:true,expectedReferrer:''},
        {name:'External private referrer',url:production+'/',expected:production+'/',referrer:'https://example.test/private/contact?email=PRIVATE_SENTINEL',expectedReferrer:'https://example.test/'},
        {name:'Persisted private attribution',url:production+'/',expected:production+'/',poison:true},
        {name:'Member cookie on public guide',fixture:'bahamas',url:production+'/boating-guides/bahamas/',expected:production+'/boating-guides/bahamas/',cookie:true},
        {name:'Legacy library canonical',fixture:'publiclegacylocks',url:production+'/app/great-loop-locks.cfm?waterwaySlug=chicago-illinois-waterway&token=PRIVATE_SENTINEL',canonical:production+'/great-loop/locks/waterway/chicago-illinois-waterway/',expected:production+'/great-loop/locks/waterway/chicago-illinois-waterway/'}
    ];
    for (const options of cases) await checkCase(options);
    // Verify every server-allowed context passes the independent client URL gate.
    // Stub the SDK for this matrix; real network behavior is covered above.
    const clientContext=await page.context().browser().newContext();
    try {
        for (const entry of matrix.CASES) {
            if (!entry.EXPECTED) continue;
            const p=await clientContext.newPage();
            const html=await snippet(entry.KEY);
            let loads=0;
            const host=entry.CONTEXT.HOST.replace(/:443$/,'');
            const url='https://'+host+entry.CONTEXT.SCRIPTPATH;
            await p.route('**/*',async route=>{
                if(new URL(route.request().url()).hostname==='us-assets.i.posthog.com') { loads++;await route.fulfill({contentType:'application/javascript',body:''}); }
                else await route.fulfill({contentType:'text/html',body:'<!doctype html><head>'+html+'</head><body>Fixture</body>'});
            });
            await p.goto(url);
            const inits=await p.evaluate(()=>window.posthog && posthog._i ? posthog._i.length : 0);
            report.clientRouteCases.push({name:entry.KEY,passed:loads===1&&inits===1});
            if(loads!==1||inits!==1)report.failures.push({name:entry.KEY,error:'Client/server eligibility mismatch'});
            await p.close();
        }
    } finally {await clientContext.close();}
    report.passed=report.failures.length===0;
    return report;
}
