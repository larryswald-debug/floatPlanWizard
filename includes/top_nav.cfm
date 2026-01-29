<!-- /includes/topnav-login.cfm -->
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
</cfscript>

<style>
  :root{
    --fpw-nav-bg: rgba(7,11,20,.78);
    --fpw-nav-line: rgba(255,255,255,.10);
    --fpw-nav-text: rgba(255,255,255,.92);
    --fpw-nav-muted: rgba(255,255,255,.72);
    --fpw-nav-subtle: rgba(255,255,255,.55);
    --fpw-nav-accent: #2dd4bf;
    --fpw-nav-accent2:#60a5fa;
    --fpw-radius: 999px;
    --fpw-shadow: 0 14px 40px rgba(0,0,0,.35);
    --fpw-max: 1120px;
    --fpw-font: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial;
  }

  /* Namespaced to avoid collisions */
  .fpwTopBar{
    position: sticky;
    top: 0;
    z-index: 90;
    backdrop-filter: blur(14px);
    background: var(--fpw-nav-bg);
    border-bottom: 1px solid var(--fpw-nav-line);
  }

  .fpwTopBarInner{
    max-width: var(--fpw-max);
    margin: 0 auto;
    padding: 10px 20px;
    display: flex;
    align-items: center;
    justify-content: flex-end; /* RIGHT ALIGN */
    font-family: var(--fpw-font);
    color: var(--fpw-nav-text);
  }

  /* Login form */
  .fpwLoginForm{
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .fpwField{
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border-radius: var(--fpw-radius);
    border: 1px solid rgba(255,255,255,.12);
    background: rgba(255,255,255,.05);
  }

  .fpwField label{
    font-size: 12px;
    font-weight: 700;
    color: var(--fpw-nav-subtle);
  }

  .fpwInput{
    width: 150px;
    padding: 8px 10px;
    border-radius: var(--fpw-radius);
    border: 1px solid rgba(255,255,255,.12);
    background: rgba(255,255,255,.06);
    color: var(--fpw-nav-text);
    font-size: 13px;
    outline: none;
  }

  .fpwInput::placeholder{
    color: rgba(255,255,255,.42);
  }

  .fpwInput:focus{
    border-color: rgba(45,212,191,.45);
    box-shadow: 0 0 0 4px rgba(45,212,191,.10);
  }

  .fpwBtn{
    padding: 9px 16px;
    border-radius: var(--fpw-radius);
    border: 1px solid rgba(255,255,255,.14);
    background: rgba(255,255,255,.06);
    color: var(--fpw-nav-text);
    font-weight: 800;
    font-size: 13px;
    cursor: pointer;
    white-space: nowrap;
    transition: transform .15s ease, background .15s ease, border-color .15s ease;
  }

  .fpwBtn.primary{
    border-color: rgba(45,212,191,.45);
    background: linear-gradient(
      135deg,
      rgba(45,212,191,.18),
      rgba(96,165,250,.12)
    );
  }

  .fpwBtn:hover{
    transform: translateY(-1px);
    background: rgba(255,255,255,.09);
    border-color: rgba(255,255,255,.20);
  }

  .fpwNote{
    font-size: 12px;
    color: var(--fpw-nav-muted);
    font-weight: 650;
    padding-left: 4px;
  }

  .fpwNote a{
    color: inherit;
    text-decoration: none;
  }

  .fpwNavRow{
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    gap: 16px;
  }

  .fpwUserNav{
    padding: 0;
  }

  .fpwUserNav .nav-link{
    color: var(--fpw-nav-muted);
    font-weight: 650;
    font-size: 13px;
    padding: 6px 10px;
    border-radius: var(--fpw-radius);
  }

  .fpwUserNav .nav-link:hover{
    color: var(--fpw-nav-text);
    background: rgba(255,255,255,.06);
  }

  .fpwUserBlock{
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 6px;
  }

  .fpwUserMenu .dropdown-toggle{
    color: var(--fpw-nav-muted);
    font-weight: 650;
    font-size: 12px;
    padding: 6px 10px;
    border-radius: var(--fpw-radius);
    border: 1px solid transparent;
    background: transparent;
  }

  .fpwUserMenu .dropdown-toggle:hover,
  .fpwUserMenu .dropdown-toggle:focus{
    color: var(--fpw-nav-text);
    background: rgba(255,255,255,.06);
    border-color: rgba(255,255,255,.10);
    box-shadow: none;
  }

  .fpwUserMenu .dropdown-menu{
    min-width: 180px;
    left: 0;
    right: auto;
    background: rgba(7,11,20,.95);
    border: 1px solid rgba(255,255,255,.12);
    box-shadow: var(--fpw-shadow);
  }

  .fpwUserMenu .dropdown-item{
    color: var(--fpw-nav-text);
    font-size: 13px;
    font-weight: 600;
  }

  .fpwUserMenu .dropdown-item:hover,
  .fpwUserMenu .dropdown-item:focus{
    color: var(--fpw-nav-text);
    background: rgba(255,255,255,.08);
  }

  .fpwBtn.compact{
    padding: 6px 12px;
    font-size: 13px;
    line-height: 1.2;
  }

  .d-none{
    display: none !important;
  }

  .alert{
    padding: 6px 12px;
    border-radius: var(--fpw-radius);
    border: 1px solid rgba(255,255,255,.18);
    font-size: 12px;
    font-weight: 600;
    color: var(--fpw-nav-text);
    background: rgba(255,255,255,.06);
  }

  .alert-success{
    border-color: rgba(52,211,153,.45);
    background: rgba(52,211,153,.12);
  }

  .alert-danger{
    border-color: rgba(251,113,133,.55);
    background: rgba(251,113,133,.12);
  }

  .alert-info{
    border-color: rgba(96,165,250,.55);
    background: rgba(96,165,250,.12);
  }

  .fpwLoginAlert{
    margin-left: 10px;
    max-width: 260px;
  }

  /* Responsive */
  @media (max-width: 760px){
    .fpwInput{
      width: min(220px, 70vw);
    }
    .fpwLoginForm{
      justify-content: flex-end;
    }
  }
</style>

<div class="fpwTopBar">
  <div class="fpwTopBarInner">

    <cfif len(userDisplayName)>
      <div class="fpwNavRow">
        <nav class="navbar navbar-expand fpwUserNav" aria-label="Primary">
          <ul class="navbar-nav me-auto">
            <li class="nav-item">
              <a class="nav-link" href="<cfoutput>#request.fpwBase#</cfoutput>/index.cfm">Home</a>
            </li>
            <li class="nav-item">
              <a class="nav-link" href="<cfoutput>#request.fpwBase#</cfoutput>/app/dashboard.cfm">Dashboard</a>
            </li>
            <li class="nav-item">
              <a class="nav-link" href="#">TBD 1</a>
            </li>
            <li class="nav-item">
              <a class="nav-link" href="#">TBD 2</a>
            </li>
            <li class="nav-item">
              <a class="nav-link" href="#">TBD 3</a>
            </li>
          </ul>
        </nav>
        <div class="dropdown fpwUserMenu">
          <button
            class="dropdown-toggle"
            type="button"
            id="userMenuButton"
            data-bs-toggle="dropdown"
            aria-expanded="false"
          >
            <cfoutput>#encodeForHTML(userDisplayName)#</cfoutput>
          </button>
          <ul class="dropdown-menu" aria-labelledby="userMenuButton">
            <li>
              <a class="dropdown-item" href="<cfoutput>#request.fpwBase#</cfoutput>/app/account.cfm">Account</a>
            </li>
            <li>
              <button class="dropdown-item" id="logoutButton" type="button">Log out</button>
            </li>
          </ul>
        </div>
      </div>
    <cfelse>
      <!-- Login only -->
      <form id="loginForm" novalidate>
        <div class="fpwField">
          <label for="email">User</label>
          <input
            type="email"
            class="fpwInput"
            id="email"
            name="email"
            required
            autocomplete="username"
        >
        </div>

        <div class="fpwField">
          <label for="password">Pass</label>
          <input
              type="password"
              class="fpwInput"
              id="password"
              name="password"
              required
              autocomplete="current-password"
          >
        </div>

        <button type="submit" class="fpwBtn primary" id="loginButton">
          Sign In
        </button>
      </form>
      <div id="loginAlert" class="alert d-none fpwLoginAlert" role="alert"></div>
    </cfif>

  </div>
</div>
