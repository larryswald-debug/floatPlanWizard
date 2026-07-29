<cfprocessingdirective pageencoding="utf-8">
<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
fpwFaqBasePath = "";
fpwFaqScriptName = structKeyExists(cgi, "script_name") ? trim(toString(cgi.script_name)) : "";

if (structKeyExists(request, "fpwBase")) {
  fpwFaqBasePath = trim(toString(request.fpwBase));
}

if (!len(fpwFaqBasePath) AND len(fpwFaqScriptName)) {
  fpwFaqBasePath = replace(fpwFaqScriptName, "\", "/", "all");
  fpwFaqBasePath = reReplaceNoCase(fpwFaqBasePath, "/faq/index\.cfm$", "");
  fpwFaqBasePath = reReplaceNoCase(fpwFaqBasePath, "/faq/?$", "");

  if (fpwFaqBasePath EQ fpwFaqScriptName) {
    fpwFaqBasePath = getDirectoryFromPath(fpwFaqScriptName);
    fpwFaqBasePath = reReplace(fpwFaqBasePath, "/faq/?$", "");
  }
}

fpwFaqBasePath = reReplace(fpwFaqBasePath, "/$", "");
if (fpwFaqBasePath EQ "/") {
  fpwFaqBasePath = "";
}
if (len(fpwFaqBasePath) AND left(fpwFaqBasePath, 1) NEQ "/") {
  fpwFaqBasePath = "/" & fpwFaqBasePath;
}

request.fpwBase = fpwFaqBasePath;
request.fpwTopNavActive = "";
fpwFaqCreateUrl = fpwFaqBasePath & "/app/join.cfm";
fpwFaqRouteBuilderUrl = fpwFaqBasePath & "/app/join.cfm";
fpwFaqFuelUrl = fpwFaqBasePath & "/boat-fuel-calculator/";

fpwFaqLinkLabels = {
  "/app/join.cfm": "Create Account",
  "/app/login.cfm": "Log In",
  "/app/pricing.cfm": "Membership Plans",
  "/app/dashboard.cfm": "Dashboard",
  "/boat-fuel-calculator/": "Boat Fuel Calculator",
  "/great-loop/locks/": "Great Loop Lock Library",
  "/great-loop/bridges/": "Great Loop Bridge Library",
  "/why-use-a-float-plan/": "Why Use a Float Plan",
  "/app/contact.cfm": "Contact Support"
};

fpwFaqSections = [
  {
    "id": "float-plan-basics",
    "title": "Float Plan Basics",
    "items": [
    {
      "id": "what-is-floatplanwizard",
      "question": "What is FloatPlanWizard?",
      "answer": [
        "FloatPlanWizard is an online boating trip-planning tool that helps captains create, organize, update, and share float plans. It gives you a place to record where you are going, when you expect to leave and return, who is on board, vessel details, route notes, emergency contacts, and other trip information.",
        "Instead of relying on scattered texts, paper notes, or memory, FloatPlanWizard helps keep the important details in one organized plan."
      ],
      "links": [
        "/app/join.cfm",
        "/why-use-a-float-plan/"
      ],
      "priority": "High"
    },
    {
      "id": "what-is-a-float-plan",
      "question": "What is a float plan?",
      "answer": [
        "A float plan is a written record of your boating trip. It usually includes your vessel information, passengers, departure point, destination, expected return time, route notes, emergency contacts, and instructions for what someone should do if you are overdue.",
        "FloatPlanWizard helps you create a more organized digital float plan that can be updated and shared with trusted family and friends."
      ],
      "links": [
        "/why-use-a-float-plan/"
      ],
      "priority": "High"
    },
    {
      "id": "why-should-i-create-a-float-plan",
      "question": "Why should I create a float plan?",
      "answer": [
        "A float plan gives someone ashore a clear picture of your intended trip. If you are delayed, your plans change, or someone becomes concerned, your trusted contacts have a better starting point than “they went boating somewhere.”",
        "Even for routine trips, a float plan can reduce confusion by documenting your route, timing, passengers, vessel details, and contact instructions before you leave."
      ],
      "links": [
        "/why-use-a-float-plan/",
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "is-floatplanwizard-only-for-long-trips",
      "question": "Is FloatPlanWizard only for long trips?",
      "answer": [
        "No. FloatPlanWizard can be useful for local day trips, fishing trips, fuel runs, marina hops, weekend cruising, Great Loop planning, and longer multi-stop routes.",
        "A short trip can still benefit from having someone know where you are going, when you expect to return, and how to view the information you chose to share."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "can-i-use-floatplanwizard-for-local-trips",
      "question": "Can I use FloatPlanWizard for local trips?",
      "answer": [
        "Yes. FloatPlanWizard works well for local trips because it helps you quickly organize the basic details: where you are leaving from, where you plan to go, who is with you, when you expect to return, and who should know about the trip.",
        "Local trips are often the ones boaters take casually, which is exactly why having a simple plan can be helpful."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "is-floatplanwizard-a-replacement-for-an-official-report-or-emergency-communication",
      "question": "Is FloatPlanWizard a replacement for an official report or emergency communication?",
      "answer": [
        "No. FloatPlanWizard is a trip-planning and float-plan sharing tool. It does not replace official reporting, VHF radio, emergency beacons, AIS, DSC, marine navigation tools, weather checks, or contacting emergency services.",
        "If there is an emergency, use the appropriate emergency communication method immediately."
      ],
      "links": [],
      "priority": "High"
    }
    ]
  },
  {
    "id": "route-builder",
    "title": "Route Builder",
    "items": [
    {
      "id": "what-is-the-floatplanwizard-route-builder",
      "question": "What is the FloatPlanWizard Route Builder?",
      "answer": [
        "The Route Builder helps you create a more complete boating trip plan by organizing your route, stops, timing, notes, and supporting float-plan details in one workflow.",
        "Instead of only writing a destination and return time, you can build a route that better reflects how boat trips actually work: departure point, destination, possible stops, timing, fuel considerations, route notes, and information your family and friends may need while following the trip."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "why-is-route-builder-one-of-the-biggest-benefits-of-floatplanwizard",
      "question": "Why is Route Builder one of the biggest benefits of FloatPlanWizard?",
      "answer": [
        "Route Builder turns a basic float plan into a more useful trip-planning workflow. It helps you think through the trip before you leave: where you are going, how you plan to get there, what stops or waypoints matter, how timing should work, and what information should be shared with family and friends.",
        "That makes the plan more useful than a quick text message or a paper form that may not include enough detail."
      ],
      "links": [
        "/app/join.cfm",
        "/why-use-a-float-plan/"
      ],
      "priority": "High"
    },
    {
      "id": "how-is-route-builder-different-from-a-normal-float-plan-form",
      "question": "How is Route Builder different from a normal float plan form?",
      "answer": [
        "A normal float plan form usually captures basic trip information. Route Builder goes further by helping you organize the trip around the route itself.",
        "That means you can think through route details, timing, stops, notes, and related planning information while building the plan, instead of filling out disconnected fields with no trip structure."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "can-i-build-a-route-with-multiple-stops",
      "question": "Can I build a route with multiple stops?",
      "answer": [
        "Yes. Route Builder is designed to help organize trips with more than one stop or route detail. That can be useful for marina-to-marina cruising, fishing plans, fuel stops, overnight stops, Great Loop segments, or any trip where the route matters."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "can-i-use-route-builder-for-a-simple-trip",
      "question": "Can I use Route Builder for a simple trip?",
      "answer": [
        "Yes. Route Builder does not have to be complicated. For a simple trip, you can use it to organize the basics: departure, destination, timing, notes, and who should be able to follow the plan.",
        "The benefit is that even a simple trip becomes easier to share and update."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "can-i-update-a-route-after-i-create-it",
      "question": "Can I update a route after I create it?",
      "answer": [
        "Yes. FloatPlanWizard is designed so your trip information can be updated as plans change. If your route, timing, notes, or stop details change, update the plan so your shared information stays more current."
      ],
      "links": [
        "/app/dashboard.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "is-route-builder-a-navigation-system",
      "question": "Is Route Builder a navigation system?",
      "answer": [
        "No. Route Builder is a planning and organization tool. It is not a replacement for marine navigation software, official charts, current notices to mariners, waterway guides, depth soundings, weather information, local knowledge, or safe seamanship.",
        "Always verify your route with current navigation sources before and during your trip."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "why-should-i-use-route-builder-instead-of-texting-my-trip-plan",
      "question": "Why should I use Route Builder instead of texting my trip plan?",
      "answer": [
        "A text message is easy to lose, forget, or misunderstand. Route Builder helps organize the trip into a more complete plan with details that can be updated and shared from one place.",
        "Your family and friends can use the secure Follow link to view the trip information you choose to share instead of searching through old messages."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "how-does-route-builder-connect-to-the-secure-follow-page",
      "question": "How does Route Builder connect to the secure Trip status page?",
      "answer": [
        "Route Builder helps organize the trip details. The secure Trip status page helps you share selected trip information with family and friends.",
        "That connection is important: you build the plan in FloatPlanWizard, then share a secure Follow link so trusted people can view the current trip information without needing their own account."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "how-does-route-builder-connect-to-active-cruise",
      "question": "How does Route Builder connect to Active Cruise?",
      "answer": [
        "Route Builder helps set up the plan before the trip. Active Cruise helps manage the trip while it is underway.",
        "Together, they support the full planning flow: create the route, organize the float plan, share the secure Follow link, then update status, delays, or check-ins while the trip is active."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    }
    ]
  },
  {
    "id": "route-builder-forms",
    "title": "Route Builder Forms",
    "items": [
    {
      "id": "what-information-does-route-builder-help-organize",
      "question": "What information does Route Builder help organize?",
      "answer": [
        "Route Builder can help organize the information that makes a float plan useful, including departure details, destination details, route notes, timing, passenger information, vessel details, emergency contacts, fuel planning, and information for family and friends following the trip.",
        "The goal is not just to draw a route. The goal is to create a useful boating plan."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "why-does-route-builder-ask-for-trip-timing",
      "question": "Why does Route Builder ask for trip timing?",
      "answer": [
        "Trip timing helps your family and friends understand when you expect to leave, when you expect to return, and when a delay may matter.",
        "Timing is one of the most important parts of a float plan because it gives your trusted contacts a frame of reference."
      ],
      "links": [
        "/why-use-a-float-plan/"
      ],
      "priority": "High"
    },
    {
      "id": "why-does-floatplanwizard-collect-vessel-information",
      "question": "Why does FloatPlanWizard collect vessel information?",
      "answer": [
        "Vessel information helps identify the boat connected to the trip. Useful vessel details may include the boat name, type, size, registration or documentation details, and other identifying information.",
        "Those details can help your trusted contacts understand which boat the plan refers to, especially if you own more than one vessel or boat with different groups of people."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "why-does-a-float-plan-include-passenger-information",
      "question": "Why does a float plan include passenger information?",
      "answer": [
        "Passenger information helps document who is expected to be on board. If someone ashore needs to understand the trip, knowing who was included in the plan can reduce confusion.",
        "Only include information that is useful and appropriate for your trusted contacts."
      ],
      "links": [],
      "priority": "Medium"
    },
    {
      "id": "why-does-route-builder-include-contacts",
      "question": "Why does Route Builder include contacts?",
      "answer": [
        "Contacts are a key part of a useful float plan. They help define who should receive or know about the trip information and who may need to be contacted if plans change.",
        "FloatPlanWizard is designed around sharing selected trip details with trusted family and friends."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "can-i-add-notes-to-my-route-or-trip-plan",
      "question": "Can I add notes to my route or trip plan?",
      "answer": [
        "Yes. Trip notes are useful for details that do not fit neatly into a single field. You may want to include marina notes, bridge or lock considerations, fuel-stop reminders, local hazards, alternate plans, or instructions for family and friends."
      ],
      "links": [
        "/great-loop/locks/",
        "/great-loop/bridges/"
      ],
      "priority": "Medium"
    },
    {
      "id": "can-route-builder-help-with-fuel-planning",
      "question": "Can Route Builder help with fuel planning?",
      "answer": [
        "Route Builder can support better fuel planning by helping you think through distance, stops, and timing. FloatPlanWizard also includes a Boat Fuel Calculator that can help estimate fuel needs based on trip-planning inputs.",
        "Fuel estimates are planning aids only. Actual fuel use can vary based on speed, load, sea state, current, wind, engine condition, and how the boat is operated."
      ],
      "links": [
        "/boat-fuel-calculator/"
      ],
      "priority": "High"
    },
    {
      "id": "can-i-use-route-builder-for-great-loop-segments",
      "question": "Can I use Route Builder for Great Loop segments?",
      "answer": [
        "Yes. Route Builder can be useful for planning Great Loop segments because those trips often involve multiple stops, timing considerations, bridge clearances, locks, fuel planning, and notes.",
        "FloatPlanWizard also includes Great Loop lock and bridge resources that can help with research before you finalize a route."
      ],
      "links": [
        "/great-loop/locks/",
        "/great-loop/bridges/"
      ],
      "priority": "High"
    }
    ]
  },
  {
    "id": "secure-follow-page",
    "title": "Secure Follow Page",
    "items": [
    {
      "id": "what-is-the-follow-page",
      "question": "What is the Trip status page?",
      "answer": [
        "The Trip status page is a shared trip page for family and friends. It lets the people you choose view the float plan information you share with them through a secure Follow link.",
        "It gives your trusted contacts one place to check trip details and updates instead of relying on scattered texts, calls, or screenshots."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "do-my-family-and-friends-need-an-account",
      "question": "Do my family and friends need an account?",
      "answer": [
        "No. Family and friends do not need a FloatPlanWizard account to view the trip information you share with them.",
        "Only the captain or trip planner needs an account to create, manage, update, and share the float plan."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "who-can-see-my-follow-page",
      "question": "Who can see my Trip status page?",
      "answer": [
        "Only people who have the secure Follow link can view the shared page. You control who receives that link.",
        "Do not post private Follow links publicly unless you are comfortable with the trip information being seen by others."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "can-i-share-the-secure-follow-link-by-text-or-email",
      "question": "Can I share the secure Follow link by text or email?",
      "answer": [
        "Yes. You can share the secure Follow link with trusted family and friends by text, email, or another communication method.",
        "For safety, make sure they understand what the plan means, when you expect to return, and what you want them to do if you are overdue."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "can-my-family-and-friends-track-my-boat-automatically",
      "question": "Can my family and friends track my boat automatically?",
      "answer": [
        "FloatPlanWizard is not a live GPS tracking replacement unless a specific tracking feature is clearly enabled. The Trip status page is primarily a shared trip-information page where family and friends can view the plan and updates you provide.",
        "Use proper marine navigation, communication, and safety equipment while underway."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "what-should-i-tell-my-follow-contacts-before-i-leave",
      "question": "What should I tell my Follow contacts before I leave?",
      "answer": [
        "Tell them that you are sharing a boating trip plan, when you expect to leave, when you expect to return, how to use the secure Follow link, and what you want them to do if you are overdue or if the plan stops updating.",
        "A float plan works best when your contacts understand their role before the trip starts."
      ],
      "links": [
        "/why-use-a-float-plan/"
      ],
      "priority": "Medium"
    }
    ]
  },
  {
    "id": "active-cruise",
    "title": "Active Cruise",
    "items": [
    {
      "id": "what-is-active-cruise",
      "question": "What is Active Cruise?",
      "answer": [
        "Active Cruise is the trip-in-progress view for managing an active float plan. It helps the captain keep track of trip status, timing, check-ins, delays, and updates while the trip is underway."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "what-is-a-check-in",
      "question": "What is a check-in?",
      "answer": [
        "A check-in is a status update from the captain. It helps confirm that the trip is still progressing and gives family and friends more confidence that the shared plan is current."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "what-happens-if-i-am-delayed",
      "question": "What happens if I am delayed?",
      "answer": [
        "If you are delayed, update your float plan or Active Cruise status as soon as practical. You can add delay information so your expected timing stays more accurate.",
        "Your family and friends should always rely on the latest shared trip information and any direct messages you send them."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "can-i-mark-myself-secure-for-the-night",
      "question": "Can I mark myself secure for the night?",
      "answer": [
        "If your trip workflow supports it, you can mark the trip as secure for the night or update your status when you are safely stopped.",
        "This helps separate normal overnight stops from unexpected overdue situations."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "does-floatplanwizard-automatically-call-for-help",
      "question": "Does FloatPlanWizard automatically call for help?",
      "answer": [
        "No. FloatPlanWizard is not an emergency dispatch system. It helps organize and share trip information, but it does not replace calling 911, the Coast Guard, local marine patrol, or emergency services.",
        "If you are in distress, use the appropriate emergency communication method immediately."
      ],
      "links": [],
      "priority": "High"
    }
    ]
  },
  {
    "id": "fuel-planning",
    "title": "Fuel Planning",
    "items": [
    {
      "id": "what-is-the-boat-fuel-calculator",
      "question": "What is the Boat Fuel Calculator?",
      "answer": [
        "The Boat Fuel Calculator helps estimate fuel needs based on trip distance, speed, fuel burn, reserve, and other planning values.",
        "It is useful for quick pre-trip estimates and can support better route planning."
      ],
      "links": [
        "/boat-fuel-calculator/"
      ],
      "priority": "High"
    },
    {
      "id": "is-the-fuel-calculator-exact",
      "question": "Is the fuel calculator exact?",
      "answer": [
        "No. Fuel use can vary based on speed, load, sea state, wind, current, hull condition, engine condition, and how the boat is operated.",
        "Use the calculator as a planning estimate and always carry an appropriate fuel reserve."
      ],
      "links": [
        "/boat-fuel-calculator/"
      ],
      "priority": "High"
    },
    {
      "id": "how-does-fuel-planning-connect-to-route-builder",
      "question": "How does fuel planning connect to Route Builder?",
      "answer": [
        "Route Builder helps organize where you are going and how the trip is structured. Fuel planning helps you think through whether the trip is practical based on distance, expected speed, fuel burn, and reserve.",
        "Together, they help turn a rough boating idea into a more thoughtful trip plan."
      ],
      "links": [
        "/boat-fuel-calculator/",
        "/app/join.cfm"
      ],
      "priority": "High"
    }
    ]
  },
  {
    "id": "great-loop-tools",
    "title": "Great Loop Tools",
    "items": [
    {
      "id": "can-i-use-floatplanwizard-for-great-loop-planning",
      "question": "Can I use FloatPlanWizard for Great Loop planning?",
      "answer": [
        "Yes. FloatPlanWizard can help organize Great Loop trip details, route segments, stops, notes, timing, locks, bridges, and information you may want to share with family and friends.",
        "It is a planning aid and should be used with official charts, current notices, waterway guides, weather information, and local navigation knowledge."
      ],
      "links": [
        "/great-loop/locks/",
        "/great-loop/bridges/"
      ],
      "priority": "High"
    },
    {
      "id": "what-is-the-great-loop-lock-library",
      "question": "What is the Great Loop Lock Library?",
      "answer": [
        "The Great Loop Lock Library helps boaters research locks commonly associated with the Great Loop route. It may include lock names, waterways, locations, notes, and other planning information.",
        "Always verify lock status, schedules, closures, restrictions, and contact information with official sources before relying on them."
      ],
      "links": [
        "/great-loop/locks/"
      ],
      "priority": "High"
    },
    {
      "id": "what-is-the-great-loop-bridge-library",
      "question": "What is the Great Loop Bridge Library?",
      "answer": [
        "The Great Loop Bridge Library helps boaters research bridge information relevant to Great Loop cruising, including fixed bridges, drawbridges, railroad bridges, clearance notes, contact information where available, and navigation-related notes.",
        "Always verify bridge openings, clearances, restrictions, and schedules with official sources before relying on them."
      ],
      "links": [
        "/great-loop/bridges/"
      ],
      "priority": "High"
    },
    {
      "id": "are-lock-and-bridge-details-guaranteed-to-be-current",
      "question": "Are lock and bridge details guaranteed to be current?",
      "answer": [
        "No. Lock, bridge, clearance, schedule, VHF, and contact information can change.",
        "Use FloatPlanWizard’s Great Loop tools for planning and research, then confirm critical details with official sources before departure and while underway."
      ],
      "links": [
        "/great-loop/locks/",
        "/great-loop/bridges/"
      ],
      "priority": "High"
    }
    ]
  },
  {
    "id": "membership",
    "title": "Membership",
    "items": [
    {
      "id": "do-i-need-a-membership-to-use-floatplanwizard",
      "question": "Do I need a membership to use FloatPlanWizard?",
      "answer": [
        "You need a FloatPlanWizard account to create, manage, and share float plans. Current access options, trial details, and membership pricing are shown on the pricing or signup page.",
        "Because offers can change, always use the current pricing page as the source of truth."
      ],
      "links": [
        "/app/pricing.cfm",
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "can-i-try-floatplanwizard-before-paying",
      "question": "Can I try FloatPlanWizard before paying?",
      "answer": [
        "Use the current signup and pricing pages for the latest trial, free-access, or membership details. If a trial or free-access period is available, you can use that to explore FloatPlanWizard before choosing a paid plan."
      ],
      "links": [
        "/app/pricing.cfm",
        "/app/join.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "is-there-a-long-term-contract",
      "question": "Is there a long-term contract?",
      "answer": [
        "No long-term contract is required for standard monthly access. Review the current pricing and checkout details before subscribing."
      ],
      "links": [
        "/app/pricing.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "can-i-cancel",
      "question": "Can I cancel?",
      "answer": [
        "Yes. If you are on a paid subscription, you can cancel according to the terms shown during signup or checkout. Your billing and subscription details are managed through your account and billing portal."
      ],
      "links": [
        "/app/pricing.cfm"
      ],
      "priority": "High"
    }
    ]
  },
  {
    "id": "account-management",
    "title": "Account Management",
    "items": [
    {
      "id": "how-do-i-create-an-account",
      "question": "How do I create an account?",
      "answer": [
        "Use the signup page to create your FloatPlanWizard account. Once your account is created, you can log in, create float plans, manage trip details, and share secure Follow links with family and friends."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "how-do-i-log-in",
      "question": "How do I log in?",
      "answer": [
        "Use the login page with the email address and password connected to your account."
      ],
      "links": [
        "/app/login.cfm"
      ],
      "priority": "Low"
    },
    {
      "id": "what-if-i-forgot-my-password",
      "question": "What if I forgot my password?",
      "answer": [
        "Use the password reset option on the login page. Follow the instructions sent to your email address to create a new password."
      ],
      "links": [
        "/app/login.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "where-do-i-manage-my-trips",
      "question": "Where do I manage my trips?",
      "answer": [
        "After logging in, use your dashboard to view and manage your float plans and trip activity."
      ],
      "links": [
        "/app/dashboard.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "can-i-update-my-account-information",
      "question": "Can I update my account information?",
      "answer": [
        "Account information should be managed from your account area after logging in. Keep your email address and profile details current so account messages and trip-related information reach the right place."
      ],
      "links": [
        "/app/dashboard.cfm"
      ],
      "priority": "Low"
    }
    ]
  },
  {
    "id": "billing-and-stripe",
    "title": "Billing & Stripe",
    "items": [
    {
      "id": "who-handles-floatplanwizard-billing",
      "question": "Who handles FloatPlanWizard billing?",
      "answer": [
        "FloatPlanWizard uses Stripe for checkout, billing, and payment processing. Stripe is a widely used payment platform that handles online payment flows for businesses."
      ],
      "links": [
        "/app/pricing.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "does-floatplanwizard-store-my-full-credit-card-number",
      "question": "Does FloatPlanWizard store my full credit card number?",
      "answer": [
        "No. FloatPlanWizard does not directly store your full credit card number on its own servers. Card entry, payment method handling, subscriptions, and billing updates are handled through Stripe’s secure payment systems."
      ],
      "links": [
        "/app/pricing.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "why-does-checkout-sometimes-show-stripe-branding-or-a-stripe-hosted-billing-page",
      "question": "Why does checkout sometimes show Stripe branding or a Stripe-hosted billing page?",
      "answer": [
        "Stripe may be used for checkout, payment method updates, subscription management, and billing portal features. Seeing Stripe during billing or payment management is expected when Stripe is handling that part of the process."
      ],
      "links": [
        "/app/pricing.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "can-i-update-or-remove-my-payment-method",
      "question": "Can I update or remove my payment method?",
      "answer": [
        "Payment method updates are handled through the billing tools available in your account. When Stripe is used for billing, payment method changes may be managed through Stripe’s secure billing portal or checkout flow."
      ],
      "links": [
        "/app/pricing.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "why-does-floatplanwizard-use-stripe-instead-of-storing-cards-directly",
      "question": "Why does FloatPlanWizard use Stripe instead of storing cards directly?",
      "answer": [
        "Using Stripe lets FloatPlanWizard rely on payment infrastructure built for secure checkout, subscriptions, billing management, and payment method handling.",
        "This helps avoid storing full card numbers directly on FloatPlanWizard servers."
      ],
      "links": [
        "/app/pricing.cfm"
      ],
      "priority": "High"
    }
    ]
  },
  {
    "id": "trustedsite-badge",
    "title": "TrustedSite Badge",
    "items": [
    {
      "id": "what-does-the-trustedsite-badge-mean",
      "question": "What does the TrustedSite badge mean?",
      "answer": [
        "The TrustedSite badge is a trustmark that helps visitors verify information about a site’s identity and security. On FloatPlanWizard, it is intended to give visitors an additional trust signal before creating an account or entering billing information."
      ],
      "links": [
        "/app/join.cfm",
        "/app/pricing.cfm"
      ],
      "priority": "High"
    },
    {
      "id": "can-i-click-the-trustedsite-badge",
      "question": "Can I click the TrustedSite badge?",
      "answer": [
        "Yes. The TrustedSite badge is designed to be clickable. When available, visitors can click it to view verification details through TrustedSite."
      ],
      "links": [],
      "priority": "Medium"
    },
    {
      "id": "does-the-trustedsite-badge-guarantee-boating-safety",
      "question": "Does the TrustedSite badge guarantee boating safety?",
      "answer": [
        "No. The TrustedSite badge relates to website trust and verification. It does not guarantee boating safety, emergency response, route accuracy, weather accuracy, or navigation safety.",
        "FloatPlanWizard is a planning and sharing tool. Safe boating remains the captain’s responsibility."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "why-does-floatplanwizard-use-a-trustedsite-badge",
      "question": "Why does FloatPlanWizard use a TrustedSite badge?",
      "answer": [
        "Float plans can include sensitive trip information, vessel details, timing, and contact information. FloatPlanWizard uses trust signals such as the TrustedSite badge to help visitors feel more confident that they are using the real site and can review available verification details."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "High"
    }
    ]
  },
  {
    "id": "privacy-and-security",
    "title": "Privacy & Security",
    "items": [
    {
      "id": "is-my-float-plan-public",
      "question": "Is my float plan public?",
      "answer": [
        "Your float plan is not intended to be public by default. You choose what to share and who receives the secure Follow link.",
        "Be careful when sharing any link that contains trip information, passenger information, vessel details, or timing."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "what-information-should-i-avoid-sharing",
      "question": "What information should I avoid sharing?",
      "answer": [
        "Avoid sharing unnecessary sensitive personal information. Only include details that are useful for trip planning, safety, and trusted family and friends.",
        "For public or casual sharing, avoid posting private trip links, full passenger details, home addresses, or security-sensitive vessel information."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "can-someone-access-my-follow-page-if-i-send-them-the-link",
      "question": "Can someone access my Trip status page if I send them the link?",
      "answer": [
        "Yes. A secure Follow link is meant to give access to the people you share it with. Treat it like a private trip link and send it only to trusted family and friends."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "why-does-trust-matter-for-a-float-plan-app",
      "question": "Why does trust matter for a float plan app?",
      "answer": [
        "A float plan can include trip details, passenger information, vessel information, timing, and emergency contacts. Trust matters because boaters need to feel confident about where they enter and share that information."
      ],
      "links": [
        "/app/join.cfm"
      ],
      "priority": "Medium"
    }
    ]
  },
  {
    "id": "safety",
    "title": "Safety",
    "items": [
    {
      "id": "does-floatplanwizard-guarantee-my-safety",
      "question": "Does FloatPlanWizard guarantee my safety?",
      "answer": [
        "No. FloatPlanWizard is a planning and sharing tool. It can help organize important trip information, but boating safety remains the captain’s responsibility.",
        "Always use current charts, proper safety equipment, weather forecasts, marine communication tools, and sound judgment. In an emergency, contact the appropriate emergency service immediately."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "should-i-still-tell-someone-where-i-am-going",
      "question": "Should I still tell someone where I am going?",
      "answer": [
        "Yes. FloatPlanWizard is designed to make that easier. Before leaving, make sure a trusted person knows where you are going, when you expect to return, how to view your plan, and what to do if you are overdue."
      ],
      "links": [
        "/why-use-a-float-plan/"
      ],
      "priority": "High"
    },
    {
      "id": "does-floatplanwizard-replace-weather-tools",
      "question": "Does FloatPlanWizard replace weather tools?",
      "answer": [
        "No. FloatPlanWizard does not replace official marine weather forecasts, radar, local conditions, tide/current information, or captain judgment.",
        "Check current weather before leaving and continue monitoring conditions while underway."
      ],
      "links": [],
      "priority": "High"
    },
    {
      "id": "does-floatplanwizard-replace-navigation-tools",
      "question": "Does FloatPlanWizard replace navigation tools?",
      "answer": [
        "No. FloatPlanWizard does not replace chartplotters, marine navigation apps, paper charts, official charts, depth sounders, AIS, VHF, or other navigation and safety tools.",
        "Use FloatPlanWizard to organize and share your plan, not as the sole source for navigation."
      ],
      "links": [],
      "priority": "High"
    }
    ]
  },
  {
    "id": "troubleshooting",
    "title": "Troubleshooting",
    "items": [
    {
      "id": "i-created-a-plan-why-can-t-my-contact-see-it",
      "question": "I created a plan. Why can’t my contact see it?",
      "answer": [
        "Make sure you sent the correct secure Follow link and that the trip is in a shareable status. If the plan was edited, closed, or replaced, your contact may need the latest link or latest trip update."
      ],
      "links": [
        "/app/contact.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "i-changed-my-plan-will-my-contacts-see-the-update",
      "question": "I changed my plan. Will my contacts see the update?",
      "answer": [
        "Contacts viewing the Trip status page should see the latest shared information available for that trip. If the change is important, also send your contacts a quick message so they know to check the updated plan."
      ],
      "links": [],
      "priority": "Medium"
    },
    {
      "id": "i-did-not-receive-an-email-what-should-i-check",
      "question": "I did not receive an email. What should I check?",
      "answer": [
        "Check your spam or junk folder, confirm that your email address was entered correctly, and allow a few minutes for delivery. If the message still does not arrive, contact support."
      ],
      "links": [
        "/app/contact.cfm"
      ],
      "priority": "Medium"
    },
    {
      "id": "something-does-not-look-right-how-do-i-report-it",
      "question": "Something does not look right. How do I report it?",
      "answer": [
        "Use the contact page to report issues, incorrect data, or problems with your account. Include the page you were using, what you expected to happen, and what actually happened."
      ],
      "links": [
        "/app/contact.cfm"
      ],
      "priority": "Medium"
    }
    ]
  }
];

function fpwFaqLocalUrl(required string path) {
  if (left(arguments.path, 1) EQ "/") {
    return fpwFaqBasePath & arguments.path;
  }

  return arguments.path;
}

function fpwFaqJoinParagraphs(required array paragraphs) {
  var joinedText = "";
  var paragraphIndex = 0;

  for (paragraphIndex = 1; paragraphIndex LTE arrayLen(arguments.paragraphs); paragraphIndex++) {
    if (len(joinedText)) {
      joinedText &= chr(10) & chr(10);
    }
    joinedText &= arguments.paragraphs[paragraphIndex];
  }

  return joinedText;
}

fpwFaqSchemaMainEntity = [];
for (fpwFaqSection in fpwFaqSections) {
  for (fpwFaqItem in fpwFaqSection.items) {
    fpwFaqQuestion = structNew("ordered");
    fpwFaqAnswer = structNew("ordered");
    structInsert(fpwFaqQuestion, "@type", "Question", true);
    fpwFaqQuestion["name"] = fpwFaqItem.question;
    structInsert(fpwFaqAnswer, "@type", "Answer", true);
    fpwFaqAnswer["text"] = fpwFaqJoinParagraphs(fpwFaqItem.answer);
    fpwFaqQuestion["acceptedAnswer"] = fpwFaqAnswer;
    arrayAppend(fpwFaqSchemaMainEntity, fpwFaqQuestion);
  }
}

fpwFaqSchema = structNew("ordered");
structInsert(fpwFaqSchema, "@context", "https://schema.org", true);
structInsert(fpwFaqSchema, "@type", "FAQPage", true);
fpwFaqSchema["mainEntity"] = fpwFaqSchemaMainEntity;
fpwFaqJsonLdText = replace(serializeJSON(fpwFaqSchema), "</", "<\/", "all");
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>FloatPlanWizard FAQ | Float Plans, Route Builder, Secure Follow Links &amp; Boating Trip Planning</title>
  <meta name="description" content="In-depth answers about FloatPlanWizard float plans, Route Builder, secure Follow links, Active Cruise, membership, Stripe billing, TrustedSite, and boating safety.">
  <link rel="canonical" href="https://floatplanwizard.com/faq/">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="FloatPlanWizard">
  <meta property="og:url" content="https://floatplanwizard.com/faq/">
  <meta property="og:title" content="FloatPlanWizard FAQ | Float Plans, Route Builder, Secure Follow Links &amp; Boating Trip Planning">
  <meta property="og:description" content="In-depth answers about FloatPlanWizard float plans, Route Builder, secure Follow links, Active Cruise, membership, Stripe billing, TrustedSite, and boating safety.">
  <meta property="og:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:secure_url" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="FloatPlanWizard FAQ | Float Plans, Route Builder, Secure Follow Links &amp; Boating Trip Planning">
  <meta name="twitter:description" content="In-depth answers about FloatPlanWizard float plans, Route Builder, secure Follow links, Active Cruise, membership, Stripe billing, TrustedSite, and boating safety.">
  <meta name="twitter:image" content="https://floatplanwizard.com/assets/images/social/floatplanwizard-social-preview-20260602.png">
  <meta name="twitter:image:alt" content="FloatPlanWizard boating trip planning and monitored float plan preview image">
  <cfoutput><link rel="stylesheet" href="#fpwFaqBasePath#/assets/css/layout.css?v=20260620-page-width"></cfoutput>
<cfoutput><link rel="stylesheet" href="#fpwFaqBasePath#/assets/css/top-nav.css?v=20260630-mega-weight-minus1"></cfoutput>
  <cfinclude template="../includes/analytics_ga4.cfm">
  <cfinclude template="../includes/analytics_clarity.cfm">
  <cfinclude template="../includes/trustedsite.cfm">
  <script type="application/ld+json"><cfoutput>#fpwFaqJsonLdText#</cfoutput></script>
  <style>
    :root {
      --fpw-faq-bg: #020915;
      --fpw-faq-bg-2: #041121;
      --fpw-faq-panel: rgba(5, 17, 31, 0.84);
      --fpw-faq-panel-strong: rgba(7, 21, 35, 0.94);
      --fpw-faq-line: rgba(126, 205, 220, 0.28);
      --fpw-faq-line-strong: rgba(126, 225, 242, 0.62);
      --fpw-faq-text: #f4f8ff;
      --fpw-faq-muted: #b8c5d2;
      --fpw-faq-soft: #8398aa;
      --fpw-faq-cyan: #7ffaf5;
      --fpw-faq-blue: #36bdf5;
      --fpw-faq-radius: 18px;
      --fpw-public-layout-max: var(--fpw-page-max, 1200px);
    }

    * {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body.fpw-faq-body {
      margin: 0;
      min-height: 100vh;
      color: var(--fpw-faq-text);
      background:
        radial-gradient(circle at 12% 8%, rgba(35, 215, 207, 0.12), transparent 30%),
        radial-gradient(circle at 88% 12%, rgba(54, 189, 245, 0.12), transparent 34%),
        linear-gradient(180deg, var(--fpw-faq-bg), var(--fpw-faq-bg-2) 48%, #02070d);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    body.fpw-faq-body a {
      color: inherit;
    }

    .fpw-faq-page {
      width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
      margin: 0 auto;
      padding: 18px 0 clamp(44px, 6vw, 82px);
    }

    .fpw-faq-hero {
      padding: clamp(30px, 4vw, 52px);
      border: 1px solid var(--fpw-faq-line);
      border-radius: 24px;
      background:
        radial-gradient(circle at top right, rgba(54, 189, 245, 0.13), transparent 36%),
        linear-gradient(135deg, rgba(6, 20, 34, 0.98), rgba(5, 17, 29, 0.92));
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.34);
    }

    .fpw-faq-eyebrow {
      margin: 0 0 12px;
      color: #b7c4d3;
      font-size: clamp(1rem, 1.4vw, 1.24rem);
      font-weight: 800;
      letter-spacing: 0.18em;
      text-transform: uppercase;
    }

    .fpw-faq-hero h1 {
      max-width: 980px;
      margin: 0;
      color: #ffffff;
      font-size: clamp(2.6rem, 5vw, 4.6rem);
      line-height: 0.98;
      letter-spacing: -0.055em;
    }

    .fpw-faq-lede {
      max-width: 1060px;
      margin: 22px 0 0;
      color: rgba(220, 232, 244, 0.86);
      font-size: clamp(1.06rem, 1.45vw, 1.26rem);
      line-height: 1.58;
    }

    .fpw-faq-support-copy {
      max-width: 980px;
      margin: 16px 0 0;
      color: rgba(184, 197, 210, 0.84);
      font-size: 1.02rem;
      line-height: 1.58;
    }

    .fpw-faq-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      margin-top: 26px;
    }

    .fpw-faq-button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 48px;
      padding: 0 20px;
      border: 1px solid rgba(126, 225, 242, 0.42);
      border-radius: 14px;
      color: #eef8ff;
      text-decoration: none;
      font-weight: 800;
      transition: transform 0.18s ease, border-color 0.18s ease, background 0.18s ease;
    }

    .fpw-faq-button:hover,
    .fpw-faq-button:focus {
      transform: translateY(-1px);
      border-color: rgba(126, 225, 242, 0.75);
      background: rgba(126, 225, 242, 0.08);
    }

    .fpw-faq-button--primary {
      color: #06131d;
      border-color: transparent;
      background: linear-gradient(135deg, #6ee7f0, #3aa9d8);
      box-shadow: 0 16px 38px rgba(38, 197, 218, 0.22);
    }

    .fpw-faq-trust-strip {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 16px;
      margin-top: 18px;
    }

    .fpw-faq-trust-card,
    .fpw-faq-section,
    .fpw-faq-bottom-cta {
      border: 1px solid var(--fpw-faq-line);
      background: rgba(5, 17, 31, 0.82);
      box-shadow: 0 18px 58px rgba(0, 0, 0, 0.2);
    }

    .fpw-faq-trust-card {
      min-height: 132px;
      padding: 22px;
      border-radius: 18px;
    }

    .fpw-faq-trust-card strong {
      display: block;
      color: #ffffff;
      font-size: 1.05rem;
      margin-bottom: 8px;
    }

    .fpw-faq-trust-card p {
      margin: 0;
      color: var(--fpw-faq-muted);
      line-height: 1.55;
    }

    .fpw-faq-category-nav {
      position: sticky;
      top: 0;
      z-index: 4;
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 20px;
      padding: 14px;
      border: 1px solid rgba(126, 205, 220, 0.2);
      border-radius: 18px;
      background: rgba(2, 9, 21, 0.9);
      backdrop-filter: blur(14px);
    }

    .fpw-faq-category-nav a {
      display: inline-flex;
      align-items: center;
      min-height: 36px;
      padding: 0 13px;
      border: 1px solid rgba(126, 225, 242, 0.22);
      border-radius: 999px;
      color: var(--fpw-faq-muted);
      text-decoration: none;
      font-size: 0.9rem;
      font-weight: 800;
    }

    .fpw-faq-category-nav a:hover,
    .fpw-faq-category-nav a:focus {
      color: #ffffff;
      border-color: rgba(126, 225, 242, 0.62);
      background: rgba(126, 225, 242, 0.08);
    }

    .fpw-faq-section {
      scroll-margin-top: 96px;
      margin: 10px 0;
      border-radius: 20px;
      overflow: hidden;
    }

    .fpw-faq-section-header {
      padding: 24px 28px 18px;
      border-bottom: 1px solid rgba(126, 205, 220, 0.18);
      background: rgba(6, 20, 34, 0.7);
    }

    .fpw-faq-section-header h2 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(1.45rem, 2.4vw, 2.35rem);
      line-height: 1.04;
      letter-spacing: -0.035em;
    }

    .fpw-faq-section-header p {
      margin: 8px 0 0;
      color: var(--fpw-faq-soft);
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      font-size: 0.75rem;
    }

    .fpw-faq-item + .fpw-faq-item {
      border-top: 1px solid rgba(126, 205, 220, 0.18);
    }

    .fpw-faq-row {
      width: 100%;
      border: 0;
      background: transparent;
      color: var(--fpw-faq-text);
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 20px;
      padding: 21px 28px;
      text-align: left;
      font: inherit;
      font-size: clamp(1rem, 1.25vw, 1.16rem);
      font-weight: 800;
      cursor: pointer;
    }

    .fpw-faq-row:hover,
    .fpw-faq-row:focus-visible {
      background: rgba(126, 225, 242, 0.06);
      outline: none;
    }

    .fpw-faq-icon {
      flex: 0 0 auto;
      color: var(--fpw-faq-cyan);
      font-size: 1.6rem;
      line-height: 1;
      transition: transform 0.2s ease, color 0.2s ease;
    }

    .fpw-faq-row[aria-expanded="true"] .fpw-faq-icon {
      color: #ffffff;
      transform: rotate(45deg);
    }

    .fpw-faq-answer {
      padding: 0 28px 24px;
      color: var(--fpw-faq-muted);
    }

    .fpw-faq-answer p {
      max-width: 1060px;
      margin: 0;
      line-height: 1.72;
      font-size: clamp(0.98rem, 1.12vw, 1.07rem);
    }

    .fpw-faq-answer p + p {
      margin-top: 14px;
    }

    .fpw-faq-related {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 18px;
      padding-top: 16px;
      border-top: 1px solid rgba(126, 205, 220, 0.16);
    }

    .fpw-faq-related span {
      display: inline-flex;
      align-items: center;
      min-height: 32px;
      color: var(--fpw-faq-soft);
      font-size: 0.82rem;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .fpw-faq-related a {
      display: inline-flex;
      align-items: center;
      min-height: 32px;
      padding: 0 11px;
      border: 1px solid rgba(126, 225, 242, 0.28);
      border-radius: 999px;
      color: var(--fpw-faq-cyan);
      text-decoration: none;
      font-size: 0.9rem;
      font-weight: 800;
    }

    .fpw-faq-related a:hover,
    .fpw-faq-related a:focus {
      border-color: rgba(126, 225, 242, 0.62);
      background: rgba(126, 225, 242, 0.08);
    }

    .fpw-faq-bottom-cta {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 24px;
      margin-top: clamp(26px, 4vw, 44px);
      padding: clamp(24px, 4vw, 36px);
      border-radius: 20px;
      background:
        radial-gradient(circle at top left, rgba(35, 215, 207, 0.12), transparent 32%),
        rgba(6, 20, 34, 0.84);
    }

    .fpw-faq-bottom-cta h2 {
      margin: 0;
      color: #ffffff;
      font-size: clamp(1.55rem, 2.4vw, 2.35rem);
      letter-spacing: -0.04em;
    }

    .fpw-faq-bottom-cta p {
      max-width: 920px;
      margin: 8px 0 0;
      color: var(--fpw-faq-muted);
      line-height: 1.55;
    }

    .fpw-faq-bottom-cta__actions {
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      gap: 12px;
    }

    @media (max-width: 980px) {
      .fpw-faq-trust-strip {
        grid-template-columns: 1fr;
      }

      .fpw-faq-category-nav {
        position: static;
      }

      .fpw-faq-bottom-cta {
        display: block;
      }

      .fpw-faq-bottom-cta__actions {
        justify-content: flex-start;
        margin-top: 18px;
      }
    }

    @media (max-width: 560px) {
      .fpw-faq-page {
        width: min(var(--fpw-public-layout-max), calc(100% - (var(--fpw-page-gutter, 32px) * 2)));
        padding-top: 18px;
      }

      .fpw-faq-hero {
        padding: 26px 20px;
        border-radius: 20px;
      }

      .fpw-faq-hero h1 {
        font-size: clamp(2.35rem, 12vw, 3.2rem);
      }

      .fpw-faq-actions,
      .fpw-faq-button,
      .fpw-faq-bottom-cta__actions {
        width: 100%;
      }

      .fpw-faq-section-header,
      .fpw-faq-row {
        padding-left: 18px;
        padding-right: 18px;
      }

      .fpw-faq-answer {
        padding: 0 18px 20px;
      }
    }
  </style>
</head>
<body id="top" class="fpw-faq-body">
<cfinclude template="../includes/top_nav.cfm">

<main class="fpw-faq-page">
  <section class="fpw-faq-hero" aria-labelledby="fpwFaqHeroTitle">
    <p class="fpw-faq-eyebrow">FloatPlanWizard FAQ</p>
    <h1 id="fpwFaqHeroTitle">Frequently Asked Questions</h1>
    <p class="fpw-faq-lede">Everything you need to know about FloatPlanWizard, including float plans, Route Builder, secure Follow links for family and friends, Active Cruise, membership, billing, TrustedSite verification, and boating safety.</p>
    <p class="fpw-faq-support-copy">FloatPlanWizard is designed to help boaters organize trip details before leaving the dock, share important information with trusted contacts, and keep plans easier to update as conditions change.</p>
    <div class="fpw-faq-actions">
      <a class="fpw-faq-button fpw-faq-button--primary" href="<cfoutput>#fpwFaqCreateUrl#</cfoutput>">Create Your Float Plan</a>
      <a class="fpw-faq-button" href="<cfoutput>#fpwFaqRouteBuilderUrl#</cfoutput>">Explore Route Builder</a>
    </div>
  </section>

  <section class="fpw-faq-trust-strip" aria-label="FloatPlanWizard trust highlights">
    <article class="fpw-faq-trust-card">
      <strong>Built for real boating plans</strong>
      <p>Organize vessel details, passengers, timing, destinations, route notes, and contacts in one place.</p>
    </article>
    <article class="fpw-faq-trust-card">
      <strong>Secure Follow links</strong>
      <p>Share trip information with family and friends without requiring them to create an account.</p>
    </article>
    <article class="fpw-faq-trust-card">
      <strong>Payments handled by Stripe</strong>
      <p>Checkout, billing, and payment method handling are processed through Stripe’s secure payment systems.</p>
    </article>
  </section>

  <nav class="fpw-faq-category-nav" aria-label="FAQ categories">
    <cfoutput>
    <cfloop array="#fpwFaqSections#" index="fpwFaqSection">
      <a href="###encodeForHTMLAttribute(fpwFaqSection.id)#">#encodeForHTML(fpwFaqSection.title)#</a>
    </cfloop>
    </cfoutput>
  </nav>

  <cfoutput>
  <cfloop array="#fpwFaqSections#" index="fpwFaqSection">
    <section class="fpw-faq-section" id="#encodeForHTMLAttribute(fpwFaqSection.id)#" aria-labelledby="fpw-faq-section-title-#encodeForHTMLAttribute(fpwFaqSection.id)#">
      <header class="fpw-faq-section-header">
        <h2 id="fpw-faq-section-title-#encodeForHTMLAttribute(fpwFaqSection.id)#">#encodeForHTML(fpwFaqSection.title)#</h2>
        <p>#arrayLen(fpwFaqSection.items)# questions</p>
      </header>
      <div class="fpw-faq-list" data-fpw-faq-section>
        <cfloop array="#fpwFaqSection.items#" index="fpwFaqItem">
          <article class="fpw-faq-item">
            <button class="fpw-faq-row" id="fpw-faq-question-#encodeForHTMLAttribute(fpwFaqItem.id)#" type="button" aria-expanded="false" aria-controls="fpw-faq-answer-#encodeForHTMLAttribute(fpwFaqItem.id)#">
              <span>#encodeForHTML(fpwFaqItem.question)#</span>
              <span class="fpw-faq-icon" aria-hidden="true">+</span>
            </button>
            <div class="fpw-faq-answer" id="fpw-faq-answer-#encodeForHTMLAttribute(fpwFaqItem.id)#" role="region" aria-labelledby="fpw-faq-question-#encodeForHTMLAttribute(fpwFaqItem.id)#" hidden>
              <cfloop array="#fpwFaqItem.answer#" index="fpwFaqParagraph">
                <p>#encodeForHTML(fpwFaqParagraph)#</p>
              </cfloop>
              <cfif arrayLen(fpwFaqItem.links)>
                <div class="fpw-faq-related" aria-label="Related links">
                  <span>Related links</span>
                  <cfloop array="#fpwFaqItem.links#" index="fpwFaqLink">
                    <a href="#encodeForHTMLAttribute(fpwFaqLocalUrl(fpwFaqLink))#">#encodeForHTML(structKeyExists(fpwFaqLinkLabels, fpwFaqLink) ? fpwFaqLinkLabels[fpwFaqLink] : fpwFaqLink)#</a>
                  </cfloop>
                </div>
              </cfif>
            </div>
          </article>
        </cfloop>
      </div>
    </section>
  </cfloop>
  </cfoutput>

  <section class="fpw-faq-bottom-cta" aria-labelledby="fpwFaqBottomCtaTitle">
    <div>
      <h2 id="fpwFaqBottomCtaTitle">Ready to build a better float plan?</h2>
      <p>Use FloatPlanWizard to create a float plan, organize your route, share a secure Follow link with family and friends, and keep important trip details easier to update.</p>
    </div>
    <div class="fpw-faq-bottom-cta__actions">
      <a class="fpw-faq-button fpw-faq-button--primary" href="<cfoutput>#fpwFaqCreateUrl#</cfoutput>">Create Your Float Plan</a>
      <a class="fpw-faq-button" href="<cfoutput>#fpwFaqFuelUrl#</cfoutput>">Try the Fuel Calculator</a>
    </div>
  </section>
</main>

<script>
  (function () {
    var faqButtons = Array.prototype.slice.call(document.querySelectorAll(".fpw-faq-row"));

    function setFaqState(button, isOpen) {
      var panelId = button.getAttribute("aria-controls");
      var panel = panelId ? document.getElementById(panelId) : null;

      button.setAttribute("aria-expanded", isOpen ? "true" : "false");
      if (panel) {
        panel.hidden = !isOpen;
      }
    }

    faqButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        var shouldOpen = button.getAttribute("aria-expanded") !== "true";

        faqButtons.forEach(function (otherButton) {
          setFaqState(otherButton, false);
        });
        setFaqState(button, shouldOpen);
      });

      button.addEventListener("keydown", function (event) {
        if (event.key !== "Enter" && event.key !== " " && event.key !== "Spacebar") {
          return;
        }

        event.preventDefault();
        button.click();
      });
    });
  })();
</script>

<cfinclude template="../includes/footer.cfm">
</body>
</html>
