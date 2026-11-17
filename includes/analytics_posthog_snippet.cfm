<script data-fpw-posthog>
(function () {
    'use strict';
    // Only public pageviews are sent. Do not connect member identity or custom events here.
    var campaignKeys = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content', 'utm_id', 'utm_source_platform', 'utm_creative_format', 'utm_marketing_tactic'];
    var publicHost = /^(www\.)?floatplanwizard\.com$/i;
    var publicPath = /^(?:\/(?:index\.cfm)?|\/boating-guides\/(?:index\.cfm|chesapeake-bay\/(?:index\.cfm)?|bahamas\/(?:index\.cfm|itineraries\/fort-lauderdale-bimini\/(?:index\.cfm)?)?)?|\/great-loop\/trip-planning\/(?:index\.cfm)?|\/great-loop\/(?:locks|ports|anchorages)\/(?:index\.cfm)?|\/great-loop\/bridges(?:\/|\.cfm)|\/great-loop-bridge\.cfm|\/app\/great-loop-(?:locks|lock|ports|port|anchorages|anchorage)\.cfm|\/great-loop\/(?:locks|ports|anchorages|bridges)\/[a-z0-9]+(?:-[a-z0-9]+)*\/|\/great-loop\/locks\/(?:state|waterway)\/[a-z0-9]+(?:-[a-z0-9]+)*\/|\/great-loop\/anchorages\/(?:location|waterway|state|country|type)\/[a-z0-9]+(?:-[a-z0-9]+)*\/|\/great-loop\/bridges\/(?:state|waterway|route)\/[a-z0-9]+(?:-[a-z0-9]+)*\/)$/i;
    var anonymousId = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

    function campaignValue(value) {
        // Preserve ordinary campaign labels; reject emails, URLs, control characters and oversized values.
        return typeof value === 'string' && /^[a-z0-9][a-z0-9 ._~+-]{0,199}$/i.test(value) ? value : '';
    }
    function cleanPublicUrl(value) {
        try {
            var url = new URL(value);
            if (!/^https?:$/.test(url.protocol) || !publicHost.test(url.hostname) || url.port ||
                url.username || url.password || !publicPath.test(url.pathname)) return '';
            var clean = new URL(url.origin + url.pathname);
            campaignKeys.forEach(function (key) {
                var value = campaignValue(url.searchParams.get(key));
                if (value) clean.searchParams.set(key, value);
            });
            return clean.href;
        } catch (error) { return ''; }
    }
    function cleanReferrer(value) {
        if (!value) return '';
        try {
            var url = new URL(value);
            if (!/^https?:$/.test(url.protocol) || url.username || url.password) return '';
            // Same-site private routes are not attribution. External attribution needs only the origin.
            if (publicHost.test(url.hostname)) return cleanPublicUrl(value);
            return url.origin + '/';
        } catch (error) { return ''; }
    }
    function addCampaigns(target, url, prefix) {
        if (!url) return;
        var params = new URL(url).searchParams;
        campaignKeys.forEach(function (key) {
            var value = campaignValue(params.get(key));
            if (value) target[prefix + key] = value;
        });
    }
    function domain(url) {
        try { return url ? new URL(url).hostname : ''; } catch (error) { return ''; }
    }

    var currentUrl = cleanPublicUrl(window.location.href);
    if (!currentUrl) return;
    // Canonical URLs keep rewritten library query selectors out of pageview attribution.
    var canonical = document.querySelector('link[rel="canonical"]');
    var canonicalUrl = canonical && cleanPublicUrl(canonical.href);
    if (canonicalUrl) {
        var currentCampaigns = new URL(currentUrl).search;
        currentUrl = new URL(canonicalUrl).origin + new URL(canonicalUrl).pathname + currentCampaigns;
    }

    function publicPageview(event) {
        if (!event || event.event !== '$pageview') return null;
        var source = event.properties || {};
        // SDK-generated UUIDs only: never forward an email/member identifier as distinct_id.
        if (source.$is_identified === true || !anonymousId.test(String(source.distinct_id || ''))) return null;
        var safe = {
            token: 'phc_xkD8U29Qbrh7cdnqGTVPDLcjazzUD9ztQCYZNjnjP7vs',
            distinct_id: source.distinct_id,
            $process_person_profile: false,
            $is_identified: false,
            $current_url: currentUrl,
            $pathname: new URL(currentUrl).pathname,
            $host: new URL(currentUrl).host
        };
        ['$device_id', '$session_id', '$window_id', '$pageview_id'].forEach(function (key) {
            if (anonymousId.test(String(source[key] || ''))) safe[key] = source[key];
        });
        ['$browser', '$browser_version', '$os', '$os_version', '$device', '$device_type', '$lib', '$lib_version', '$timezone'].forEach(function (key) {
            var value = source[key];
            if ((typeof value === 'string' && /^[a-z0-9 ._+()/:-]{1,100}$/i.test(value) && value.indexOf('://') === -1) ||
                (typeof value === 'number' && isFinite(value))) safe[key] = value;
        });
        ['$screen_height', '$screen_width', '$viewport_height', '$viewport_width', '$timezone_offset', '$session_start_timestamp'].forEach(function (key) {
            if (typeof source[key] === 'number' && isFinite(source[key])) safe[key] = source[key];
        });
        safe.$referrer = cleanReferrer(source.$referrer || document.referrer);
        safe.$referring_domain = domain(safe.$referrer);
        addCampaigns(safe, currentUrl, '');
        [
            ['$initial_current_url', '$initial_pathname', '$initial_referrer', '$initial_referring_domain', '$initial_'],
            ['$session_entry_url', '$session_entry_pathname', '$session_entry_referrer', '$session_entry_referring_domain', '$session_entry_']
        ].forEach(function (keys) {
            var url = cleanPublicUrl(source[keys[0]]);
            if (url) {
                safe[keys[0]] = url;
                safe[keys[1]] = new URL(url).pathname;
                addCampaigns(safe, url, keys[4]);
            }
            safe[keys[2]] = cleanReferrer(source[keys[2]]);
            safe[keys[3]] = domain(safe[keys[2]]);
        });
        // Drop unknown persisted properties, search terms, IDs and nested $set/$set_once payloads.
        var result = { event: '$pageview', properties: safe };
        if (event.timestamp) result.timestamp = event.timestamp;
        if (anonymousId.test(String(event.uuid || ''))) result.uuid = event.uuid;
        return result;
    }

    !function(t,e){var o,n,p,r;e.__SV||(window.posthog && window.posthog.__loaded)||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split(".");2==o.length&&(t=t[o[0]],e=o[1]),t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}}p||((p=t.createElement("script")).type="text/javascript",p.crossOrigin="anonymous",p.referrerPolicy="no-referrer",p.async=!0,p.src=s.api_host.replace(".i.posthog.com","-assets.i.posthog.com")+"/static/array.js",p.onerror=function(){p=null},(r=t.getElementsByTagName("script")[0]).parentNode.insertBefore(p,r));var u=e;for(void 0!==a?u=e[a]=[]:a="posthog",u.people=u.people||[],Object.defineProperty(u,"toString",{configurable:!0,enumerable:!0,writable:!0,value:function(t){var e="posthog";return"posthog"!==a&&(e+="."+a),t||(e+=" (stub)"),e}}),Object.defineProperty(u.people,"toString",{configurable:!0,enumerable:!0,writable:!0,value:function(){return u.toString(1)+".people (stub)"}}),o="Eh Rh Ph Oh Dh qh init yd bd dd fd Sd wc md xd ad Ed Ad Rd Pd Od Fd capture getExtension gr pd gd calculateEventProperties Dd register register_once register_for_session unregister unregister_for_session zd hd jd getFeatureFlag getFeatureFlagPayload getFeatureFlagResult getAllFeatureFlags isFeatureEnabled reloadFeatureFlags updateFlags updateEarlyAccessFeatureEnrollment on onFeatureFlags onSurveysLoaded onSessionId getSurveys getActiveMatchingSurveys onActiveMatchingSurveysChanged renderSurvey displaySurvey cancelPendingSurvey canRenderSurvey canRenderSurveyAsync Hd identify setPersonProperties unsetPersonProperties group resetGroups setPersonPropertiesForFlags resetPersonPropertiesForFlags setGroupPropertiesForFlags resetGroupPropertiesForFlags reset Ud shutdown setIdentity clearIdentity get_distinct_id getGroups get_session_id get_session_replay_url alias set_config startSessionRecording stopSessionRecording sessionRecordingStarted captureException addExceptionStep captureLog startExceptionAutocapture stopExceptionAutocapture loadToolbar get_property getSessionProperty qd Td createPersonProfile setInternalOrTestUser Bd Uh zh opt_in_capturing opt_out_capturing Hh has_opted_in_capturing has_opted_out_capturing get_explicit_consent_status is_capturing clear_opt_in_out_capturing $d debug kc Ds getPageViewId captureTraceFeedback captureTraceMetric rd".split(" "),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__SV=1)}(document,window.posthog||[]);
    posthog.init('phc_xkD8U29Qbrh7cdnqGTVPDLcjazzUD9ztQCYZNjnjP7vs', {
        api_host: 'https://us.i.posthog.com',
        defaults: '2026-05-30',
        capture_pageview: true,
        autocapture: false,
        disable_session_recording: true,
        person_profiles: 'never',
        capture_pageleave: false,
        capture_exceptions: false,
        capture_performance: false,
        capture_dead_clicks: false,
        capture_heatmaps: false,
        disable_capture_url_hashes: true,
        advanced_disable_flags: true,
        disable_external_dependency_loading: true,
        before_send: publicPageview
    })
}());
</script>
