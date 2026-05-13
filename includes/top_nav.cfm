<!-- /includes/top_nav.cfm -->
<cfscript>
userDisplayName = "";
if (structKeyExists(session, "user") && isStruct(session.user)) {
  firstName = "";
  lastName = "";
  if (structKeyExists(session.user, "firstName")) {
    firstName = session.user.firstName;
  } else if (structKeyExists(session.user, "FIRSTNAME")) {
    firstName = session.user.FIRSTNAME;
  } else if (structKeyExists(session.user, "fName")) {
    firstName = session.user.fName;
  } else if (structKeyExists(session.user, "FNAME")) {
    firstName = session.user.FNAME;
  }

  if (structKeyExists(session.user, "lastName")) {
    lastName = session.user.lastName;
  } else if (structKeyExists(session.user, "LASTNAME")) {
    lastName = session.user.LASTNAME;
  } else if (structKeyExists(session.user, "lName")) {
    lastName = session.user.lName;
  } else if (structKeyExists(session.user, "LNAME")) {
    lastName = session.user.LNAME;
  }

  userDisplayName = trim(firstName & " " & lastName);

  if (!len(userDisplayName)) {
    if (structKeyExists(session.user, "email")) {
      userDisplayName = session.user.email;
    } else if (structKeyExists(session.user, "EMAIL")) {
      userDisplayName = session.user.EMAIL;
    }
  }
}
basePath = "";
if (structKeyExists(request, "fpwBase")) {
  basePath = request.fpwBase;
}
if (!len(trim(basePath)) && structKeyExists(cgi, "script_name")) {
  scriptName = toString(cgi.script_name);
  appPathPos = findNoCase("/app/", scriptName);
  if (appPathPos > 1) {
    basePath = left(scriptName, appPathPos - 1);
  }
}

memberDisplayInitials = "FP";
if (len(userDisplayName)) {
  memberInitialParts = listToArray(reReplace(userDisplayName, "\s+", " ", "all"), " ");
  memberDisplayInitials = "";
  memberInitialLimit = arrayLen(memberInitialParts);
  if (memberInitialLimit > 2) {
    memberInitialLimit = 2;
  }
  for (memberInitialPartIndex = 1; memberInitialPartIndex <= memberInitialLimit; memberInitialPartIndex++) {
    if (len(memberInitialParts[memberInitialPartIndex])) {
      memberDisplayInitials = memberDisplayInitials & left(memberInitialParts[memberInitialPartIndex], 1);
    }
  }
  if (!len(memberDisplayInitials)) {
    memberDisplayInitials = left(userDisplayName, 2);
  }
  memberDisplayInitials = uCase(memberDisplayInitials);
}
</cfscript>

<style>
  :root{
    --bg0:#07121f;
    --bg1:#0a1a2b;
    --panel:#0b1a2a;
    --line:rgba(255,255,255,.08);
    --text:rgba(255,255,255,.88);
    --muted:rgba(255,255,255,.62);
    --accent:#35d0c8;
    --accent2:#4aa3ff;
    --shadow: 0 18px 50px rgba(0,0,0,.35);
    --radius:14px;
    --radius2:12px;
    --font: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji","Segoe UI Emoji";
  }

  *{ box-sizing:border-box; }
  body{
    margin:0;
    font-family:var(--font);
    background:#0b1320;
    color:var(--text);
  }

  /* ===== Toggle logic =====
     body:not(.is-logged-in) shows pre-login
     body.is-logged-in shows post-login
  */
  .nav--public{ display:block; }
  .nav--app{ display:block; }
  body.is-logged-in .nav--public,
  body.is-logged-in .loginStrip{ display:none; }
  body.is-logged-in .nav--app{ display:block; }

  /* ===== Shell ===== */
  .topbar{
    position:sticky;
    top:0;
    z-index:1050;
    background:
      radial-gradient(1200px 90px at 10% 0%, rgba(53,208,200,.18), transparent 55%),
      radial-gradient(900px 110px at 85% 10%, rgba(74,163,255,.16), transparent 60%),
      linear-gradient(180deg, var(--bg0), var(--bg1));
    border-bottom:1px solid var(--line);
  }
  .topbar.nav--public,
  .topbar.nav--app{
    position:sticky !important;
    top:0 !important;
    z-index:1051 !important;
  }
  .inner{
    max-width:1200px;
    margin:0 auto;
    padding:12px 16px;
    display:flex;
    align-items:center;
    gap:16px;
  }

  /* ===== Brand ===== */
  .brand{
    display:flex;
    align-items:center;
    gap:10px;
    text-decoration:none;
    color:inherit;
    min-width: 300px;
  }
  .logo{
    width:34px; height:34px; border-radius:10px;
    background:
      radial-gradient(circle at 30% 20%, rgba(255,255,255,.35), transparent 40%),
      linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75));
    box-shadow: 0 8px 18px rgba(0,0,0,.25);
    flex:0 0 auto;
  }
  .brandTitle{
    font-weight:900;
    letter-spacing:.2px;
    line-height:1.05;
  }
  .tagline{
    font-size:.92rem;
    color:var(--muted);
    margin-top:2px;
    line-height:1.15;
  }

  /* ===== Public nav ===== */
  .navLinks{
    display:flex;
    align-items:center;
    gap:14px;
    flex-wrap:wrap;
  }
  .navLinks a{
    color:var(--muted);
    text-decoration:none;
    font-weight:700;
    padding:8px 6px;
    border-radius:10px;
  }
  .navLinks a:hover{
    color:var(--text);
    background:rgba(255,255,255,.05);
  }

  /* ===== Actions / buttons ===== */
  .actions{
    margin-left:auto;
    display:flex;
    align-items:center;
    gap:10px;
  }
  .btn{
    border-radius:10px;
    padding:8px 12px;
    font-weight:800;
    font-size:.92rem;
    border:1px solid var(--line);
    background: rgba(255,255,255,.04);
    color:var(--text);
    text-decoration:none;
    display:inline-flex;
    align-items:center;
    gap:8px;
    cursor:pointer;
    user-select:none;
  }
  .btn:hover{ background: rgba(255,255,255,.07); }
  .btnPrimary{
    border-color: rgba(53,208,200,.35);
    background: linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75));
    color:#021018;
  }
  .divider{
    width:1px; height:26px;
    background:var(--line);
    margin:0 4px;
  }

  /* ===== Login strip (pre-login) ===== */
  section.loginStrip{
    position:fixed;
    left:0;
    right:0;
    top:0;
    z-index:1040;
    display:block !important;
    background:
      radial-gradient(1200px 90px at 10% 0%, rgba(53,208,200,.18), transparent 55%),
      radial-gradient(900px 110px at 85% 10%, rgba(74,163,255,.16), transparent 60%),
      linear-gradient(180deg, var(--bg0), var(--bg1));
    border-bottom:1px solid var(--line);
    padding-top:2px !important;
    padding-bottom:2px !important;
    transform:translate3d(0, calc(-100% - 8px), 0);
    pointer-events:none;
    transition:transform .4s ease;
    will-change:transform;
    backface-visibility:hidden;
  }
  section.loginStrip.is-open{
    transform:translate3d(0, var(--login-open-offset, 0px), 0);
    pointer-events:auto;
  }
  .loginInner{
    max-width:1200px;
    margin:0 auto;
    padding:2px 16px;
    display:flex;
    align-items:center;
    justify-content:flex-end;
    gap:10px;
    flex-wrap:wrap;
  }
  #loginForm{
    display:flex;
    align-items:center;
    gap:6px;
    flex-wrap:nowrap;
    margin:0;
  }
  #loginForm .field{
    margin:0;
    width:228px;
  }
  .field{
    display:flex;
    flex-direction:column;
    gap:6px;
  }
  .field label{
    font-size:.78rem;
    color:var(--muted);
    font-weight:700;
    display:none; /* keep clean; placeholders handle */
  }
  .input{
    background: rgba(255,255,255,.06);
    border:1px solid var(--line);
    color:var(--text);
    border-radius:10px;
    padding:8px 10px;
    min-width: 220px;
    outline:none;
  }
  #loginForm .input{
    width:100% !important;
    min-width:0 !important;
    padding:5px 6px;
    border-radius:6px;
    font-size:0.75rem;
  }
  #loginButton{
    border-color: rgba(53,208,200,.35) !important;
    background: linear-gradient(135deg, rgba(53,208,200,.95), rgba(74,163,255,.75)) !important;
    color:#021018 !important;
    padding:5px 7px !important;
    border-radius:6px !important;
    font-size:0.75rem !important;
  }
  #loginAlert{
    flex:0 0 auto;
    margin:0 8px 0 0;
    text-align:left;
    white-space:nowrap;
  }
  #loginAlert.alert{
    margin-bottom:0;
    padding:4px 8px;
    font-size:0.75rem;
    line-height:1.2;
  }
  #loginAlert.d-none{
    display:none !important;
  }
  .input::placeholder{ color: rgba(255,255,255,.45); }
  .forgot{
    color:var(--muted);
    text-decoration:none;
    font-weight:700;
    padding:6px 8px;
    border-radius:10px;
  }
  .forgot:hover{ color:var(--text); background:rgba(255,255,255,.05); }

  /* ===== App nav ===== */
  .brandCompact{
    min-width:auto;
  }
  .brandCompact .tagline{ display:none; }
  .brandCompact .brandTitle{ letter-spacing:.35px; }
  .tabs{
    display:flex;
    align-items:center;
    gap:8px;
    flex-wrap:wrap;
  }
  .tab{
    color:var(--muted);
    text-decoration:none;
    font-weight:900;
    padding:8px 10px;
    border-radius:12px;
    border:1px solid transparent;
  }
  .tab:hover{ color:var(--text); background:rgba(255,255,255,.05); }
  .tab.active{
    color:var(--text);
    background: rgba(53,208,200,.12);
    border-color: rgba(53,208,200,.22);
  }

  /* ===== Icon button + badge ===== */
  .iconBtn{
    position:relative;
    width:38px; height:38px;
    border-radius:12px;
    border:1px solid var(--line);
    background: rgba(255,255,255,.04);
    color:var(--text);
    display:inline-flex;
    align-items:center;
    justify-content:center;
    cursor:pointer;
  }
  .iconBtn:hover{ background: rgba(255,255,255,.07); }
  .fpwHamburger{
    display:none;
    font-size:1.05rem;
    font-weight:900;
    line-height:1;
  }
  .fpwHamburgerIcon--close{
    display:none;
  }
  .fpwHamburger[aria-expanded="true"] .fpwHamburgerIcon--open{
    display:none;
  }
  .fpwHamburger[aria-expanded="true"] .fpwHamburgerIcon--close{
    display:inline;
  }
  .badge{
    position:absolute;
    top:-6px; right:-6px;
    min-width:18px; height:18px;
    border-radius:999px;
    background: rgba(53,208,200,.95);
    color:#021018;
    font-size:.75rem;
    font-weight:900;
    display:flex;
    align-items:center;
    justify-content:center;
    padding:0 5px;
    box-shadow: 0 10px 18px rgba(0,0,0,.25);
  }

  /* ===== Dropdown (pure HTML/CSS via <details>) ===== */
  details.dd{
    position:relative;
  }
  details.dd > summary{
    list-style:none;
  }
  details.dd > summary::-webkit-details-marker{ display:none; }

  .menu{
    position:absolute;
    right:0;
    top: calc(100% + 10px);
    min-width: 240px;
    background: var(--panel);
    border:1px solid rgba(255,255,255,.08);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding:8px;
    z-index:1000;
  }
  .menu a, .menu button{
    width:100%;
    display:flex;
    align-items:center;
    gap:10px;
    padding:10px 10px;
    border-radius:12px;
    border:0;
    background: transparent;
    color: rgba(255,255,255,.86);
    text-decoration:none;
    font-weight:800;
    cursor:pointer;
    text-align:left;
    font-family:var(--font);
    font-size:.95rem;
  }
  .menu a:hover, .menu button:hover{
    background: rgba(255,255,255,.06);
    color: rgba(255,255,255,.95);
  }
  .menu hr{
    border:0;
    border-top:1px solid rgba(255,255,255,.08);
    margin:8px 0;
  }
  .fpwMobileBackdrop{
    display:none;
    position:fixed;
    inset:0;
    background:rgba(0,0,0,.45);
    z-index:1048;
  }
  .fpwMobileMenu{
    display:none;
    position:fixed;
    left:12px;
    right:12px;
    top:72px;
    max-height:calc(100vh - 84px);
    overflow:auto;
    background: var(--panel);
    border:1px solid rgba(255,255,255,.08);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding:8px;
    z-index:1049;
  }
  .fpwMobileMenu a,
  .fpwMobileMenu button{
    width:100%;
    display:flex;
    align-items:center;
    gap:10px;
    padding:10px 10px;
    border-radius:12px;
    border:0;
    background: transparent;
    color: rgba(255,255,255,.86);
    text-decoration:none;
    font-weight:800;
    cursor:pointer;
    text-align:left;
    font-family:var(--font);
    font-size:.95rem;
  }
  .fpwMobileMenu a:hover,
  .fpwMobileMenu button:hover{
    background: rgba(255,255,255,.06);
    color: rgba(255,255,255,.95);
  }
  .fpwMobileMenu hr{
    border:0;
    border-top:1px solid rgba(255,255,255,.08);
    margin:8px 0;
  }
  .fpwMobileSection{
    padding:6px 10px;
    color:var(--muted);
    font-size:.74rem;
    font-weight:900;
    letter-spacing:.08em;
    text-transform:uppercase;
  }
  body.fpwMobileNavOpen{
    overflow:hidden;
  }
  .hint{
    max-width:1200px;
    margin: 18px auto 0;
    padding: 0 16px;
    color: var(--muted);
    font-weight:700;
    font-size:.95rem;
  }
  .hint code{
    background: rgba(255,255,255,.06);
    border:1px solid rgba(255,255,255,.08);
    padding:2px 8px;
    border-radius:10px;
    color: rgba(255,255,255,.86);
  }

  /* ===== Member workspace nav ===== */
  .fpw-member-nav,
  .fpw-member-nav *{
    box-sizing:border-box;
  }
  .fpw-member-nav{
    position:sticky;
    top:0;
    z-index:1051;
    color:#f4f8fb;
    background:
      radial-gradient(circle at 8% 42%, rgba(16,224,216,.12), transparent 24rem),
      radial-gradient(circle at 86% 38%, rgba(0,180,255,.08), transparent 28rem),
      linear-gradient(180deg, #06111c 0%, #02070d 100%);
    border-bottom:1px solid rgba(108,210,234,.16);
    box-shadow:0 20px 70px rgba(0,0,0,.35);
    isolation:isolate;
  }
  .fpw-member-nav::before{
    content:"";
    position:absolute;
    inset:0;
    z-index:-1;
    background-image:
      linear-gradient(rgba(95,184,214,.035) 1px, transparent 1px),
      linear-gradient(90deg, rgba(95,184,214,.025) 1px, transparent 1px);
    background-size:72px 72px;
    mask-image:linear-gradient(180deg, transparent 0%, black 24%, black 78%, transparent 100%);
  }
  .fpw-member-nav a{
    color:inherit;
    text-decoration:none;
  }
  .fpw-member-nav button{
    font:inherit;
  }
  .fpw-member-nav__inner{
    width:min(calc(100% - 48px), 1320px);
    min-height:92px;
    margin:0 auto;
    padding:18px 0;
    display:grid;
    grid-template-columns:minmax(210px, .8fr) minmax(420px, auto) minmax(230px, .8fr);
    align-items:center;
    gap:clamp(1rem, 2vw, 2rem);
  }
  .fpw-member-brand{
    display:inline-flex;
    align-items:center;
    gap:.9rem;
    min-width:0;
  }
  .fpw-member-brand__mark{
    width:42px;
    height:42px;
    flex:0 0 42px;
    display:grid;
    place-items:center;
    color:#1ff0e7;
    filter:drop-shadow(0 0 12px rgba(31,240,231,.55));
  }
  .fpw-member-brand__mark svg{
    width:100%;
    height:100%;
    overflow:visible;
  }
  .fpw-member-brand__mark circle,
  .fpw-member-brand__mark path{
    fill:none;
    stroke:currentColor;
    stroke-width:4;
    stroke-linecap:round;
    stroke-linejoin:round;
  }
  .fpw-member-brand__mark circle:nth-last-child(-n + 4){
    fill:currentColor;
    stroke:none;
  }
  .fpw-member-brand__text{
    display:grid;
    gap:.2rem;
    min-width:0;
  }
  .fpw-member-brand__name{
    color:#f7fbff;
    font-size:1.45rem;
    font-weight:900;
    letter-spacing:-.04em;
    line-height:.95;
    white-space:nowrap;
  }
  .fpw-member-brand__label{
    color:#29f4e7;
    font-size:.66rem;
    font-weight:850;
    letter-spacing:.17em;
    line-height:1.2;
    text-transform:uppercase;
    white-space:nowrap;
  }
  .fpw-member-tabs{
    display:flex;
    align-items:center;
    justify-content:center;
    gap:.55rem;
    padding:.42rem;
    border:1px solid rgba(142,203,219,.14);
    border-radius:999px;
    background:rgba(2,10,18,.42);
    box-shadow:inset 0 0 0 1px rgba(255,255,255,.025);
  }
  .fpw-member-tab{
    min-height:42px;
    display:inline-flex;
    align-items:center;
    justify-content:center;
    padding:0 1rem;
    color:rgba(247,251,255,.78);
    border:1px solid transparent;
    border-radius:999px;
    font-size:.94rem;
    font-weight:800;
    letter-spacing:-.015em;
    line-height:1;
    white-space:nowrap;
    transition:color 160ms ease, border-color 160ms ease, background 160ms ease, box-shadow 160ms ease;
  }
  .fpw-member-tab:hover,
  .fpw-member-tab:focus-visible{
    color:#29f4e7;
    background:rgba(35,215,207,.08);
  }
  .fpw-member-tab.is-active{
    color:#021018;
    background:linear-gradient(135deg, #29f4e7, #4aa3ff);
    border-color:rgba(41,244,231,.9);
    box-shadow:
      0 0 0 1px rgba(255,255,255,.14) inset,
      0 0 24px rgba(33,243,238,.3);
  }
  .fpw-member-actions{
    display:flex;
    align-items:center;
    justify-content:flex-end;
    gap:.75rem;
    min-width:0;
  }
  .fpw-member-account{
    position:relative;
  }
  .fpw-member-account__button,
  .fpw-member-mobile-toggle{
    min-height:48px;
    border:1px solid rgba(33,243,238,.55);
    border-radius:999px;
    color:#34fff1;
    background:rgba(2,10,18,.42);
    box-shadow:
      0 0 0 1px rgba(33,243,238,.08) inset,
      0 0 18px rgba(33,243,238,.12);
    cursor:pointer;
  }
  .fpw-member-account__button{
    max-width:260px;
    display:inline-flex;
    align-items:center;
    gap:.62rem;
    padding:0 .95rem 0 .45rem;
    font-size:.9rem;
    font-weight:850;
  }
  .fpw-member-account__button:hover,
  .fpw-member-account__button:focus-visible,
  .fpw-member-account__button[aria-expanded="true"],
  .fpw-member-mobile-toggle:hover,
  .fpw-member-mobile-toggle:focus-visible,
  .fpw-member-mobile-toggle[aria-expanded="true"]{
    color:#ffffff;
    border-color:#7ffcf6;
    background:rgba(35,215,207,.1);
    box-shadow:
      0 0 0 1px rgba(127,252,246,.16) inset,
      0 0 26px rgba(33,243,238,.3);
  }
  .fpw-member-account__avatar{
    width:36px;
    height:36px;
    flex:0 0 36px;
    display:grid;
    place-items:center;
    color:#021018;
    background:linear-gradient(135deg, #29f4e7, #4aa3ff);
    border-radius:999px;
    font-size:.76rem;
    font-weight:950;
    letter-spacing:.03em;
  }
  .fpw-member-account__name{
    overflow:hidden;
    text-overflow:ellipsis;
    white-space:nowrap;
  }
  .fpw-member-account__chevron{
    color:rgba(247,251,255,.8);
    transform:translateY(-1px);
  }
  .fpw-member-account__button[aria-expanded="true"] .fpw-member-account__chevron{
    transform:translateY(-1px) rotate(180deg);
  }
  .fpw-member-account__menu{
    position:absolute;
    top:calc(100% + 14px);
    right:0;
    z-index:1060;
    width:min(280px, calc(100vw - 32px));
    padding:10px;
    color:#f4f8fb;
    background:
      radial-gradient(circle at 20% 0%, rgba(35,215,207,.18), transparent 9rem),
      linear-gradient(180deg, rgba(7,24,42,.98), rgba(2,10,18,.98));
    border:1px solid rgba(41,244,231,.32);
    border-radius:18px;
    box-shadow:
      0 0 0 1px rgba(255,255,255,.04) inset,
      0 18px 52px rgba(0,0,0,.48),
      0 0 28px rgba(33,243,238,.18);
    opacity:0;
    visibility:hidden;
    pointer-events:none;
    transform:translateY(-6px);
    transition:opacity 160ms ease, transform 160ms ease, visibility 160ms ease;
  }
  .fpw-member-account__menu.is-open{
    opacity:1;
    visibility:visible;
    pointer-events:auto;
    transform:translateY(0);
  }
  .fpw-member-account__menu-header{
    padding:10px 12px 12px;
    border-bottom:1px solid rgba(142,203,219,.14);
    margin-bottom:6px;
  }
  .fpw-member-account__menu-header strong,
  .fpw-member-account__menu-header span{
    display:block;
    overflow:hidden;
    text-overflow:ellipsis;
    white-space:nowrap;
  }
  .fpw-member-account__menu-header strong{
    color:#ffffff;
    font-size:.95rem;
    font-weight:900;
  }
  .fpw-member-account__menu-header span{
    margin-top:3px;
    color:rgba(184,203,214,.82);
    font-size:.78rem;
    font-weight:700;
  }
  .fpw-member-account__menu a,
  .fpw-member-account__menu button,
  .fpw-member-mobile-panel a,
  .fpw-member-mobile-panel button{
    width:100%;
    display:flex;
    align-items:center;
    gap:.55rem;
    padding:11px 12px;
    border:0;
    border-radius:12px;
    color:rgba(244,248,251,.92);
    background:transparent;
    font:inherit;
    font-size:.9rem;
    font-weight:800;
    text-align:left;
    text-decoration:none;
    cursor:pointer;
  }
  .fpw-member-account__menu a:hover,
  .fpw-member-account__menu a:focus-visible,
  .fpw-member-account__menu button:hover,
  .fpw-member-account__menu button:focus-visible,
  .fpw-member-mobile-panel a:hover,
  .fpw-member-mobile-panel a:focus-visible,
  .fpw-member-mobile-panel button:hover,
  .fpw-member-mobile-panel button:focus-visible{
    color:#ffffff;
    background:rgba(35,215,207,.1);
    box-shadow:0 0 18px rgba(33,243,238,.12) inset;
  }
  .fpw-member-account__menu-divider{
    height:1px;
    margin:7px 0;
    background:rgba(142,203,219,.14);
  }
  .fpw-member-mobile-toggle{
    width:48px;
    display:none;
    place-items:center;
    padding:0;
  }
  .fpw-member-mobile-toggle svg{
    width:22px;
    height:22px;
    fill:none;
    stroke:currentColor;
    stroke-width:2.2;
    stroke-linecap:round;
  }
  .fpw-member-mobile-panel{
    display:none;
    position:fixed;
    left:12px;
    right:12px;
    top:104px;
    z-index:1059;
    max-height:calc(100vh - 116px);
    overflow:auto;
    padding:10px;
    color:#f4f8fb;
    background:
      radial-gradient(circle at 20% 0%, rgba(35,215,207,.18), transparent 9rem),
      linear-gradient(180deg, rgba(7,24,42,.98), rgba(2,10,18,.98));
    border:1px solid rgba(41,244,231,.32);
    border-radius:18px;
    box-shadow:
      0 18px 52px rgba(0,0,0,.48),
      0 0 28px rgba(33,243,238,.18);
  }
  .fpw-member-mobile-panel.is-open{
    display:block;
  }
  .fpw-member-mobile-panel__section{
    padding:7px 12px;
    color:rgba(184,203,214,.82);
    font-size:.72rem;
    font-weight:900;
    letter-spacing:.12em;
    text-transform:uppercase;
  }
  .fpw-member-mobile-panel a.is-active{
    color:#021018;
    background:linear-gradient(135deg, #29f4e7, #4aa3ff);
  }

  /* Responsive: hide center links on public; you’d add hamburger later */
  @media (max-width: 980px){
    .tagline{ display:none; }
    .navLinks{ display:none; }
    .tabs{ display:none; }
    .brand{ min-width:auto; }
    .actions > :not(.fpwHamburger){ display:none !important; }
    .fpwHamburger{ display:inline-flex; }
    .fpwMobileBackdrop.is-open{ display:block; }
    .fpwMobileMenu.is-open{ display:block; }
    .input{ min-width: 180px; }
    #loginForm{
      flex-wrap:wrap;
      justify-content:flex-end;
    }
    #loginAlert{
      flex:0 0 100%;
      margin:4px 0 0;
      text-align:right;
    }
    #loginForm .field{ width:136px; }
    .fpw-member-nav__inner{
      width:min(calc(100% - 32px), 1320px);
      min-height:82px;
      grid-template-columns:1fr auto;
      gap:1rem;
    }
    .fpw-member-tabs{
      display:none;
    }
    .fpw-member-account__button{
      display:none;
    }
    .fpw-member-mobile-toggle{
      display:grid;
    }
    .fpw-member-brand__name{
      font-size:1.25rem;
    }
    .fpw-member-brand__label{
      font-size:.58rem;
      letter-spacing:.14em;
    }
  }

  @media (max-width: 560px){
    .fpw-member-nav__inner{
      width:min(calc(100% - 24px), 1320px);
    }
    .fpw-member-brand{
      gap:.65rem;
    }
    .fpw-member-brand__mark{
      width:36px;
      height:36px;
      flex-basis:36px;
    }
    .fpw-member-brand__label{
      display:none;
    }
  }
</style>

<cfif len(userDisplayName)>
  <cfparam name="request.fpwTopNavActive" default="dashboard">

  <header class="fpw-member-nav nav--app" role="banner" data-fpw-member-nav>
    <div class="fpw-member-nav__inner">
      <a class="fpw-member-brand" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm" aria-label="FloatPlanWizard Dashboard">
        <span class="fpw-member-brand__mark" aria-hidden="true">
          <svg viewBox="0 0 64 64" focusable="false">
            <circle cx="32" cy="32" r="17"></circle>
            <circle cx="32" cy="32" r="6"></circle>
            <path d="M32 4v12"></path>
            <path d="M32 48v12"></path>
            <path d="M4 32h12"></path>
            <path d="M48 32h12"></path>
            <path d="M12.2 12.2l8.5 8.5"></path>
            <path d="M43.3 43.3l8.5 8.5"></path>
            <path d="M51.8 12.2l-8.5 8.5"></path>
            <path d="M20.7 43.3l-8.5 8.5"></path>
            <circle cx="32" cy="4" r="2.5"></circle>
            <circle cx="32" cy="60" r="2.5"></circle>
            <circle cx="4" cy="32" r="2.5"></circle>
            <circle cx="60" cy="32" r="2.5"></circle>
          </svg>
        </span>
        <span class="fpw-member-brand__text">
          <span class="fpw-member-brand__name">FPW</span>
          <span class="fpw-member-brand__label">Member Workspace</span>
        </span>
      </a>

      <nav class="fpw-member-tabs" aria-label="Member navigation">
        <a class="fpw-member-tab<cfif request.fpwTopNavActive EQ 'dashboard'> is-active</cfif>" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm"<cfif request.fpwTopNavActive EQ 'dashboard'> aria-current="page"</cfif>>Dashboard</a>
        <a class="fpw-member-tab<cfif request.fpwTopNavActive EQ 'weather'> is-active</cfif>" id="fpwNavWeatherLink" href="<cfoutput>#basePath#</cfoutput>/app/weather.cfm"<cfif request.fpwTopNavActive EQ 'weather'> aria-current="page"</cfif>>Weather</a>
        <a class="fpw-member-tab<cfif request.fpwTopNavActive EQ 'monitoring'> is-active</cfif>" href="<cfoutput>#basePath#</cfoutput>/app/monitoring.cfm"<cfif request.fpwTopNavActive EQ 'monitoring'> aria-current="page"</cfif>>Monitor</a>
        <a class="fpw-member-tab<cfif request.fpwTopNavActive EQ 'fuel'> is-active</cfif>" href="<cfoutput>#basePath#</cfoutput>/app/fuel-calculator.cfm"<cfif request.fpwTopNavActive EQ 'fuel'> aria-current="page"</cfif>>Fuel Calculator</a>
      </nav>

      <div class="fpw-member-actions">
        <div class="fpw-member-account">
          <button
            class="fpw-member-account__button"
            type="button"
            aria-expanded="false"
            aria-controls="fpwMemberAccountMenu"
            data-fpw-member-account-toggle>
            <span class="fpw-member-account__avatar" aria-hidden="true"><cfoutput>#encodeForHTML(memberDisplayInitials)#</cfoutput></span>
            <span class="fpw-member-account__name"><cfoutput>#encodeForHTML(userDisplayName)#</cfoutput></span>
            <span class="fpw-member-account__chevron" aria-hidden="true">&#8964;</span>
          </button>

          <div class="fpw-member-account__menu" id="fpwMemberAccountMenu" role="menu" aria-label="Member account menu" data-fpw-member-account-menu>
            <div class="fpw-member-account__menu-header">
              <strong><cfoutput>#encodeForHTML(userDisplayName)#</cfoutput></strong>
              <span>Member account</span>
            </div>
            <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm" role="menuitem">Member Account</a>
            <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm" role="menuitem">Account Settings</a>
            <div class="fpw-member-account__menu-divider" aria-hidden="true"></div>
            <button type="button" role="menuitem" data-fpw-member-logout>Logout</button>
          </div>
        </div>

        <button
          class="fpw-member-mobile-toggle"
          type="button"
          aria-label="Open member menu"
          aria-expanded="false"
          aria-controls="fpwMemberMobilePanel"
          data-fpw-member-mobile-toggle>
          <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <path d="M4 7h16"></path>
            <path d="M4 12h16"></path>
            <path d="M4 17h16"></path>
          </svg>
        </button>
      </div>
    </div>

    <div class="fpw-member-mobile-panel" id="fpwMemberMobilePanel" data-fpw-member-mobile-panel aria-hidden="true">
      <nav aria-label="Mobile member navigation">
        <div class="fpw-member-mobile-panel__section">Workspace</div>
        <a class="<cfif request.fpwTopNavActive EQ 'dashboard'>is-active</cfif>" href="<cfoutput>#basePath#</cfoutput>/app/dashboard.cfm"<cfif request.fpwTopNavActive EQ 'dashboard'> aria-current="page"</cfif>>Dashboard</a>
        <a class="<cfif request.fpwTopNavActive EQ 'weather'>is-active</cfif>" id="fpwMobileWeatherLink" href="<cfoutput>#basePath#</cfoutput>/app/weather.cfm"<cfif request.fpwTopNavActive EQ 'weather'> aria-current="page"</cfif>>Weather</a>
        <a class="<cfif request.fpwTopNavActive EQ 'monitoring'>is-active</cfif>" href="<cfoutput>#basePath#</cfoutput>/app/monitoring.cfm"<cfif request.fpwTopNavActive EQ 'monitoring'> aria-current="page"</cfif>>Monitor</a>
        <a class="<cfif request.fpwTopNavActive EQ 'fuel'>is-active</cfif>" href="<cfoutput>#basePath#</cfoutput>/app/fuel-calculator.cfm"<cfif request.fpwTopNavActive EQ 'fuel'> aria-current="page"</cfif>>Fuel Calculator</a>
        <div class="fpw-member-mobile-panel__section">Account</div>
        <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm">Member Account</a>
        <a href="<cfoutput>#basePath#</cfoutput>/app/account.cfm">Account Settings</a>
        <button type="button" data-fpw-member-logout>Logout</button>
      </nav>
    </div>
  </header>

  <script>
    (function () {
      function initMemberNav() {
        var nav = document.querySelector("[data-fpw-member-nav]");
        if (!nav) return;

        var accountToggle = nav.querySelector("[data-fpw-member-account-toggle]");
        var accountMenu = nav.querySelector("[data-fpw-member-account-menu]");
        var mobileToggle = nav.querySelector("[data-fpw-member-mobile-toggle]");
        var mobilePanel = nav.querySelector("[data-fpw-member-mobile-panel]");
        var logoutButtons = nav.querySelectorAll("[data-fpw-member-logout]");

        function setAccountOpen(isOpen) {
          if (!accountToggle || !accountMenu) return;
          accountToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
          accountMenu.classList.toggle("is-open", isOpen);
        }

        function syncMobilePanelTop() {
          if (!mobilePanel) return;
          var rect = nav.getBoundingClientRect();
          var top = Math.max(0, Math.round(rect.bottom) + 8);
          mobilePanel.style.top = top + "px";
          mobilePanel.style.maxHeight = "calc(100vh - " + (top + 12) + "px)";
        }

        function setMobileOpen(isOpen) {
          if (!mobileToggle || !mobilePanel) return;
          syncMobilePanelTop();
          mobileToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
          mobilePanel.setAttribute("aria-hidden", isOpen ? "false" : "true");
          mobilePanel.classList.toggle("is-open", isOpen);
          document.body.classList.toggle("fpwMobileNavOpen", isOpen);
        }

        function closeMenus() {
          setAccountOpen(false);
          setMobileOpen(false);
        }

        function redirectAfterLogout() {
          if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
            window.AppAuth.redirectToLogin();
          } else {
            window.location.href = "<cfoutput>#JSStringFormat(basePath)#</cfoutput>/index.cfm";
          }
        }

        function runLogout(event) {
          event.preventDefault();
          closeMenus();
          if (!window.Api || typeof window.Api.logout !== "function") {
            console.error("Logout failed: Api.logout is not available.");
            return;
          }

          window.Api.logout()
            .catch(function (err) {
              console.error("Logout failed:", err);
            })
            .finally(redirectAfterLogout);
        }

        if (accountToggle) {
          accountToggle.addEventListener("click", function (event) {
            event.preventDefault();
            setMobileOpen(false);
            setAccountOpen(accountToggle.getAttribute("aria-expanded") !== "true");
          });
        }

        if (mobileToggle) {
          mobileToggle.addEventListener("click", function (event) {
            event.preventDefault();
            setAccountOpen(false);
            setMobileOpen(mobileToggle.getAttribute("aria-expanded") !== "true");
          });
        }

        if (mobilePanel) {
          mobilePanel.addEventListener("click", function (event) {
            if (event.target.closest("a,button")) {
              setMobileOpen(false);
            }
          });
        }

        Array.prototype.forEach.call(logoutButtons, function (logoutButton) {
          logoutButton.addEventListener("click", runLogout);
        });

        document.addEventListener("click", function (event) {
          if (!nav.contains(event.target)) {
            closeMenus();
          }
        });

        document.addEventListener("keydown", function (event) {
          if (event.key === "Escape") {
            closeMenus();
          }
        });

        window.addEventListener("resize", function () {
          syncMobilePanelTop();
          if (window.innerWidth > 980) {
            setMobileOpen(false);
          }
        });

        syncMobilePanelTop();
      }

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initMemberNav);
      } else {
        initMemberNav();
      }
    })();
  </script>
<cfelse>
  <header class="topbar nav--public" role="banner">
    <div class="inner">
      <a class="brand" href="<cfoutput>#basePath#</cfoutput>/index.cfm" aria-label="FloatPlanWizard Home">
        <span class="logo" aria-hidden="true"></span>
        <span>
          <div class="brandTitle">FloatPlanWizard</div>
        </span>
      </a>

      <nav class="navLinks" aria-label="Primary">
        <a href="#features">Features</a>
        <a href="#how">How it works</a>
        <a href="#monitoring">Monitoring</a>
        <a href="#pricing">Pricing</a>
        <a href="#faq">FAQ</a>
        <a href="<cfoutput>#basePath#</cfoutput>/app/fuel-calculator.cfm">Fuel Calculator</a>
      </nav>

      <div class="actions">
        <a class="btn" href="#login" id="publicLoginToggle">Log in</a>
        <a class="btn btnPrimary" href="<cfoutput>#basePath#</cfoutput>/app/join.cfm">Start free</a>
        <button class="iconBtn fpwHamburger" type="button" id="fpwPublicMobileToggle" aria-controls="fpwMobileMenuPublic" aria-expanded="false" aria-label="Toggle menu">
          <span class="fpwHamburgerIcon fpwHamburgerIcon--open" aria-hidden="true">☰</span>
          <span class="fpwHamburgerIcon fpwHamburgerIcon--close" aria-hidden="true">✕</span>
        </button>
      </div>
    </div>
  </header>

  <div class="fpwMobileBackdrop fpwMobileBackdrop--public" id="fpwMobileBackdropPublic" aria-hidden="true"></div>
  <nav class="fpwMobileMenu fpwMobileMenu--public" id="fpwMobileMenuPublic" role="navigation" aria-label="Mobile public menu" aria-hidden="true">
    <a href="#features">Features</a>
    <a href="#how">How it works</a>
    <a href="#monitoring">Monitoring</a>
    <a href="#pricing">Pricing</a>
    <a href="#faq">FAQ</a>
    <a href="<cfoutput>#basePath#</cfoutput>/app/fuel-calculator.cfm">Fuel Calculator</a>
    <hr />
    <a href="#login" id="fpwMobilePublicLoginLink">Log in</a>
    <a href="<cfoutput>#basePath#</cfoutput>/app/join.cfm">Start free</a>
  </nav>

  <section class="loginStrip" id="login" aria-label="Login">
    <div class="loginInner">
      <form id="loginForm" novalidate>
        <div id="loginAlert" class="alert d-none fpwLoginAlert" role="alert"></div>
        <div class="field">
          <label for="email">Email</label>
          <input
            class="input fpwInput"
            type="email"
            id="email"
            name="email"
            required
            autocomplete="username"
            placeholder="Email"
          >
        </div>
        <div class="field">
          <label for="password">Password</label>
          <input
            class="input fpwInput"
            type="password"
            id="password"
            name="password"
            required
            autocomplete="current-password"
            placeholder="Password"
          >
        </div>
        <button type="submit" class="btn btnPrimary fpwBtn primary" id="loginButton">Sign In</button>
      </form>
      <a class="forgot" href="<cfoutput>#basePath#</cfoutput>/app/forgot-password.cfm">Forgot?</a>
    </div>
  </section>

  <script>
    (function () {
      function initPublicLoginToggle() {
        var toggle = document.getElementById("publicLoginToggle");
        var loginStrip = document.getElementById("login");
        var publicHeader = document.querySelector(".topbar.nav--public");
        var publicMobileToggle = document.getElementById("fpwPublicMobileToggle");
        var publicMobileMenu = document.getElementById("fpwMobileMenuPublic");
        var publicMobileBackdrop = document.getElementById("fpwMobileBackdropPublic");
        var publicMobileLoginLink = document.getElementById("fpwMobilePublicLoginLink");
        if (!toggle || !loginStrip || !publicHeader) return;

        function syncLoginStripTop() {
          var rect = publicHeader.getBoundingClientRect();
          loginStrip.style.setProperty(
            "--login-open-offset",
            Math.max(0, Math.round(rect.bottom)) + "px"
          );
        }

        function openLoginStrip() {
          syncLoginStripTop();
          loginStrip.classList.add("is-open");
          var emailInput = document.getElementById("email");
          if (emailInput && typeof emailInput.focus === "function") {
            emailInput.focus();
          }
        }

        function closeLoginStrip() {
          loginStrip.classList.remove("is-open");
        }

        function syncPublicMobileMenuTop() {
          if (!publicMobileMenu) return;
          var rect = publicHeader.getBoundingClientRect();
          var top = Math.max(0, Math.round(rect.bottom) + 8);
          publicMobileMenu.style.top = top + "px";
          publicMobileMenu.style.maxHeight = "calc(100vh - " + (top + 12) + "px)";
        }

        function setPublicMobileOpen(isOpen) {
          if (!publicMobileMenu || !publicMobileBackdrop || !publicMobileToggle) return;
          syncPublicMobileMenuTop();
          if (isOpen) {
            publicMobileMenu.classList.add("is-open");
            publicMobileBackdrop.classList.add("is-open");
            publicMobileMenu.setAttribute("aria-hidden", "false");
            publicMobileToggle.setAttribute("aria-expanded", "true");
            document.body.classList.add("fpwMobileNavOpen");
          } else {
            publicMobileMenu.classList.remove("is-open");
            publicMobileBackdrop.classList.remove("is-open");
            publicMobileMenu.setAttribute("aria-hidden", "true");
            publicMobileToggle.setAttribute("aria-expanded", "false");
            document.body.classList.remove("fpwMobileNavOpen");
          }
        }

        toggle.addEventListener("click", function (event) {
          event.preventDefault();
          if (loginStrip.classList.contains("is-open")) {
            closeLoginStrip();
          } else {
            openLoginStrip();
          }
        });

        if (publicMobileToggle) {
          publicMobileToggle.addEventListener("click", function (event) {
            event.preventDefault();
            setPublicMobileOpen(!publicMobileMenu || !publicMobileMenu.classList.contains("is-open"));
          });
        }
        if (publicMobileBackdrop) {
          publicMobileBackdrop.addEventListener("click", function () {
            setPublicMobileOpen(false);
          });
        }
        if (publicMobileMenu) {
          publicMobileMenu.addEventListener("click", function (event) {
            if (event.target.closest("a,button")) {
              setPublicMobileOpen(false);
            }
          });
        }
        if (publicMobileLoginLink) {
          publicMobileLoginLink.addEventListener("click", function (event) {
            event.preventDefault();
            setPublicMobileOpen(false);
            toggle.click();
          });
        }

        document.addEventListener("keydown", function (event) {
          if (event.key === "Escape") {
            setPublicMobileOpen(false);
          }
        });

        window.addEventListener("resize", function () {
          syncLoginStripTop();
          syncPublicMobileMenuTop();
          if (window.innerWidth > 980) {
            setPublicMobileOpen(false);
          }
        });
        syncLoginStripTop();
        syncPublicMobileMenuTop();
      }

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initPublicLoginToggle);
      } else {
        initPublicLoginToggle();
      }
    })();
  </script>
</cfif>
