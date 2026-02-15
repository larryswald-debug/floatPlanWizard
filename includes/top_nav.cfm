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

<header class="topbar">
    <div class="wrap">
      <div class="inner">
        <div class="brand">
          <div class="logo" aria-hidden="true"></div>
          <div>
            <div class="fpwBrandTitleRow">
              <div class="fpwBrandTitle">FloatPlanWizard</div>
             
            </div>
            <div class="tiny">Float plans, check-ins, and overdue alerts — made simple.</div>
          </div>
        </div>

        <nav aria-label="Primary">
          <a href="#features">Features</a>
          <a href="#how">How it works</a>
          <a href="#monitoring">Monitoring</a>
          <a href="#faq">FAQ</a>
         
        </nav>
      </div>
    </div>
  </header>

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
