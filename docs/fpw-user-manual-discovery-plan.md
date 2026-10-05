# FPW User Manual — Discovery Report and Manual Plan

## 1. Executive summary

The current member experience centers on:

**Dashboard → saved boating information → route planning → Float Plan Wizard → sending/sharing → Active Cruise → explicit completion.**

“Trip Planner,” “Routes,” and “FPW Route Generator” describe connected parts of this workflow, not three separate planning applications.

The future manual should teach the current Dashboard workflow. Older implementations should appear only where an existing navigation or return path can still expose them.

The principal findings are:

- The Dashboard’s current Float Plan Wizard has **six steps**.
- Its **Basic Save & Send** emails a PDF to one saved contact and preserves the Draft. It does **not** activate monitoring.
- **Premium Save & Send** activates the route-backed trip and its operational features.
- Sending a Float Plan and sharing its **Follow Link** are separate actions.
- Scheduled departure, actual departure, leg completion, and final trip closure are separate events.
- **Delayed**, **Add Delay Time**, **Secure Night**, and **Daily Start Time** have different effects.
- Route progress is an estimate. It is not continuous GPS tracking or automatic arrival.
- The completed-trip page exists, but no current Dashboard history entry was verified. The captain’s safe-arrival email supplies a verified entry.
- You confirmed that **Companion is not currently available to members**. Its implemented capabilities belong in an owner-only discovery appendix, not normal member instructions.

This was read-only source discovery. FPW inspection used MCPCFC. Companion inspection used the read-only shell fallback you explicitly approved.

No files, accounts, trips, settings, databases, or messages were changed. No screenshots were created. Tests were inspected but not executed. MCP Playwright’s available tab was the previous administrator manual; an authenticated member walkthrough was not performed.

At the end of discovery, the FPW working tree was clean and `git diff --check` passed. Companion contained existing uncommitted changes; this report describes its inspected working-tree source, not a verified released build.

This discovery report was saved to `docs/fpw-user-manual-discovery-plan.md` on 2026-10-04 after owner approval. This step adds only the report; the final member manual, screenshot capture, runtime validation, and application changes remain outside this documentation step. The findings and validation limits below describe the completed discovery phase.

## 2. Authenticated application page inventory

Routes below are application URLs, not filesystem paths. Local development adds the `/fpw` prefix.

| ID | Page or major screen | Route / entry | Navigation and purpose | Main actions and displayed data | Manual placement |
|---|---|---|---|---|---|
| D | Dashboard | `/app/dashboard.cfm` | Main member landing page | Setup readiness, home port, default vessel, saved routes, saved boating records, shortcuts | Chapters 1–2 |
| V | Saved Vessels / vessel dialog | Dashboard → Vessels | Maintain reusable boats | Add, edit, delete, select default, manage image and performance/safety information | Chapter 3 |
| O | Operators | Dashboard → Operators | Maintain reusable operators | Add, edit, delete; name, phone, notes | Chapter 4 |
| P | Passengers & Crew | Dashboard → Crew | Maintain reusable people | Add, edit, delete; name, phone, age, gender, notes | Chapter 5 |
| C | Trip Contacts | Dashboard → Contacts | Maintain people ashore | Add, edit, delete; name, phone, email | Chapter 6 |
| W | Waypoints | Dashboard → Waypoints | Maintain reusable locations | Add/edit/delete; map, coordinates, name, notes | Chapter 7 |
| R | FPW Route Generator | Dashboard → **+ Create Route** / **Generate Route** | Build and refine a route | My Routes, waypoint legs, vessel assumptions, map geometry, timeline, fuel/time estimates | Chapters 8–12 |
| F | Float Plan Wizard | Dashboard route actions | Complete a route-backed Float Plan | Six steps, saved-record selections, safety information, review, save, send | Chapters 15–16 |
| A | Active Cruise | `/app/active-cruise.cfm` | Operate the current active trip | Current leg, estimates, check-ins, timing, weather, notes, contacts, leg completion and closure | Chapters 18–21 |
| M | Float Plan Monitor / Monitoring Console | `/app/monitoring.cfm` | Read-only monitoring view | Trip state, health, monitoring status, next check-in, GPS history, alert readiness | Chapter 19 |
| WX | Marine Weather Briefing | `/app/weather.cfm` | Member weather page | Home-port/ZIP/coordinate lookup, marine conditions, alerts, tides, forecasts, maps | Chapter 13 |
| CT | Completed trip record | `/app/completed-trip.cfm` with trip context | Verified entry from captain’s safe-arrival email | Read-only identity, timing, route/completion summary, source limitations | Chapter 23 |
| AC | My Account | `/app/account.cfm` | Account menu; Dashboard Settings | Profile, home port, password, membership, credits, billing, promotional codes | Chapter 24 |
| H | Help | `/app/help.cfm` | Dashboard Help and footer | Search, contents navigation, FAQs | Chapter 25 |
| FL | Linked Fuel Calculator | `/boat-fuel-calculator/boat-fuel-calculator.cfm` | Member navigation | Independent fuel/range scenario, breakdown, reset, copy results | Chapter 14 |
| SF | Follow Page | `/app/follow.cfm` through generated shared link | Dashboard **Follow Page / Share Follow Link** | Trip progress, status, map, PDF when available, voyage updates and follower interaction | Chapter 17 |
| FM | Follow full map | `/app/follow-full-map.cfm` through Follow | Contextual map expansion | Larger view of the shared trip map | Chapter 17 |
| GL | Great Loop reference libraries | `/great-loop/locks/`, `/anchorages/`, `/ports/`, `/bridges/` | Shared Great Loop navigation | Search, filters, maps, record details; Ports can add a saved waypoint | Chapter 10 |
| ALT | Alternate wizard / Basic form | Checkout-return fallback; existing Basic continuation | Currently reachable exception | Different wizard and Basic behavior | Section 25; not a parallel primary workflow |

The seven clearly guarded member pages found through `require_auth.cfm` are Dashboard, Account, Active Cruise, Monitoring, Weather, Completed Trip, and the standalone Float Plan Wizard.

Help, the linked calculator, Great Loop references, and shared Follow pages are included only to the extent that they participate in the member’s workflow. They are not all authentication-only pages.

## 3. Navigation map

```text
Member header
├─ Dashboard
├─ Active Cruise
├─ Monitor
├─ Weather
├─ Fuel Calculator
├─ Great Loop reference navigation
└─ Account menu
   ├─ My Account
   └─ Logout

Dashboard navigation
├─ Dashboard
├─ Routes
├─ Float Plans
├─ Monitoring
├─ Weather
├─ Vessels
├─ Contacts
├─ Waypoints
├─ Crew
├─ Operators
├─ Settings
├─ Help
└─ Tour

Dashboard workflow entries
├─ Getting Started
│  ├─ Add your vessel
│  ├─ Add a shore contact
│  ├─ Add an operator
│  └─ Add waypoints
├─ Continue Setup / Create My Route
├─ View Welcome / Show Me Around
├─ + Create Route
└─ Quick Actions
   ├─ Generate Route
   ├─ Add Vessel
   ├─ Add Contact
   ├─ Add Operator
   └─ Add Waypoint

Route actions, according to state
├─ Activate Route
├─ Complete Float Plan
├─ View & Send Float Plan / Edit Float Plan
├─ Edit Route
├─ Open Active Cruise
├─ Follow Page / Share Follow Link
├─ Download PDF Float Plan
├─ Cancel
└─ Delete / Archive
```

Dashboard **Routes** and **Float Plans** currently lead to the same route workspace region. The manual should not invent a separate Trips screen or history tab.

The **Getting Started** switch is persisted. A pending welcome/setup state can affect its presentation.

Primary evidence: [current navigation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/top_nav.cfm:619), [Dashboard](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm:191), and [route actions](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard.js:5241).

## 4. Reusable data inventory

All five reusable-record groups are maintained through Dashboard dialogs. They support multiple saved records and reuse across planning/Float Plans.

Deletion can be blocked when a record is referenced by a Float Plan. The member must address the references identified by the application. No archive control was found for these reusable records.

### Vessels

**Required:** Vessel Name, Type, Length, Hull Color.

| Field group | Visible fields |
|---|---|
| Image and default | Vessel Image; Remove image; Default Vessel |
| Basic identification | Vessel Name, Type, Length, Hull Color, Registration, Hailing Port, Make, Model |
| Additional identification | HIN, Year Built, Draft, Hull Material, Prominent Features |
| Communications | Radio Call Sign, MMSI, primary/secondary radio type, primary/secondary channel or frequency monitored, Vessel/Onboard Mobile Phone, Satellite Phone |
| Primary propulsion | Propulsion details, propulsion type, number of engines, primary fuel capacity |
| Auxiliary propulsion | Propulsion details, propulsion type, number of engines, auxiliary fuel capacity |
| Planning performance | Max Speed **(KPH)**, Most Efficient **(KPH)**, GPH at efficient speed, GPH at maximum speed, Total Fuel Capacity |
| Navigation equipment | Compass, Radar, GPS/DGPS, Depth Sounder, Charts, Maps, Other, other navigation equipment |
| Visual distress equipment | Electric Distress Light, Flag, Aerial Flare, Handheld Flare, Signal Mirror, Smoke |
| Audible distress equipment | Bell, Horn, Whistle |
| Other safety equipment | EPIRB UIN, anchor aboard, anchor line/rode length, dewatering device, exposure suits, fire extinguisher, flashlight/searchlight, raft/dinghy |
| Additional equipment | Other Equipment 1–4 |

Hull-material choices include Aluminum, Composite, Concrete, Fabric, Fiberglass, Plastic, Steel, and Wood.

Radio choices include None, CB, HF, MF, and VHF-FM. Propulsion choices include the listed diesel, gasoline and electric configurations, plus Fan, Oar, Paddle, and Wind; auxiliary propulsion permits None.

Important manual coverage:

- Image formats: JPG, PNG, WebP; maximum 5 MB.
- Only one default vessel is retained. Changing the default clears the prior default.
- Vessel performance can populate route calculations.
- Selecting a different vessel in the planner overwrites the corresponding speed/burn inputs.
- Saved vessel details are reused in the Float Plan/PDF workflow.
- Vessel onboard phone and Account mobile phone are separate fields.
- Numeric fields and allowed choices have server validation.
- The KPH/kn discrepancy must be resolved or explicitly handled before teaching performance entry; see Section 25.

### Operators / Captains

Fields: **Name** required; **Phone** and **Notes** optional. Phone must satisfy the current US-phone validation when supplied.

Members can add, edit, delete and reuse multiple operators. The primary Wizard selects one saved operator.

There is no separate reusable “Captain” entity to teach alongside Operators. Account sender identity is also separate from the selected operator.

### Passengers & Crew

Fields: **Name** required; **Phone**, **Age**, **Gender**, **Notes**.

The saved-person form has no separate passenger-versus-crew role field. Do not invent distinct CRUD workflows for those labels.

Members select saved people for a Float Plan. A solo trip can have no passengers.

### Contacts / Shore Contacts

Fields: **Name, Phone, Email**, all required by the current form. Phone uses the current US-phone validation.

There is no visible contact-type selector distinguishing “shore,” “emergency,” or other roles. The manual should describe selected trip contacts and their use, rather than inventing a contact taxonomy.

Contacts are reusable. The Wizard selects contacts for the trip. Actual email recipients vary by action:

- Review Basic Send: one selected saved contact.
- Premium initial send: selected contacts with email.
- Escalation and safe-arrival notices: their respective implemented recipient rules.
- Follow-link sharing: a separate member action.

### Waypoints

Fields: **Name**, **Latitude**, **Longitude**, **Notes**, plus an interactive map.

- Name is required and limited to 45 characters.
- Map click/tap and marker dragging establish location.
- Automatic location naming can assist until the member supplies a name.
- Planning requires usable coordinates even though the waypoint save form does not enforce every planning constraint.
- Saved waypoints can serve as a route start, destination, or intermediate leg endpoint.
- A route leg ends at the next selected waypoint; adding a leg does not create a different class of waypoint.
- Great Loop **Ports → Add to My Waypoints** creates a normal saved waypoint.
- The map provides NOAA chart/radar context where enabled.
- No current rendered marine-POI filter controls were found in the Dashboard dialog; dormant JS handlers are not member features.

Field evidence: [Dashboard forms](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm:475) and [vessel form](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm:625).

## 5. Full trip lifecycle

```text
Saved boating records and waypoints
    ↓
Create/select My Route → Set Start → Add Leg(s)
    ↓
Load into FPW Route Generator
    ↓
Review geometry, vessel assumptions, weather, time and fuel
    ↓
Save Route
    ↓
Saved route
    ↓ Activate Route / Complete Float Plan
Route-backed Float Plan Draft
    ├─ Basic Save & Send
    │    → PDF emailed to one contact
    │    → Draft preserved; no operational activation
    │
    └─ Premium Save & Send
         → Active plan and operational access
         → Scheduled / awaiting actual departure
              ↓ On Track
            Underway
              ├─ Delayed → progress paused
              ├─ Secure Night → overnight pause
              │      ↓ On Track
              │    Resume same leg
              └─ Complete Current Leg / Arrived
                     ↓
                   Awaiting Next Leg
                     ↓ Start Next Leg
                   Underway on next leg
                     ↓ repeat
                   Final leg completed
                     ↓ Close Float Plan + confirmation
                   Closed / Completed record
                   Monitoring stopped; safe-arrival attempt

Active route/Float Plan group
    └─ Cancel + confirmation
         → Cancelled; monitoring and operational access end
         → Not successful completion
```

Important distinctions:

- **Activate Route** prepares/opens a Float Plan draft. It does not send email.
- Scheduled departure does not establish actual departure.
- Projected progress reaching 100% does not complete a leg.
- Passing a return time does not close a trip.
- **Cancel** can end an active trip before every leg is complete, but does not produce “Trip Completed Safely.”
- **Archive** removes an eligible route from the Routes list while retaining protected history. It is not a history-view command.
- Editing an active route is subject to progress-preservation checks.
- Completed/cancelled/expired historical plans are read-only in the inspected Wizard path.

## 6. Trip Planner feature inventory

The current entry is Dashboard → **+ Create Route**, opening **FPW Route Generator**.

The principal planning functions are:

| Function | Implemented behavior |
|---|---|
| Create/select route | Enter Route Name; create or select an entry under My Routes |
| Choose route start | Select Route Start Waypoint; choose Set Start |
| Add stops/legs | Choose endpoint under Add Leg by Waypoint; choose Add Leg |
| Load planning route | Load populates the preview and Cruise Timeline |
| Select vessel | Saved vessel supplies performance assumptions |
| Set performance assumptions | Speed, burn, idle time, pace, weather, reserve, daily underway hours, fuel price |
| Review route | Summary cards, leg details, timeline/day rollups |
| Refine distance/path | Leg Edit Route opens geometry editing |
| Save generated route | Save Route creates or updates its saved planning snapshot |
| Resume | Dashboard Edit Route reopens the saved route |
| Prepare Float Plan | Activate Route / Complete Float Plan |
| Dispose of route | Delete or Archive according to state/history restrictions |

There is no current visible drag-reorder/up/down control for legs. Do not document backend reorder capabilities as an interface feature.

The primary planner does not expose a current departure-date control. Departure date/time and timezones belong in the Float Plan workflow. Hidden template-era controls should not become instructions.

Ordinary route planning currently requires authentication, not Premium membership.

## 7. Route/Trip Generator inventory

### Current build sequence

1. Prepare saved waypoints with valid coordinates.
2. Open **+ Create Route**.
3. Enter **Route Name**.
4. Under **My Routes & Waypoint Builder**, choose **Create** or select an existing route.
5. Choose **Route Start Waypoint → Set Start**.
6. Choose **Add Leg by Waypoint → Add Leg** for each next endpoint.
7. Choose **Load**.
8. Review assumptions, geometry, totals and **Cruise Timeline**.
9. Choose **Save Route**.

A **Guided Tour** explains these steps with Skip, Back, Next and Done; prerequisite steps can show Waiting.

### Persistence members must understand

| Action | Persistence behavior |
|---|---|
| Create, Set Start, Add Leg, Remove | Calls the server immediately |
| My Routes → Delete | Deactivates that waypoint-route record |
| Save Overrides | Saves geometry changes immediately |
| Load | Loads planning data; does not send a Float Plan |
| Save Route | Saves the generated route and planning snapshot |
| Close | Closes the dialog; does not save unsaved planning assumptions |
| Reset | Resets inputs/restores an editor baseline; does not undo all earlier saved operations |

Creating a My Route with an existing name can return/reactivate an owned record. It is not a reliable “duplicate route” command.

Removing a middle leg can reconnect a following leg and clear its geometry override. The manual should require review of the affected path and totals.

### Outputs and controls

- Summary cards: **Total Distance, Total Travel Hours, Estimated Fuel, Adjusted Speed, Fuel Cost, Locks, Offshore Legs, Expected Avg GPH**.
- Expandable **Cruise Timeline** legs.
- Day grouping and day rollups.
- Lock details, where mapped: identity, waterway, location, dimensions, communications, notes, source and Best/Typical/Worst wait estimates.
- **Retry** for failed lock-detail retrieval.
- Model-derived GREEN/YELLOW/RED day indicators.
- Point-based **Live Weather Assist**.

The Dashboard’s decorative route-detail curve is explicitly a display-only preview. It is not the geographic route map.

Evidence: [current generator controls](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/modals/route_generator_modal.cfm:1536), [planner behavior](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/routebuilder.js:7151).

## 8. Overrides, timing and fuel inventory

### Route geometry and mileage

For each applicable leg, **Edit Route** opens **Leg Geometry**:

- Computed NM
- Search place, marina, city…
- Search
- Clear Pin
- Clear Draw
- Revert to Default
- Save Overrides
- Map drawing/editing controls

A valid line requires at least two points. Search places a reference pin; it does not draw the route. Saved geometry changes recalculate distance and dependent estimates.

Without a canonical distance or saved override, a waypoint leg can use straight endpoint distance. This is not automatic safe-water routing.

No current visible “type a mileage override” or per-leg duration-override field was found. The manual should teach the actual geometry editor.

### Planning inputs

| Input | Meaning |
|---|---|
| Most Efficient Speed / Max Speed | Planner speeds in knots |
| GPH @ Efficient / Fuel Burn @ Max | Performance anchors |
| Idle Burn / Idle Hours | Planned idle consumption |
| Pace | Relaxed, Efficient Speed, Max Speed |
| Weather Factor | Adjusts estimated speed and consumption |
| Underway Hrs / Day | Controls planning day grouping |
| Reserve Method | One-Third Rule, Standard Reserve – 20%, Minimum Reserve – 15% |
| Fuel Price | Cost estimate |
| Vessel | Supplies editable starting assumptions |

The manual needs only the calculation explanations that affect decisions:

- Estimates depend on entered boat performance, route distance, pace, weather and idle time.
- The One-Third Rule is not simply “add 33% to consumption.”
- Fuel cost includes the selected reserve calculation.
- Daily time grouping may split one leg across days or combine portions of multiple legs.
- Mapped lock delays may affect time.
- **No canonical lock mapping for waypoint leg** means missing mapping, not proof of zero locks.
- Day colors are planning indicators, not navigation clearance.

### Operational timing controls

| Control | Location | Effect |
|---|---|---|
| Set Active-Trip Pace | Active Cruise | Saves immediately and refreshes projections |
| Add Delay Time | Active Cruise | Adds positive whole minutes to manual ETA adjustment |
| Clear Delay | Active Cruise | Clears the manual delay total |
| Daily Start Time | Active Cruise | Saves the trip-local next-day timing setting |
| Secure Night | Check-in | Pauses progress and moves the overnight checkpoint |
| On Track | Check-in | Starts/resumes the operational leg |
| Apply Weather to Route | Active Cruise | Saves the looked-up weather factor |

Changing these is not interchangeable. In particular, **Add Delay Time is not a check-in**.

### Linked Fuel Calculator

The linked calculator is independent of saved member data:

- Inputs include distance, speed/burn, idle time, weather, daily underway hours, pace, usable capacity, reserve and fuel price.
- Results update as inputs change.
- **Calculation Breakdown and JSON** expands details.
- **Copy Result JSON** copies results; it does not save a vessel or route.
- **Reset** restores defaults, and a fresh load does not restore an earlier scenario.
- Range estimates depend on usable capacity and reserve; they are not a guaranteed safe reach.

## 9. Float Plan Wizard inventory

The primary Dashboard modal has six steps.

| Step | Fields and purpose | Required / behavior |
|---|---|---|
| **1. Basics** | Missing account sender name, Float Plan Name, Vessel, Operator, Operator has PFD | Plan name, saved vessel and operator required. At least first or last account name required when missing. PFD checkbox optional |
| **2. Times & Route** | Departing From, departure date/time/timezone, Returning To, return date/time/timezone | All required. Return must follow departure; sending requires a future return |
| **3. People & Safety** | Email while underway, Rescue Authority, Food, Water, Notes | Rescue Authority required; N/A – Call 911 available. Other listed inputs optional in validation |
| **4. Passengers, Crew & Contacts** | Trip Manifest, On This Trip, searchable Passengers and Contacts tabs, selected counts | Passengers optional; at least one contact required |
| **5. Waypoints** | Numbered In Route waypoint summary | Read-only in the primary modal |
| **6. Review** | Sender, saved PDF preview, Save Float Plan, Basic/Premium choices | Explain saved preview versus current edits, recipients, access and send result |

Additional behavior:

- Saved records and existing draft selections load into the Wizard.
- Missing locations may derive from route endpoints or home port.
- The app can suggest return timing; manually edited return timing is preserved.
- **Next/Back do not autosave.**
- **Save Float Plan** validates through the current step, saves, and leaves the modal open.
- Closing discards the current in-memory Wizard; no unsaved-change confirmation was found.
- Review PDF reflects persisted data. Save before relying on the preview.
- Actual send actions save current changes first.
- Scheduled departure cannot be changed after actual departure is recorded.
- Route-backed plans cannot be switched/detached from their route through ordinary Wizard saving.
- New primary-modal plans must originate from a route.

Evidence: [six-step modal](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm:845), [Wizard navigation and saving](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/floatplanWizard.js:1244).

## 10. Send/share workflow

| Behavior | Review Basic Save & Send | Premium Save & Send |
|---|---|---|
| Starting point | Route-backed Draft | Route-backed Draft |
| Recipient | One selected saved contact with usable email | Selected plan contacts with email |
| Confirmation | Recipient and feature exclusions; Continue with Basic Send | Current save-and-send flow; no extra acknowledgment checkbox found |
| Result | PDF emailed; Draft retained | Plan becomes Active; operational route and monitoring initialized |
| Monitoring / Active Cruise | Not activated | Available for the exact eligible trip |
| Follow sharing | Not supplied by this Basic send | Separate Follow-link action |
| Payment/access | No Premium credit consumed | Eligible membership or one Premium Send Credit |

When multiple contacts are selected for Basic, the member chooses one. Invalid-email choices are disabled.

Premium UI can show **Buy One Trip**, **Monthly Membership**, **Annual Membership**, or an unavailable purchase state. Purchasing does not send the Draft.

A consumed Premium Send Credit provides operational access for **21 days from consumption/send**, not scheduled departure. Eligible membership can independently provide access.

After a committed Premium send, **Show Original Premium Send Result** returns the earlier result without spending another credit or sending again.

The manual must distinguish a definite failure from uncertain submission. Review Basic explicitly instructs:

> The email was submitted, but its completion could not be confirmed. Do not resend; contact support.

Do not generalize “retry is always safe.”

Common blocks include another active trip group, expired return time, missing contacts/email, missing access/credit, or failed PDF/activation preparation.

The alternate one-day Basic form is not the primary workflow. Its current reachability and materially different monitoring behavior are recorded in Section 25.

## 11. Shore Contact behavior relevant to members

Initial Float Plan emails attach the PDF. They do not automatically contain the private Follow URL.

For an eligible active route, Dashboard **Share Follow Link** provides:

- Follow Page Link
- Open Follow Page
- Send by Text Message
- Copy Link

The recipient does not need the captain’s account session to use a valid shared link.

The Follow experience can display:

- Current leg, next stop and route progress
- Check-in/status information
- Conditions
- Map and Open Full Map
- Track Log
- PDF download when available
- Latest Photos
- Trip Summary
- Cruise Timeline
- Voyage Stream

The manual should explain that estimated markers and ETAs are not continuous live tracking. A green status is not proof of the vessel’s location or condition.

### Voyage Stream

Signed-in owners can post text and/or one JPG, PNG or WebP photo up to 5 MB.

Quick tags—All good, Underway, Weather delay, Anchored safely—insert text; **Post Update** publishes.

Owner-created nonsystem posts can be deleted after confirmation. No edit control was found.

Followers can react with Like, Love, Boat or Wave and submit comments up to 500 characters. First interaction requests a display name, optional email, and a password when applicable to the stream’s interaction configuration.

Do not promise that password mode universally prevents reading by someone holding a valid share token.

### Completion and access

Successful completion can produce a restricted **Trip Completed Safely** view. It does not retain the active map/posts/actions.

Cancelled or expired trips are not automatically “completed safely.” No independent fixed Follow-link lifetime was established.

The member should arrange expectations directly with shore contacts. FPW does not confirm that the initial email was delivered or read.

## 12. Active Cruise inventory

| Panel / control | What the member sees or does |
|---|---|
| Map Overview / Open Full Map | Planned route and available last reported GPS context |
| Trip overview | Scheduled Departure, Current Leg, Distance Complete, Next Stop/Arrived Destination, ETA |
| Route summary | Complete, Total Route, Remaining, Final Arrival |
| Current Leg Estimate | Endpoints, distance, remaining distance, ETA, adjusted speed, weather factor, progress |
| Set Active-Trip Pace | Relaxed / Efficient Speed / Max Speed; changes save immediately |
| Route Timeline | Expand a leg; inspect departure/arrival, distance, progress and available lock details |
| Selected Leg Data | Information for the selected row; selection does not start that leg |
| Check-In | On Track, Delayed, Changed Plan, Secure Night; optional note |
| Timing | Last Check-In, Secure for Night, Next Expected Check-In, Current Delay |
| Delay controls | Add Delay Time; Clear Delay |
| Daily timing | Daily Start Time; Save Daily Start Time |
| Quick Notes | Private by default; optionally publish the note to Voyage Stream |
| Shore Contact | Available Call, Text, Email device links |
| Crew & Passengers | Operator/captain and passenger/contact summary |
| Weather | Current-leg Start/End; Check Conditions; Apply Weather to Route |
| Leg operations | Complete Current Leg / Arrived; Start Next Leg |
| Trip closure | Close Float Plan after all legs are completed |

Quick Notes supports up to 1,200 characters and presets including All good, Underway, Weather delay, Anchored, Docking, Fuel, Mechanical and Marina call. Choosing public posting changes the action from **Save Note** to **Save & Post**. This is not email.

No visible captain-note edit/delete control was found.

Disabled operational actions display reasons. Missing access, missing route, conflicting active trips and closed trips can prevent the normal console.

## 13. Check-in, timing and overnight workflow

| Action | Actual effect |
|---|---|
| **On Track**, before actual start | Records operational departure and starts the first leg |
| **On Track**, after a pause | Resumes the same Delayed/Secure Night leg |
| **Delayed** | Pauses underway progress; monitoring remains active |
| **Changed Plan** | Reports a status; does not edit the route or schedule |
| **Secure Night** | Pauses progress and moves the next checkpoint to the next Daily Start |
| **Add Delay Time** | Adds a manual ETA adjustment; does not check in |
| **Clear Delay** | Clears manual delay; does not clear every pause or monitoring obligation |
| **Save Daily Start Time** | Saves trip-local daily timing; does not start/resume a leg |
| **Complete Current Leg / Arrived** | Explicitly completes the current underway leg |
| **Start Next Leg** | Starts the pending leg after the previous leg was completed |
| **Close Float Plan** | Explicitly closes the completed route-backed trip |

Daily Start defaults to **08:00 local to the trip**. Passing that time does not resume a paused leg.

Use the displayed **Next Expected Check-In** as the member’s practical authority. Current code generally uses an evening checkpoint or the next Daily Start, with a future planned return potentially making the checkpoint earlier.

Source defaults are 60 minutes’ grace and 120 minutes after recorded Missed before escalation. These are evaluation rules, not proof that a scheduler ran or a notification arrived.

A subsequent accepted check-in resolves Missed/Escalated monitoring and recalculates the checkpoint.

### Location and confirmation

The web check-in attempts location capture, but denied/unavailable GPS does not block the status report.

An accepted check-in followed by a panel-refresh failure should lead the member to refresh the display, not repeat the check-in blindly.

### Monitoring Console

The Monitor page is read-only. It includes:

- Trip State, Health, Mode, Monitoring Status
- Next Check-In, Last Status, GPS Quality
- Route and last check-in location
- Alert Readiness
- Monitoring Audit
- GPS Capture History
- Expandable technical reference

The manual should explain the human-readable state and clocks. Internal diagnostics are not a tutorial topic.

GPS history is not continuous tracking. The page can mark older location data stale.

## 14. Completed-trip functionality

Completion requires explicit member action.

For route-backed trips:

1. Complete each leg.
2. Complete the final leg.
3. Choose **Close Float Plan**.
4. Confirm closure.

Monitoring stops after committed closure. Safe-arrival notification is attempted afterward; email failure does not undo closure.

The owner’s **Completed trip record** contains:

- Trip Identity
- Timing
- Route Summary
- Completion Summary
- Shore Contact/source limitations
- Back to Dashboard

Planned and actual times remain distinct.

The page is read-only. No reopen, edit, delete or route-reuse control was found.

Important limits:

- No current Dashboard Completed Trips/Trip History entry was verified.
- The safe-arrival email is a verified entry.
- Vessel name uses the current associated vessel profile rather than an immutable historical snapshot.
- Historical shore-contact details are suppressed where only mutable records exist.
- Route geometry availability is reported; this page is not an editable historical map.

Evidence: [completed record](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/completed-trip.cfm:548).

## 15. Weather

Three distinct weather contexts need explanation.

| Context | Actions and interpretation |
|---|---|
| Marine Weather Briefing | Home Port / ZIP / Coordinates; Update; conditions, waves, tides, alerts, forecasts and maps |
| Route Generator Live Weather Assist | Refresh Suggestion from route start or Lookup Point; Apply Suggested explicitly updates Weather Factor |
| Active Cruise | Choose current-leg Start/End; Check Conditions; Apply Weather to Route explicitly saves the factor |

The dedicated weather page includes:

- Marine risk assessment
- Conditions Now
- Waves/Seas
- Tide Now
- Marine Alerts and expandable alert details
- Next 12 Hours
- Tide & Water Level: Today / Tomorrow
- Source & Station Details
- NOAA Weather Map
- NOAA Zone Area Forecast

Map overlays include radar, wind forecast, cloud/satellite, surface fronts and marine warnings where available.

The page reports location, update time, provider/station and unavailable data. Missing values should not be interpreted as zero conditions.

ZIP lookup represents an approximate area. Home-port setup can improve the default location.

Fetching weather does not automatically apply it to route assumptions. Point-based suggestions are not a forecast for every place and time along the trip.

The visible favorite-star control has no verified handler; omit favorite-management instructions pending clarification.

## 16. Account/member settings

| Area | Current member functionality |
|---|---|
| Profile | View email, last login/update; edit first name, last name, mobile phone; Refresh; Save Profile |
| Home Port | Street, city, state, ZIP, phone, latitude, longitude; Save Home Port |
| Password | Current password, new password, confirmation; change password |
| Membership | View current access/membership and Premium Send Credits |
| Purchase | Buy One Trip, Monthly Membership, Annual Membership when available |
| Billing | Manage Billing opens the hosted billing portal when eligible |
| Codes | Redeem founder/promotional/launch code |
| Session | Logout |

At least one profile name is required. Passwords require at least eight characters and matching confirmation; changing an existing password requires the current password.

Email is displayed read-only. No current Account email-change, account-deletion or general notification-preferences editor was found.

Do not promise specific cancellation options inside the hosted billing portal; its live configuration was not inspected.

Checkout can remain “being confirmed.” The manual should tell members to refresh/check Account rather than assume a return from checkout sent a Float Plan.

The Account **Companion Devices** section is commented out and unavailable. You confirmed Companion is not member available.

## 17. User-facing emails and notifications

| Trigger | Recipient / member expectation | Confirmation or limitation |
|---|---|---|
| Review Basic Send | One chosen saved contact; PDF | Draft remains; uncertain submission can explicitly prohibit resend |
| Premium Send | Selected contacts with email; precautionary PDF | Trip activates after committed send workflow |
| Separate operational Basic Send | Its notification contact; PDF | Exceptional alternate flow; Basic monitoring differs |
| Departure reminder | Owner of eligible unstarted active route-backed trip | Limited windows around scheduled departure; no arbitrary catch-up |
| Missed check-in | Owner notification becomes eligible | Evaluation-dependent |
| Escalation | Selected trip contacts; applicable operational Basic contact | Distinct from owner Missed notice |
| Accepted status check-in | Updates trip/monitoring and applicable voyage stream | Do not promise an email for every routine check-in |
| Safe arrival | Owner and applicable associated contacts after verified closure | Owner Completed Trip link; completed Follow link where available |
| Account creation | Welcome email | Creation is not undone by mail failure |
| Password-reset request | Reset email if the account exists | Generic on-screen response does not confirm account existence or delivery |
| Account password/profile change | No separate email hook found | On-screen success |
| Checkout | Access/credit confirmation in Account | No verified FPW receipt email; external billing email settings not inspected |

Password-reset links last 60 minutes in the inspected flow, are replaced by a new request, and are cleared after successful use. Reset returns the member to sign-in.

The manual must not label SMTP acceptance as delivered or imply recipient read acknowledgment.

## 18. Warnings, help and errors

The manual should explain the following in context rather than reproduce every backend message.

| Area | Important guidance |
|---|---|
| Initial setup | Missing vessel, contact, operator or usable waypoints blocks the intended route workflow |
| Saved-record deletion | Referenced records may need to be removed from associated plans first |
| Route creation | Missing coordinates, identical endpoints, discontinuous legs and unavailable data |
| Route changes | Removing a leg can change neighboring geometry; Reset/Close are not universal undo |
| Estimates | Verify knots, route geometry, consumption and mapping coverage |
| Wizard | Required fields, date/timezone checks, unsaved changes and stale saved PDF preview |
| Sending | Missing access, no usable recipient, existing active trip, expired return time, uncertain submission |
| Active Cruise | Disabled actions explain current-state restrictions |
| Check-in | GPS missing does not necessarily mean check-in failed |
| Refresh failure | Refresh after an accepted action rather than repeat it |
| Monitoring | No active trip, access expired, no route, uninitialized/closed monitoring, conflicting trips |
| Weather | Invalid ZIP/coordinates, unavailable station/data, lookup timeout |
| Account | Invalid phone/password/code; checkout pending or unmatched |
| Shared Follow | Invalid/unavailable access, unavailable PDF, limited completed view |

Available help includes Dashboard Tour, Route Generator Guided Tour, setup prompts, Help search and FAQs.

Contact Support is a contextual support handoff, not an emergency-reporting workflow.

## 19. Mobile differences

Source confirms responsive presentation, not a separately implemented mobile website workflow:

- Header navigation collapses to a mobile menu.
- Forms and planner grids stack.
- Route Generator uses a vertically scrolling layout at smaller widths.
- Geometry-map editing remains available in a compact overlay.
- Wizard manifest summaries can expand/collapse.
- Active Cruise columns stack and timeline details move below summaries.
- Call/Text links depend on the device’s handlers.

The manual should use shared procedures with short mobile notes. Phone/tablet screenshots and touch behavior still need a later authenticated browser/device pass.

### Companion — owner-only discovery appendix

**Availability:** You confirmed it is not currently available to members. Do not include installation or pairing as an ordinary manual procedure.

| Topic | Implemented working-tree source | Availability/limit |
|---|---|---|
| Screens | Loading, No Active Trip, Active Trip, Check-In Confirm, Offline Queue, Device Pairing | Not a released member workflow |
| Access | Manual pairing-code entry; device name; disconnect | Required main-app pairing panel is hidden |
| Trip selection | Automatically resolves the current active route-backed plan | No vessel/trip chooser |
| Active screen | Trip/current leg, monitoring, last/next check-in, last GPS | No routed map, weather or full timeline |
| Status actions | On Track, Delayed, Changed Plan, Secure for the Night | Assistance intentionally blocked |
| Notes | Optional check-in note | No full captain-note history/editor |
| Location | Opt-in, one-shot foreground GPS | No continuous/background tracking |
| Location failure | Try Location Again, Submit Without Location, Cancel / Go Back | Does not silently force location-less submission |
| Offline handling | One pending check-in stored on device | Blocks another pending check-in |
| Retry | Manual Retry Check-In; preserves submission ID and original GPS | No reconnect/background auto-flush found |
| Discard | Confirmation removes the pending local record | Does not undo a server-processed action |
| Disconnect | Attempts revoke; clears local pairing even if online revoke fails | Does not close trip or stop monitoring; queue is separate |
| Native permissions | Foreground location declarations | No background-location or battery-exemption procedure found |
| Satellite | No satellite/SMS integration | HTTP connectivity is required; GPS capture is not transmission |
| Privacy | Native credentials use secure storage; pending note/location uses separate app-data storage | No verified retention-policy/member-management workflow |
| Leg/closure controls | Start Next Leg/Arrived panel hidden and not functional | Use main FPW; no Companion final closure |
| Demo | Mock trip and mock submission remain visible in source | Demo does not update FPW |

Important distinctions for future instructions:

- Captured GPS ≠ queued report ≠ server acceptance.
- Timeout means unconfirmed; the server may still process the request.
- Retry should retain the same submission identity.
- Current phone submissions do not transmit the local queue-creation timestamp supported by the backend.
- Later acceptance does not backdate monitoring.
- Companion GPS is not proven to update every main-FPW map.
- No tracking start/stop, background sampling, battery optimization, satellite delivery, push-notification or complete native release workflow should be invented.

The source is substantial enough to support a future Companion chapter, but member availability is not. Reserve a chapter outline for a later approved release; keep it out of the current member TOC.

## 20. Explicit exclusion list

Exclude from the ordinary member manual:

- Admin, Recovery Center and scheduled-task administration
- Internal reporting, APIs, schemas and server/hosting details
- Developer/test/debug/sample screens
- Public marketing, SEO, press and editorial content
- Private payment configuration
- Hidden template, comfort-profile, overnight-bias and rebuild controls
- Backend-only leg reorder/override actions
- Older unlinked Fuel Calculator and navigation copies
- Unreachable legacy/V1/V2 implementations
- Companion installation/use while it is unavailable to members

Include only the relevant portion of these borderline areas:

| Borderline area | Treatment |
|---|---|
| Public Fuel Calculator | Include because current member navigation links it |
| Great Loop libraries | Include planning references and Ports → Add to My Waypoints; exclude editorial guides |
| Follow pages | Explain what members share and how owner posting works |
| Help / Support | Include access and contextual use |
| Sign-in/reset pages | Short account-recovery handoff; no public-site tour |
| Alternate wizard/Basic flow | Brief current ambiguity because checkout fallback can expose it |
| Monitoring technical panels | Recognize their presence; avoid internal diagnostic instruction |

## 21. Screenshot plan

No screenshots were created.

Use new disposable canonical accounts and fictional boating details in a later authorized capture phase. Do not capture real contact details, payment information or bearer links.

| ID | Chapter / screen | Purpose and visible content | Recommended callouts |
|---|---|---|---|
| S01 | Dashboard | Navigation, setup readiness, route workspace, saved items | 1 navigation; 2 setup; 3 routes; 4 saved information |
| S02 | Vessel basics | Required identity, image, default vessel | 1 required fields; 2 default; 3 image |
| S03 | Vessel performance/safety | Planning numbers and equipment groups | 1 units; 2 burn/capacity; 3 safety |
| S04 | Operator / Crew / Contact dialogs | Reusable-person distinctions | 1 record type; 2 required fields; 3 Save |
| S05 | Waypoint | Map, marker, coordinates, name | 1 map; 2 coordinates; 3 Save |
| S06 | Generator route construction | My Routes, Set Start, Add Leg, Load | 1 Create; 2 start; 3 legs; 4 Load |
| S07 | Generator assumptions/totals | Vessel, speeds, pace, reserve, weather, summary | 1 vessel; 2 assumptions; 3 totals; 4 Save Route |
| S08 | Leg Geometry | Actual polyline and Computed NM | 1 drawing; 2 pin versus line; 3 distance; 4 Save Overrides |
| S09 | Cruise Timeline / locks | Expanded leg, days, mapped lock details | 1 leg; 2 day rollup; 3 lock coverage |
| S10 | Great Loop Port | Reference details and Add to My Waypoints | 1 source; 2 coordinates; 3 add |
| S11 | Wizard Basics / Times | Required records, sender, timezone fields | 1 name; 2 vessel/operator; 3 departure; 4 return |
| S12 | Wizard Safety | Authority, supplies and notes | 1 authority; 2 optional information |
| S13 | Wizard Manifest / Waypoints | Selected people and read-only route order | 1 passenger/contact tabs; 2 counts; 3 route summary |
| S14 | Wizard Review | PDF, Save, Basic versus Premium | 1 preview; 2 save; 3 send choices |
| S15 | Basic confirmation / Premium result | Recipient and committed-result distinction | 1 recipient; 2 feature limits; 3 result |
| S16 | Share Follow Link | Open, text and copy actions | 1 generated link; 2 Open; 3 Text/Copy |
| S17 | Follow / Voyage Stream | Recipient view and owner post | 1 status; 2 estimates; 3 stream; 4 posting |
| S18 | Active Cruise overview | Current leg, route summary, timeline | 1 current leg; 2 final arrival; 3 selected leg |
| S19 | Check-in and timing | Four statuses, next expected time, delays, Daily Start | 1 status; 2 checkpoint; 3 delay; 4 Daily Start |
| S20 | Overnight / next-leg states | Secure state versus Awaiting Next Leg | 1 secure checkpoint; 2 resume; 3 Start Next Leg |
| S21 | Monitor | State, health, GPS, alert readiness | 1 status; 2 next check-in; 3 location age |
| S22 | Quick Notes / weather apply | Private/public choice and explicit apply | 1 sharing checkbox; 2 Save/Post; 3 weather apply |
| S23 | Completed owner / shared views | Read-only completion and differing audiences | 1 actual completion; 2 historical limits; 3 Back |
| S24 | Weather | Location, marine conditions, alerts, tides | 1 lookup; 2 update time; 3 alerts; 4 tides |
| S25 | Account | Profile/home port, password, access/credits | 1 profile; 2 home port; 3 membership |
| S26 | Linked Fuel Calculator | Inputs, results, breakdown, reset | 1 assumptions; 2 results; 3 reset/copy |

Capture meaningful desktop and phone examples, rather than duplicating every screenshot.

Companion screenshots remain deferred to its release-specific documentation phase.

## 22. Scenario plan

| ID | Scenario | Features demonstrated |
|---|---|---|
| E01 | First simple day trip | Setup, two waypoints, route, Wizard, send, On Track, completion |
| E02 | Solo boater | Operator versus account identity; no passengers; shore-contact selection |
| E03 | Trip with passengers/crew | Reusable people, manifest selection, PDF review |
| E04 | Reuse saved locations | My Routes, waypoint endpoints, reopen/edit route |
| E05 | Correct an unrealistic distance | Edit Route geometry, Computed NM, estimates, Save Overrides |
| E06 | Plan fuel and time | Vessel assumptions, units, pace, weather, idle fuel, reserve |
| E07 | Lock/bridge planning | Library references, mapped lock delays, missing mapping, source verification |
| E08 | Running late underway | Delayed versus Add Delay Time; checkpoint remains visible |
| E09 | Overnight in the same leg | Secure Night, Daily Start, next-day On Track |
| E10 | Multi-leg trip | Complete Current Leg, Awaiting Next Leg, Start Next Leg |
| E11 | Multi-day trip | Daily route grouping, overnight pauses, accumulated delay |
| E12 | Share with family ashore | PDF versus Follow Link, text/copy, updates and comments |
| E13 | Finish safely | Final-leg completion, Close Float Plan, safe-arrival notice, read-only record |
| E14 | Cancel a trip | Cancel confirmation and distinction from safe completion |
| E15 | Purchase/send recovery | Credit purchase, return to Draft, pending confirmation, original-send result |
| E16 | Missing GPS or refresh failure | Recorded status versus missing location; refresh without duplicate submission |
| E17 | Bad weather during planning/underway | Lookup versus explicitly apply weather factor |
| E18 | Organize saved information | Edit reusable records; referenced-record deletion block |

Future Companion scenarios—pairing, optional location, offline retry, revoked device—remain owner-only planning items.

## 23. Proposed final manual table of contents

### Part I — Getting Started

1. Find Your Way Around FPW
2. Complete Your First-Time Setup

### Part II — Set Up Your Boating Information

3. Add and Maintain Your Vessels
4. Save Operators and Captains
5. Save Passengers and Crew
6. Choose and Maintain Shore Contacts
7. Create and Reuse Waypoints

### Part III — Plan Your Trip

8. Create, Save and Reopen a Route
9. Choose Your Vessel and Planning Assumptions
10. Use Great Loop Planning References

### Part IV — Build and Refine Your Route

11. Adjust a Leg’s Path and Distance
12. Understand the Cruise Timeline, Time and Fuel Estimates
13. Use Weather in Planning and Underway
14. Use the Linked Fuel and Range Calculator

### Part V — Create and Send Your Float Plan

15. Complete the Six-Step Float Plan Wizard
16. Review and Send: Basic, Premium and Credits
17. Share Your Trip and Post Voyage Updates

### Part VI — Use FPW While Underway

18. Read Active Cruise
19. Check In and Understand Monitoring
20. Handle Delays, Overnight Stops and Multiple Legs
21. Keep Captain Notes and Reach Your Contacts

### Part VII — Finish and Review Your Trip

22. Complete or Cancel Your Trip
23. View the Completed Trip Record

### Part VIII — Account and Reference

24. Manage Your Profile, Home Port, Password and Membership
25. Use Help and FPW on Smaller Screens

### Part IX — Common Scenarios and Troubleshooting

26. Worked Boating Scenarios
27. Troubleshooting and Status Reference

Companion is excluded from this current member TOC. Its future chapter outline should cover access/setup, current trip, check-ins/location, offline results, device privacy and main-app differences after availability is approved.

## 24. Feature-to-chapter coverage matrix

Page IDs refer to Section 2. Screenshot IDs refer to Section 21. Scenario IDs refer to Section 22.

**Priority:** P1 = essential workflow; P2 = supporting feature; Hold = unresolved/unavailable, not normal instructions. Field sets are enumerated in Sections 4 and 9 rather than repeated as separate rows for each input.

| Feature | Page/route | User action | Chapter | Screenshot | Scenario | Priority | Notes |
|---|---|---|---|---|---|---|---|
| Member navigation | D/header | Navigate between workspaces | 1 | S01 | E01 | P1 | Use current labels |
| Account menu/logout | AC/header | Open account; sign out | 24 | S25 | — | P1 | Distinct from device revoke |
| Getting Started | D | Show/hide; follow setup | 2 | S01 | E01 | P1 | Persisted switch |
| Welcome / Dashboard tour | D | View Welcome; Show Me Around/Tour | 2,25 | S01 | E01 | P2 | Guided assistance |
| Setup readiness | D | Resolve missing records | 2 | S01 | E01 | P1 | Waypoint requirement |
| Quick actions | D | Open create dialogs/planner | 1–8 | S01 | E01 | P2 | Alternate entries |
| Add vessel | V | Enter identity/equipment | 3 | S02–03 | E01 | P1 | Required fields listed |
| Edit vessel | V | Update reusable information | 3 | S02–03 | E18 | P1 | Affects later use |
| Delete vessel | V | Confirm deletion | 3,27 | — | E18 | P2 | References may block |
| Vessel image | V | Upload/remove image | 3 | S02 | — | P2 | Formats/size |
| Default vessel | V | Set default | 3,9 | S02 | E06 | P1 | One default |
| Vessel performance | V | Enter speed/burn/capacity | 3,9 | S03 | E06 | P1 | Unit issue held |
| Vessel safety/communications | V | Maintain equipment and radio fields | 3,15 | S03 | E01 | P1 | Reused details |
| Add operator | O | Save name/phone/notes | 4 | S04 | E02 | P1 | Reusable |
| Edit operator | O | Update operator | 4 | S04 | E18 | P2 | Separate from profile |
| Delete operator | O | Confirm deletion | 4,27 | — | E18 | P2 | Reference checks |
| Select operator | F | Choose saved operator | 15 | S11 | E02 | P1 | One selected operator |
| Add passenger/crew | P | Save person | 5 | S04 | E03 | P1 | No separate role field |
| Edit passenger/crew | P | Update saved person | 5 | S04 | E18 | P2 | Reusable |
| Delete passenger/crew | P | Confirm deletion | 5,27 | — | E18 | P2 | Reference checks |
| Select manifest | F | Select/search passengers | 15 | S13 | E03 | P1 | Optional for solo |
| Add contact | C | Save name/phone/email | 6 | S04 | E01 | P1 | All required |
| Edit contact | C | Update saved contact | 6 | S04 | E18 | P1 | Verify email |
| Delete contact | C | Confirm deletion | 6,27 | — | E18 | P2 | Reference checks |
| Select trip contacts | F | Select/search contacts | 6,15 | S13 | E12 | P1 | At least one |
| Add waypoint | W | Name/location/notes | 7 | S05 | E04 | P1 | Usable coordinates |
| Edit waypoint/map marker | W | Enter coordinates or move marker | 7 | S05 | E04 | P1 | Review position |
| Delete waypoint | W | Confirm deletion | 7,27 | — | E18 | P2 | Reference checks |
| Waypoint chart/radar context | W | Toggle available map overlays | 7 | S05 | E04 | P2 | Layer limitations |
| Open Route Generator | D/R | + Create Route / Generate Route | 8 | S06 | E01 | P1 | Same planner |
| Planner Guided Tour | R | Follow tour | 8,25 | S06 | E01 | P2 | Prerequisites |
| Create My Route | R | Enter name; Create | 8 | S06 | E04 | P1 | Immediate persistence |
| Select existing My Route | R | Choose saved source | 8 | S06 | E04 | P1 | Not clone command |
| Set route start | R | Set Start | 8 | S06 | E04 | P1 | Saved waypoint |
| Add route leg/stop | R | Add Leg | 8 | S06 | E10 | P1 | Sequential endpoints |
| Remove route leg | R | Remove | 8,11 | S06 | E05 | P1 | Review reconnection |
| Delete My Route | R | Delete source route | 8 | — | E18 | P2 | Distinct from Dashboard Delete |
| Load route | R | Load | 8 | S06 | E04 | P1 | No send |
| Select vessel in planner | R | Choose Vessel | 9 | S07 | E06 | P1 | Overwrites performance inputs |
| Edit performance assumptions | R | Adjust speed/burn | 9,12 | S07 | E06 | P1 | Knots |
| Pace | R | Choose Relaxed/Efficient/Max | 9,12 | S07 | E06 | P1 | Changes estimates |
| Idle consumption | R | Enter burn/hours | 12 | S07 | E06 | P2 | Added fuel |
| Reserve | R | Select reserve method | 12 | S07 | E06 | P1 | Explain conventions |
| Fuel price/cost | R | Enter price; review cost | 12 | S07 | E06 | P2 | Estimate |
| Daily underway hours | R | Adjust hours/day | 12 | S09 | E11 | P1 | Day grouping |
| Route totals | R | Review summary | 12 | S07 | E06 | P1 | Missing-data caveats |
| Cruise Timeline | R | Expand legs/days | 12 | S09 | E10 | P1 | Day slices |
| Lock details/retry | R | Expand; Retry if needed | 10,12 | S09 | E07 | P1 | Coverage not guaranteed |
| Day indicators | R | Interpret color/rollup | 12 | S09 | E11 | P2 | Planning indicator |
| Geometry editor | R | Edit Route; draw/edit line | 11 | S08 | E05 | P1 | Actual path review |
| Geometry place search | R | Search; Clear Pin | 11 | S08 | E05 | P2 | Pin is not route |
| Geometry save/revert | R | Save Overrides; Clear Draw; Revert | 11 | S08 | E05 | P1 | Immediate save |
| Weather suggestion | R | Refresh Suggestion / Lookup Point | 13 | S07 | E17 | P2 | Point-based |
| Apply weather suggestion | R | Apply Suggested | 13 | S07 | E17 | P1 | Explicit apply |
| Save generated route | R | Save Route | 8 | S07 | E04 | P1 | Planning snapshot |
| Reset / Close | R | Reset inputs / close modal | 8,27 | S07 | E04 | P1 | Not universal undo |
| Reopen saved route | D/R | Edit Route | 8,11 | S01 | E04 | P1 | Preserve progress rules |
| Activate route | D/F | Activate Route | 8,15 | S01 | E01 | Opens/prepares Draft |
| Rebuild draft confirmation | D/F | Review replacement warning | 15,27 | — | E04 | P1 | Can replace Drafts |
| Delete generated route | D | Delete | 8,27 | — | E18 | P2 | State/history restrictions |
| Archive generated route | D | Archive | 8,23 | — | E18 | P2 | Removes list entry |
| Great Loop Locks | GL | Search/filter/map/detail | 10 | S09 | E07 | P2 | Reference data |
| Great Loop Anchorages | GL | Search/filter/map/detail | 10 | — | E09 | P2 | Verification/source |
| Great Loop Ports | GL | Search/filter/map/detail | 10 | S10 | E04 | P2 | Services/approach |
| Port to waypoint | GL/W | Add to My Waypoints | 7,10 | S10 | E04 | P2 | Does not add route leg |
| Great Loop Bridges | GL | Filters/clearances/schedules | 10 | — | E07 | P2 | No vessel clearance check |
| Wizard sender/Basics | F | Set name, vessel, operator | 15 | S11 | E01 | P1 | Sender ≠ operator |
| Wizard Times & Route | F | Set locations/times/zones | 15 | S11 | E01 | P1 | Validation |
| Wizard People & Safety | F | Authority/supplies/notes | 15 | S12 | E03 | P1 | Required versus optional |
| Wizard Manifest | F | Select people/contacts | 15 | S13 | E03 | P1 | Search and counts |
| Wizard Waypoints | F | Review route order | 15 | S13 | E04 | P1 | Read-only |
| Wizard Next/Back | F | Navigate steps | 15 | S11 | E01 | P1 | No autosave |
| Save/resume Draft | F | Save Float Plan; reopen | 15 | S14 | E01 | P1 | Close may lose unsaved edits |
| PDF preview/download | F/D/SF | Review/download saved PDF | 15–17 | S14 | E12 | P1 | Availability varies |
| Review Basic Send | F | Choose recipient; confirm | 16 | S15 | E12 | P1 | PDF only |
| Premium Send | F | Save and send | 16 | S14–15 | E01 | P1 | Activates trip |
| Purchase access/credit | F/AC | Buy trip/membership | 16,24 | S25 | E15 | P1 | Purchase does not send |
| Original send result | F | Show Original Premium Send Result | 16,27 | S15 | E15 | P1 | No repeat send |
| Uncertain submission | F | Follow hold/support instruction | 16,27 | — | E15 | P1 | No blind resend |
| Open Follow | D/SF | Follow Page | 17 | S17 | E12 | P1 | Exact trip access |
| Share link | D | Open/Text/Copy | 17 | S16 | E12 | P1 | Separate from PDF email |
| Follow status/progress | SF | Read status/timeline/track log | 17 | S17 | E12 | P1 | Estimated, not live tracking |
| Follow full map | SF/FM | Open Full Map | 17 | S17 | E12 | P2 | Contextual view |
| Owner voyage post | SF | Text/photo/tags; Post Update | 17 | S17 | E12 | P2 | Owner signed in |
| Delete owner post | SF | Delete; confirm | 17 | — | E12 | P2 | No Edit found |
| Follower reactions | SF | Like/Love/Boat/Wave | 17 | S17 | E12 | P2 | Explain recipient experience |
| Follower comments | SF | Identify; Comment | 17 | S17 | E12 | P2 | Optional password challenge |
| Active Cruise overview | A | Read route/current leg | 18 | S18 | E01 | P1 | Operational access |
| Active map/full map | A | Open map | 18 | S18 | E16 | P1 | Last known GPS distinct |
| Active timeline selection | A | Expand/select leg | 18 | S18 | E10 | P1 | Does not start leg |
| Active pace | A | Move pace slider | 18 | S18 | E06 | P2 | Saves immediately |
| On Track | A | Start/resume/check in | 19–20 | S19 | E01,E09 | P1 | Can establish departure |
| Delayed | A | Report delayed status | 19–20 | S19 | E08 | P1 | Pause, not minute input |
| Changed Plan | A | Report changed status | 19 | S19 | E08 | P1 | Does not edit route |
| Secure Night | A | Confirm overnight status | 20 | S20 | E09 | P1 | Monitoring continues |
| Optional check-in note | A | Add note | 19 | S19 | E16 | P2 | Voyage stream |
| Check-in location | A | Allow/deny GPS | 19,27 | S19 | E16 | P1 | Status can succeed without it |
| Next Expected Check-In | A/M | Read deadline | 19 | S19–21 | E08 | P1 | Practical timing authority |
| Add Delay Time | A | Enter whole minutes | 20 | S19 | E08 | P1 | ETA adjustment |
| Clear Delay | A | Clear manual total | 20 | S19 | E08 | P1 | Not check-in |
| Daily Start Time | A | Save local time | 20 | S19 | E09 | P1 | Does not resume |
| Complete Current Leg | A | Arrived; confirm | 20 | S20 | E10 | P1 | Explicit completion |
| Start Next Leg | A | Start pending leg | 20 | S20 | E10 | P1 | Prior leg complete |
| Captain notes | A | Save private note | 21 | S22 | E11 | P2 | 1,200 characters |
| Publish captain note | A | Save & Post | 21 | S22 | E12 | P2 | Separate checkbox |
| Contact shortcuts | A | Call/Text/Email | 21 | S18 | E08 | P2 | Device handlers |
| Crew summary | A | Read people summary | 18,21 | S18 | E03 | P2 | Not editor |
| Active weather | A | Check Start/End conditions | 13,18 | S22 | E17 | P1 | Lookup only |
| Apply active weather | A | Apply Weather to Route | 13,18 | S22 | E17 | P1 | Saves factor |
| Monitor summary | M | Read health/state/clocks | 19 | S21 | E16 | P1 | Read-only |
| Monitor GPS/history | M | Inspect location/age/history | 19 | S21 | E16 | P2 | Not continuous tracking |
| Alert readiness/audit | M | Read summarized evidence | 19 | S21 | E16 | P2 | No technical tutorial |
| Close Float Plan | A | Confirm final closure | 22 | S23 | E13 | P1 | All legs complete |
| Cancel trip | D | Cancel active group | 22 | — | E14 | P1 | Not safe completion |
| Completed owner record | CT | Open email link; review | 23 | S23 | E13 | P1 | Read-only |
| Completed shared view | SF | View completed Follow | 17,23 | S23 | E13 | P1 | Limited final state |
| Weather location | WX | Home Port/ZIP/Coordinates; Update | 13 | S24 | E17 | P1 | Approximate ZIP |
| Conditions/risk/waves | WX | Read current briefing | 13 | S24 | E17 | P1 | Source/time |
| Weather alerts | WX | Expand alert details | 13 | S24 | E17 | P1 | Official instructions |
| Tides/forecast | WX | Today/Tomorrow; read forecast | 13 | S24 | E17 | P2 | Station context |
| Weather map/overlays | WX | Open map; choose layer | 13 | S24 | E17 | P2 | Available layers |
| Weather sources | WX | Inspect station/source details | 13 | S24 | E17 | P2 | Missing values |
| Fuel calculator inputs/results | FL | Enter scenario | 14 | S26 | E06 | P2 | Independent from saved data |
| Calculator breakdown/copy | FL | Expand; Copy Result JSON | 14 | S26 | E06 | P2 | No save |
| Calculator Reset | FL | Restore defaults | 14 | S26 | E06 | P2 | New page also resets |
| Profile | AC | Edit name/phone; Save/Refresh | 24 | S25 | — | P1 | Email read-only |
| Home Port | AC | Edit location/address | 24 | S25 | E17 | P1 | Weather/map default |
| Password change/reset handoff | AC/auth | Change or recover password | 24,27 | S25 | — | P1 | Separate processes |
| Access/credit status | AC | Review membership | 24 | S25 | E15 | P1 | Exact-trip limits |
| Billing portal | AC | Manage Billing | 24 | S25 | — | P2 | External options unverified |
| Promotional code | AC | Redeem Code | 24 | S25 | — | P2 | Eligibility errors |
| Help search/FAQ | H | Search; expand sections | 25,27 | — | — | P2 | Current code remains authority |
| Responsive navigation/forms | D/R/F/A | Use mobile layout | 25 | Selected phone views | E01 | P2 | Browser proof pending |
| Email expectations | Multiple | Recognize trigger/recipient/result | 16,19,22,24 | S15 | E12–13 | P1 | No receipt guarantee |
| Checkout fallback wizard | ALT | Encounter alternate return surface | 27 | Deferred | E15 | Hold | Material Basic difference |
| Weather favorite | WX | Visible star | — | No | — | Hold | No handler verified |
| Follow Privacy/Text Link | SF | Visible controls | — | No | — | Hold | Use working Dashboard share |
| Companion setup/device | Companion | Pair/disconnect | Owner appendix | Deferred | Deferred | Hold | Not member available |
| Companion current trip/status | Companion | View and check in | Owner appendix | Deferred | Deferred | Hold | Four launch statuses |
| Companion optional GPS | Companion | Capture/omit location | Owner appendix | Deferred | Deferred | Hold | Foreground only |
| Companion pending queue | Companion | Retry/discard | Owner appendix | Deferred | Deferred | Hold | One pending; uncertain timeout |
| Companion mock mode | Companion | View sample/confirm mock | Owner appendix | Deferred | — | Hold | No real trip updates |

## 25. Current Experience Ambiguities

These are current accuracy issues, not a legacy catalog or an implementation request.

| Issue | Evidence and consequence | Manual treatment / owner decision |
|---|---|---|
| **Vessel speed units conflict** | Vessel form labels KPH; planner labels knots. Legacy-column fallback passes values without conversion | Settle the intended units before publishing performance-entry instructions; do not claim conversion |
| **Checkout fallback opens another wizard** | Current Account return code can fall back to the standalone seven-step page | Primary manual remains six-step; explain the exceptional return only after supported behavior is confirmed |
| **Basic means different things on that fallback** | Primary Review Basic is PDF-only; standalone Basic can lead to operational one-day Basic | Do not combine them into one Basic procedure |
| **Completed-trip entry is email-based** | Completed page exists; no current Dashboard history link found | Teach verified email entry; do not invent history navigation |
| **Active Cruise final-time discrepancy** | Bottom Final Destination uses current-leg ETA; summary Final Arrival uses final-route projection | Use summary Final Arrival; do not equate the two timestamps |
| **Visible unwired controls** | Weather star; Follow Text Link; Follow Privacy alert without a verified editor | Omit functional instructions; use the working Dashboard share flow |
| **Onboarding wording** | Tour describes waypoints as optional while current setup path expects usable waypoint preparation | Teach the actual current route prerequisites |
| **Companion availability** | Owner confirmed not member available; Account pairing hidden | Resolved for scope: owner appendix only |
| **Companion release evidence differs from current source** | Readiness prose names one production host while current environment points elsewhere; source includes mock/development copy and existing modifications | No installation, production endpoint or released-build claims |

Key evidence:

- [vessel unit labels](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm:769) and [planner fallback values](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/routeBuilder.cfc:7240)
- [checkout return fallback](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/account.js:490)
- [Active Cruise final-time rendering](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/active-cruise.cfm:4130)
- [hidden Account Companion panel](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/account.cfm:229)

Legacy classification is deliberately brief:

- **Current/relevant:** Dashboard modal, current linked calculator, current navigation, current operational pages.
- **Obsolete/ignored:** old fuel page/nav copies, snapshots, samples, hidden template controls, backend-only UI helpers.
- **Ambiguous/currently reachable:** checkout fallback wizard and its Basic handoff.

## 26. Recommended next step for writing the manual

**Best approach:** Resolve the current accuracy blockers—especially speed units and checkout/Basic behavior—then write the manual from the chapter structure and coverage matrix above. Validate procedures against the intended deployed build before taking final screenshots.

**Safest Fix option for documentation:** Draft the confirmed primary web workflows first, leaving the disputed procedures and Companion out of published instructions. Mark the few affected passages as owner-review items. This avoids changing application behavior merely to finish documentation.

The writing phase should:

1. Use plain boating language and exact current button labels.
2. Explain purpose, prerequisites, steps, result, and common failure for each procedure.
3. Keep saved records, route planning, Float Plan sending and underway operation distinct.
4. Include the worked scenarios and screenshot callouts above.
5. Check every matrix row against a chapter.
6. Use canonical disposable data for later authorized browser capture and action validation.
7. Verify desktop/phone presentation, disabled reasons, success states and current navigation.
8. Separate source-confirmed behavior from runtime-tested behavior in the completion report.
9. Keep Companion material owner-only until access and distribution are available.
10. Produce the final user manual only in the next approved writing phase.

No public API, schema, application behavior, dependency, or configuration changes are proposed.

### Inspection record

The following sources were read or searched. Large services were inspected through focused workflow ranges; this is not a claim that every line of every file was reviewed.

**FPW pages and navigation**

[Dashboard](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm), [Account](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/account.cfm), [Active Cruise](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/active-cruise.cfm), [Monitoring](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/monitoring.cfm), [Completed Trip](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/completed-trip.cfm), [Weather](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/weather.cfm), [standalone Wizard](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/floatplan-wizard.cfm), [Follow](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/follow.cfm), [Help](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/help.cfm), [Contact](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/contact.cfm), [Pricing](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/pricing.cfm), [Start Trial](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/start-trial.cfm), [older fuel page](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/fuel-calculator.cfm), [linked calculator](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/boat-fuel-calculator/boat-fuel-calculator.cfm), [top navigation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/top_nav.cfm), [older navigation—bounded inbound search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/top_nav_orig.cfm), [footer](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/footer.cfm), [authentication guard](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/require_auth.cfm), [route modal](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/modals/route_generator_modal.cfm), [URL rewrites—focused search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config).

**Great Loop pages**

[Locks](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-locks.cfm), [Lock detail](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-lock.cfm), [Anchorages](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-anchorages.cfm), [Anchorage detail](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-anchorage.cfm), [Ports](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-ports.cfm), [Port detail](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-port.cfm), [Bridges](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop/bridges.cfm), [Bridge detail](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop-bridge.cfm).

**FPW JavaScript and responsive styles**

[Dashboard controller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard.js), [vessels](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/vessels.js), [operators](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/operators.js), [passengers](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/passengers.js), [contacts](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/contacts.js), [waypoints](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/waypoints.js), [onboarding](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/onboarding.js), [route builder](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/routebuilder.js), [route tour](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/route-generator-tour.js), [Float Plans module](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/floatplans.js), [Basic form](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/basic-floatplan.js), [Wizard](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/floatplanWizard.js), [Follow](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/follow/follow.js), [Account](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/account.js), [Weather](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/weather-page.js), [Help](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/help.js), [Help tour](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/help-tour.js), [Join](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/join.js), [Start Trial](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/start-trial.js), [Forgot Password](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/forgot-password.js), [Reset Password](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/reset-password.js), [auth modal—search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/auth-modal.js), [auth utilities—search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/auth-utils.js).

[Locks JS](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/great-loop-locks.js), [Anchorages JS](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/great-loop-anchorages.js), [Bridges JS](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/great-loop-bridges.js), [Ports JS](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/ports-library.js), [waypoint map](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/maps/leaflet-noaa-waypoint-map.js), [weather overlays](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/maps/fpw-weather-overlays.js), [Dashboard CSS—search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/css/dashboard-console.css), [navigation CSS—search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/css/top-nav.css), [Account CSS—search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/css/account.css).

**FPW workflow services**

[Vessel](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/vessel.cfc), [Operator](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/operator.cfc), [Passenger](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/passenger.cfc), [Contact](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/contact.cfc), [Waypoint](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/waypoint.cfc), [Profile](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/profile.cfc), [Home Port](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/homeport.cfc), [Route Builder](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/routeBuilder.cfc), [Route Timeline](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/RouteTimelineService.cfc), [Float Plan](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/floatplan.cfc), [Email](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/email.cfc), [Basic Review Send](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/BasicReviewSendService.cfc), [Voyage](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/voyage.cfc), [Member Access Gate](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/MemberAccessGateService.cfc), [Member Entitlement](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/MemberEntitlementService.cfc), [Premium Trip Access](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PremiumTripAccessService.cfc), [Premium Send Credit](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PremiumSendCreditService.cfc).

[Active Cruise view model](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/ActiveCruiseViewModelService.cfc), [Monitoring view model](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/MonitoringConsoleViewModelService.cfc), [Completed Trip view model](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/CompletedTripViewModelService.cfc), [Trip Activity Writer](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/TripActivityWriterService.cfc), [Trip Progress Projection](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/TripProgressProjectionService.cfc), [Overnight Timing](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/OvernightTimingService.cfc), [Monitor](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/monitor.cfc), [Departure Reminders](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/DepartureReminderService.cfc), [Overdue Alerts](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/OverdueAlertService.cfc), [Safe Arrival](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/SafeArrivalNotificationService.cfc), [Weather Target Resolver](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/WeatherTargetResolver.cfc), [Weather view model](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/WeatherPageViewModelService.cfc).

[Billing](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/billing.cfc), [Stripe Checkout](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/StripeCheckoutService.cfc), [Stripe webhook—search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/stripeWebhook.cfc), [Stripe entitlement—search](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/StripeEntitlementService.cfc), [Join](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/join.cfc), [Password reset](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/password_reset.cfc), [Ports](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/ports.cfc), [Locks](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/greatLoopLocks.cfc), [Bridges service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/GreatLoopBridgesService.cfc), [Companion auth endpoint](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/companionAuth.cfc), [Companion Auth Service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/CompanionAuthService.cfc), [Companion Check-in Service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/CompanionCheckinService.cfc), [Companion view model](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/CompanionViewModelService.cfc).

**FPW test/document sources consulted—not executed**

[Vessel CRUD](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/vessel-crud-expanded-fields.test.mjs), [member profile name](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/member-profile-name.spec.js), [Dashboard navigation race](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/dashboard-navigation-race.spec.js), [route closure](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/RouteInstanceClosureContractSpec.cfc), [scheduled/actual departure](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/ScheduledActualDepartureContractSpec.cfc), [safe arrival](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/SafeArrivalNotificationServiceSpec.cfc), [completed view model](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/CompletedTripViewModelServiceSpec.cfc), [departure reminder](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/DepartureReminderContractSpec.cfc), [final arrival projection](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/FinalArrivalProjectionContractSpec.cfc), [Premium access lifecycle](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/specs/PremiumTripAccessLifecycleSpec.cfc), [unified authentication documentation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/docs/unified-authentication-implementation.md).

**Companion sources**

[README](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/README.md), [readiness documentation](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/docs/production-native-readiness.md), [package](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/package.json), [Capacitor configuration](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/capacitor.config.ts), [routing](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/app-routing.module.ts), [module](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/app.module.ts), [app template](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/app.component.html), [models](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/models/companion.model.ts), [development environment](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/environments/environment.ts), [production environment](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/environments/environment.prod.ts).

[Loading controller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/loading/loading.page.ts), [Loading template](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/loading/loading.page.html), [Active Trip controller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/active-trip/active-trip.page.ts), [Active Trip template](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/active-trip/active-trip.page.html), [Active Trip styles](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/active-trip/active-trip.page.scss), [Check-in controller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/check-in-confirm/check-in-confirm.page.ts), [Check-in template](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/check-in-confirm/check-in-confirm.page.html), [Check-in styles](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/check-in-confirm/check-in-confirm.page.scss), [No Active Trip controller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/no-active-trip/no-active-trip.page.ts), [No Active Trip template](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/no-active-trip/no-active-trip.page.html), [No Active Trip styles](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/no-active-trip/no-active-trip.page.scss), [Device controller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/settings-device/settings-device.page.ts), [Device template](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/settings-device/settings-device.page.html), [Queue controller](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/offline-queue/offline-queue.page.ts), [Queue template](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/pages/offline-queue/offline-queue.page.html).

[Location service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-location.service.ts), [API service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-api.service.ts), [transport](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-api-transport.service.ts), [credentials](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-credential.service.ts), [storage](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-storage.service.ts), [queue service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/offline-queue.service.ts), [action service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-action.service.ts), [mock service](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/mock-companion.service.ts), [device placeholder](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/device-placeholder.service.ts), [iOS permissions](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/ios/App/App/Info.plist), [Android permissions](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/android/app/src/main/AndroidManifest.xml).

Companion service tests consulted, not executed: [location](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-location.service.spec.ts), [queue](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/offline-queue.service.spec.ts), [API](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-api.service.spec.ts), [actions](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-action.service.spec.ts), [storage](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-storage.service.spec.ts), [credentials](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw-companion/src/app/services/companion-credential.service.spec.ts).

Discovery stops here. Application behavior and existing files remain unchanged.
