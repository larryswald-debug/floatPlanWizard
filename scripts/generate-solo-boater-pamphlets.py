#!/usr/bin/env python3
"""Generate the FloatPlanWizard Solo Boating Safety Series PDFs.

The checklist wording is parsed directly from solo-boating-safety-guide.cfm so
the public HTML guide remains the controlling checklist source.
"""

from __future__ import annotations

import argparse
import html
import re
from functools import partial
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from pypdf.generic import NameObject, TextStringObject
from reportlab import rl_config
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    Flowable,
    HRFlowable,
    Image,
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


rl_config.invariant = 1

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
GUIDE_SOURCE = REPOSITORY_ROOT / "solo-boating-safety-guide.cfm"
LOGO_PATH = REPOSITORY_ROOT / "assets" / "press" / "logo.png"
DOWNLOADS_DIR = REPOSITORY_ROOT / "downloads"
PUBLICATION_DATE = "August 10, 2026"
SERIES_LABEL = "FloatPlanWizard Solo Boating Safety Series"
SITE_URL = "https://floatplanwizard.com/"
GUIDE_URL = "https://floatplanwizard.com/solo-boating-safety-guide/"

NAVY = colors.HexColor("#04111f")
DEEP_BLUE = colors.HexColor("#08253a")
TEAL = colors.HexColor("#0b6f78")
CYAN = colors.HexColor("#00bfc4")
INK = colors.HexColor("#132331")
MUTED = colors.HexColor("#4c5d69")
LINE = colors.HexColor("#b7c9d3")
PALE_CYAN = colors.HexColor("#e9f7f7")
PALE_BLUE = colors.HexColor("#eef4f7")
WHITE = colors.white

EXPECTED_COUNTS = {
    "trip-plan": 12,
    "vessel": 7,
    "personal": 10,
    "weather": 14,
    "communications": 12,
    "readiness": 19,
    "specific": 10,
}

COMMON_PROMOTION = (
    "A checklist helps you remember the details. FloatPlanWizard helps you organize "
    "them into a float plan that can be created, sent to a shore contact, shared, "
    "and automatically monitored during an active trip."
)

MONITORING_LIMIT = (
    "Automated monitoring is not professional human monitoring. FloatPlanWizard does "
    "not guarantee live tracking, a current location, alert delivery, distress "
    "verification, emergency-services contact, or rescue dispatch."
)

DISCLAIMER = (
    "This guide provides general recreational-boating safety information and does not "
    "replace applicable laws, official safety guidance, training, seamanship, or the "
    "judgment of the vessel operator. Requirements vary by vessel, activity, location, "
    "and jurisdiction."
)


PAMPHLETS = [
    {
        "key": "trip-planning",
        "group_id": "trip-plan",
        "filename": "solo-boater-trip-planning-guide.pdf",
        "title": "Solo Boater Trip Planning Guide & Checklist",
        "short_title": "Trip Planning Guide",
        "purpose": "Build a clear trip plan that somebody ashore can understand and use.",
        "why": [
            "When nobody else is aboard, the shore contact may be the only person who knows where the boater intended to go and when the trip was supposed to end.",
            "An accurate plan helps a shore contact distinguish an ordinary schedule change from a potentially overdue boater. It also gives the contact useful facts if authorities need information.",
            "The plan should be specific enough to be useful without pretending that every delay is an emergency. Agree in advance on check-ins, what overdue means for this trip, and what the shore contact should do.",
        ],
        "sections": [
            {
                "heading": "Record the intended trip",
                "paragraphs": [
                    "Identify the exact launch or departure point, planned route, destination, important stops, and expected return or arrival time. Include reasonable alternate destinations or safe stopping points when the trip may change.",
                    "For a trailered boat or paddlecraft, the ramp, beach, access point, parking area, vehicle, and trailer can help identify where the trip began.",
                ],
                "bullets": [
                    "Use location names that another person can find.",
                    "Record timing as a plan, not as a guaranteed schedule.",
                    "Keep the shore contact's copy accessible for the full trip.",
                ],
            },
            {
                "heading": "Agree on check-ins and overdue expectations",
                "paragraphs": [
                    "A planned check-in is a specific point when the boater expects to report. An overdue threshold is the agreed point when the shore contact should follow the response plan. They are related, but they are not the same thing.",
                    "There is no universal grace period. Trip type, weather, remoteness, communications, the operator, and other circumstances all affect the appropriate response. Evidence of immediate danger may justify action before a planned overdue time.",
                ],
            },
            {
                "heading": "Update and close the plan",
                "paragraphs": [
                    "When practical, notify the shore contact after a substantial route change, different destination, unexpected stop, delay, early return, or abandoned trip. The contact should know which information is still current.",
                    "Tell the shore contact when the trip is safely complete. A plan left open creates avoidable uncertainty about whether the boater forgot to close it or is actually overdue.",
                ],
            },
        ],
        "key_things": [
            "A useful plan identifies where the trip starts, where it is intended to go, and when it should end.",
            "The shore contact must understand the plan and the agreed overdue response.",
            "Report material changes and close the plan when the trip is complete.",
        ],
        "related": [
            ("Solo Boating Safety Guide", GUIDE_URL),
            ("Shore Contact Guide", "https://floatplanwizard.com/shore-contact-overdue-boater/"),
            ("Why Use a Float Plan", "https://floatplanwizard.com/why-use-a-float-plan/"),
        ],
    },
    {
        "key": "vessel-information",
        "group_id": "vessel",
        "filename": "solo-boater-vessel-information-guide.pdf",
        "title": "Solo Boater Vessel Identification Guide & Checklist",
        "short_title": "Vessel Identification Guide",
        "purpose": "Make the boat, craft, launch point, vehicle, and trailer easier to identify accurately.",
        "why": [
            "If a solo boater is overdue, somebody ashore may need to describe the boat or craft and explain where it entered the water. Generic descriptions such as 'white boat' or 'blue kayak' provide far less useful information than a current photo and accurate details.",
            "The most useful identification varies with the craft. A kayaker may need an exact launch site, vehicle information, and a clear craft photo. A cruiser may need vessel name, registration or documentation, size, color, marina, and distinguishing features.",
            "Record the information before departure, when there is time to confirm it. Do not rely on the shore contact remembering details from an old photo or a casual conversation.",
        ],
        "sections": [
            {
                "heading": "Start with a current photo",
                "paragraphs": [
                    "Use a recent photo that clearly shows the vessel or craft as it appears for the trip. If practical, include its primary colors, hull profile, cabin or deck arrangement, and visible equipment.",
                    "For paddlecraft, record the kayak or canoe type and color. For powerboats and sailboats, include make, model, type, length, registration or documentation, and prominent features.",
                ],
            },
            {
                "heading": "Describe what makes it identifiable",
                "paragraphs": [
                    "Identifying features can include vessel name, hull and trim colors, top or enclosure color, sail markings, antennas, towers, unusual equipment, or other visible details. Accuracy matters more than a long description.",
                ],
                "bullets": [
                    "Use current registration or documentation information where applicable.",
                    "Record the exact marina, ramp, dock, beach, or access point.",
                    "Include the tow vehicle and trailer when they help establish the launch location.",
                ],
            },
            {
                "heading": "Match the record to the craft",
                "paragraphs": [
                    "Kayaks and canoes may have little formal identifying information, so the current photo, color, launch location, route, vehicle, and planned return may carry more weight. Larger boats often have additional registration, documentation, vessel-name, size, marina, and equipment details to record.",
                ],
            },
        ],
        "key_things": [
            "Use a current photo, not a generic model image.",
            "Record exact access-point and vehicle details when relevant.",
            "Describe the craft with details another person can repeat accurately.",
        ],
        "related": [
            ("Solo Boating Safety Guide", GUIDE_URL),
            ("Shore Contact Guide", "https://floatplanwizard.com/shore-contact-overdue-boater/"),
        ],
    },
    {
        "key": "personal-safety",
        "group_id": "personal",
        "filename": "solo-boater-personal-safety-guide.pdf",
        "title": "Solo Boater Personal Safety Guide & Checklist",
        "short_title": "Personal Safety Guide",
        "purpose": "Prepare for personal needs and self-recovery when no second person is aboard to assist.",
        "why": [
            "A small problem can become serious more quickly when there is no second person to provide flotation, take the helm, retrieve equipment, call for help, or assist with reboarding.",
            "Personal preparation includes wearing an appropriate PFD, dressing for air and water conditions, beginning rested and hydrated, carrying needed food and medications, and keeping first-aid and emergency equipment accessible.",
            "Before departure, ask: If I enter the water, can I get back aboard without another person's help? The practical answer depends on the craft, freeboard, ladder or rescue method, clothing, water temperature, waves, fatigue, and physical condition.",
        ],
        "callouts": [
            "If you enter the water, can you get back aboard without another person's help?",
        ],
        "sections": [
            {
                "heading": "Wear and carry equipment for the activity",
                "paragraphs": [
                    "Federal and state PFD requirements vary by vessel, activity, age, location, and jurisdiction. This reference does not state that every adult is legally required to wear a PFD at all times in every situation.",
                    "For solo boating, the FloatPlanWizard best-practice recommendation is to wear an appropriate PFD while underway. An unexpected emergency may not leave time to retrieve and put one on.",
                ],
            },
            {
                "heading": "Plan the recovery before the trip",
                "paragraphs": [
                    "A kayak requires a practiced capsize or self-rescue method appropriate to the craft and conditions. A small open boat or center console requires a realistic way to reach and use a ladder. A sailboat or high-freeboard cruiser may be very difficult to board from the water without a properly designed system.",
                    "Practice the relevant method where practical and safe. A ladder is useful only if it can be reached or deployed from the water, and essential communications are useful only if they remain accessible after separation from the boat.",
                ],
            },
            {
                "heading": "Manage the operator",
                "paragraphs": [
                    "Rest, hydration, food, medications, exposure protection, and first-aid preparation are operational safety considerations. Set conservative limits before departure, and do not let a schedule create pressure to continue when the operator is not ready.",
                ],
            },
        ],
        "key_things": [
            "Wear a PFD appropriate to the activity and conditions.",
            "Dress for both air and water exposure.",
            "Know and, where practical, practice how you would reboard or self-rescue.",
            "Keep essential equipment reachable if separated from the craft.",
        ],
        "related": [
            ("Solo Boating Safety Guide", GUIDE_URL),
            ("U.S. Coast Guard Life Jacket Guidance", "https://www.uscgboating.org/recreational-boaters/life-jacket-wear-wearing-your-life-jacket.php"),
            ("National Park Service Kayak Safety", "https://www.nps.gov/thingstodo/kayaking-and-kayak-safety.htm"),
        ],
    },
    {
        "key": "weather",
        "group_id": "weather",
        "filename": "solo-boater-weather-guide.pdf",
        "title": "Solo Boater Weather & Conditions Guide & Checklist",
        "short_title": "Weather & Conditions Guide",
        "purpose": "Use the full-route forecast and predetermined limits to make a conservative solo go/no-go decision.",
        "why": [
            "A solo operator has no one aboard to take over when conditions deteriorate or fatigue increases. Weather therefore deserves a larger safety margin than the operator might choose with competent crew aboard.",
            "Conditions you may comfortably handle with competent crew aboard may not be conditions you choose to handle alone. Check the full planned route and time period, not only the conditions visible at the launch point.",
            "This reference does not prescribe universal wind, wave, current, temperature, or visibility limits. Appropriate limits depend on the craft, operator, route, experience, exposure, and actual conditions.",
        ],
        "callouts": [
            "Conditions you may comfortably handle with competent crew aboard may not be conditions you choose to handle alone.",
        ],
        "sections": [
            {
                "heading": "Review the complete weather picture",
                "paragraphs": [
                    "Review the current forecast, applicable advisories and warnings, wind and gusts, waves or seas, thunderstorm risk, visibility, fog, air temperature, water temperature, and daylight. Add tides and currents wherever they affect the trip.",
                    "Use official NOAA/NWS information and other authoritative local sources. FPW Marine Weather can help organize weather review in the trip-planning workflow, but no single display replaces operator judgment or current official warnings.",
                ],
            },
            {
                "heading": "Consider the entire route",
                "paragraphs": [
                    "Conditions can differ between the launch, open water, a river reach, a shoreline exposed to wind, and the return leg. Consider how the timing of the trip changes wind, current, tide, daylight, and exposure.",
                    "For paddlecraft, an offshore wind, current, tidal flow, or building waves can make the return much harder than the outbound leg. Larger boats also face route-specific visibility, maneuvering, and fatigue demands.",
                ],
            },
            {
                "heading": "Set turn-back limits before departure",
                "paragraphs": [
                    "Decide in advance which conditions would cause you to cancel, turn back, shorten the trip, or choose a protected alternative. Predetermined limits reduce the influence of schedule pressure after the trip has started.",
                ],
            },
        ],
        "key_things": [
            "Check current official forecasts, advisories, and warnings.",
            "Evaluate conditions along the entire route and return period.",
            "Use craft-, operator-, and route-specific conservative limits.",
            "Decide what will trigger a turn-back or cancellation before leaving.",
        ],
        "related": [
            ("Solo Boating Safety Guide", GUIDE_URL),
            ("FPW Marine Weather", "https://floatplanwizard.com/app/weather.cfm"),
            ("NOAA/NWS Marine Forecasts", "https://www.weather.gov/marine/"),
        ],
    },
    {
        "key": "communications",
        "group_id": "communications",
        "filename": "solo-boater-communications-guide.pdf",
        "title": "Solo Boater Communications & Distress Equipment Guide",
        "subtitle": "VHF, Cellphones, DSC, PLBs, EPIRBs & Checklist",
        "short_title": "Communications Guide",
        "purpose": "Build useful communication redundancy and keep critical distress equipment accessible after separation from the boat.",
        "why": [
            "A solo boater should not depend on one communication method. Coverage, batteries, devices, antennas, and the operator's ability to reach the equipment can all fail.",
            "The best radio or beacon aboard is of limited use if the solo operator cannot reach it after becoming separated from the vessel. At least one useful emergency communication method should remain personally accessible where appropriate.",
            "Communication equipment improves options, but it does not guarantee coverage, reception, rescue, or a particular beacon-response time. Learn how the equipment works before departure and tell the shore contact which methods you expect to use.",
        ],
        "sections": [
            {
                "heading": "Use more than one appropriate method",
                "paragraphs": [
                    "A cellphone can be useful in coverage and should be charged and protected from water where appropriate. It is not a complete substitute for marine VHF in situations where VHF is the appropriate boating communication tool.",
                    "A fixed VHF can provide range and power from the vessel. A charged waterproof handheld VHF can provide backup and may remain useful if the primary radio or boat power fails.",
                ],
            },
            {
                "heading": "Understand VHF, Channel 16, and DSC",
                "paragraphs": [
                    "Channel 16 is the international distress, safety, and calling channel. Know how to select it, transmit clearly, state the nature of the problem, and provide location and vessel information where applicable.",
                    "Digital Selective Calling can transmit a digital distress alert from a properly configured radio. Its usefulness depends on correct installation, GPS integration where required, and a registered MMSI matched to current vessel and contact information.",
                ],
            },
            {
                "heading": "PLB and EPIRB are different tools",
                "paragraphs": [
                    "A PLB is a personally carried emergency beacon. Personal accessibility can be especially valuable to a solo boater who becomes separated from the vessel.",
                    "An EPIRB is a maritime or vessel distress beacon designed for boating use. Equipment choice and carriage depend on the vessel and trip. Registration information for either beacon must be kept current.",
                ],
            },
            {
                "heading": "Accessibility is part of the system",
                "paragraphs": [
                    "Do not store every radio, phone, or beacon where it becomes unreachable after a capsize or fall overboard. Protect equipment from water, check batteries, and practice basic operation before the trip.",
                ],
            },
        ],
        "key_things": [
            "Choose a primary method and an appropriate backup.",
            "Know how to use Channel 16 and configure DSC/MMSI correctly where applicable.",
            "Register PLBs and EPIRBs and keep the registration current.",
            "Keep critical personal distress equipment accessible after separation from the vessel.",
        ],
        "related": [
            ("Solo Boating Safety Guide", GUIDE_URL),
            ("U.S. Coast Guard Radio Information for Boaters", "https://navcen.uscg.gov/radio-information-for-boaters"),
            ("NOAA Beacon Registration", "https://beaconregistration.noaa.gov/RGDB/index"),
        ],
    },
    {
        "key": "boat-readiness",
        "group_id": "readiness",
        "filename": "solo-boater-boat-readiness-guide.pdf",
        "title": "Solo Boater Pre-Departure Boat Readiness Guide & Checklist",
        "short_title": "Boat Readiness Guide",
        "purpose": "Check propulsion, controls, power, navigation, safety equipment, and craft-specific systems before leaving alone.",
        "why": [
            "Equipment failures that might be manageable with another capable person aboard can become much harder to handle alone. A pre-departure check reduces avoidable surprises and confirms that essential equipment is accessible.",
            "Readiness is proportional to the craft and trip. A paddler may focus on hull condition, drainage, paddle or spare paddle, flotation, and personal equipment. A powerboat or cruiser adds fuel, batteries, propulsion, steering, controls, dewatering, navigation, anchoring, and electrical systems.",
            "This reference is not a universal regulatory equipment list. Legal requirements vary by vessel, length, propulsion, activity, operating waters, and jurisdiction. Confirm current requirements with the appropriate authority.",
        ],
        "sections": [
            {
                "heading": "Propulsion, fuel, power, and control",
                "paragraphs": [
                    "Check the engine or other propulsion system, fuel quantity, appropriate reserve, batteries, charging, steering, throttle, shift controls, rudder or tiller, and engine cut-off system where applicable.",
                    "Fuel calculations are estimates. They do not replace the operator's responsibility to account for actual consumption, reserve, weather, current, detours, and operating conditions.",
                ],
            },
            {
                "heading": "Water management and navigation",
                "paragraphs": [
                    "Confirm bilge pumps, drain plugs, cockpit drains, scuppers, and manual dewatering equipment where appropriate. Check navigation lights if they may be needed and verify the chartplotter, charts, compass, and an appropriate backup navigation method.",
                ],
            },
            {
                "heading": "Safety and contingency equipment",
                "paragraphs": [
                    "Check required and trip-appropriate PFDs, sound-signaling equipment, visual distress signals, fire extinguishing equipment, first aid, anchor and ground tackle, reboarding equipment, communications, tools, and spares.",
                    "For eligible recreational boats, a free U.S. Coast Guard Auxiliary Vessel Safety Check can help identify missing required equipment, condition issues, and other preparation concerns.",
                ],
            },
        ],
        "key_things": [
            "Check the systems that move, steer, power, and control the craft.",
            "Verify dewatering, navigation, signaling, and safety equipment.",
            "Carry appropriate backup navigation, tools, and spares for the trip.",
            "Review current legal requirements for the vessel and operating waters.",
        ],
        "related": [
            ("Solo Boating Safety Guide", GUIDE_URL),
            ("FPW Boat Fuel Calculator", "https://floatplanwizard.com/boat-fuel-calculator/"),
            ("U.S. Coast Guard Auxiliary Vessel Safety Check", "https://www.cgaux.org/vsc/"),
        ],
    },
    {
        "key": "precautions",
        "group_id": "specific",
        "filename": "solo-boater-precautions-guide.pdf",
        "title": "Solo Boating Precautions Guide & Checklist",
        "short_title": "Solo Precautions Guide",
        "purpose": "Deliberately replace some of the redundancy lost when no capable second person is aboard.",
        "why": [
            "Solo boating removes the safety margin normally provided by another competent person aboard. The purpose of preparation is not to discourage boating alone; it is to replace some of that missing redundancy with planning, equipment, communication, conservative judgment, and practiced recovery methods.",
            "A solo operator must consider what happens if the boat keeps moving after a fall overboard, whether reboarding equipment can be reached from the water, whether critical communications remain accessible, and who ashore understands the trip.",
            "Before departure, ask two direct questions: If something goes wrong and you cannot operate the boat normally, what is your backup plan? If you fall overboard, will the boat stop - and can you get back aboard?",
        ],
        "callouts": [
            "If something goes wrong and you cannot operate the boat normally, what is your backup plan?",
            "If you fall overboard, will the boat stop - and can you get back aboard?",
        ],
        "sections": [
            {
                "heading": "Stay with the boat and plan reboarding",
                "paragraphs": [
                    "Use the engine cut-off system where required and whenever appropriately equipped for the operating situation. Arrange frequently used equipment to reduce unnecessary movement away from a secure operating position.",
                    "Know whether you can climb back aboard without help. Test the ladder, platform, or craft-specific self-rescue method where practical and safe, including whether it can be reached or deployed from the water.",
                ],
            },
            {
                "heading": "Keep critical equipment accessible",
                "paragraphs": [
                    "Do not place every communication device or piece of emergency equipment somewhere you could lose access to after falling overboard or capsizing. Personal carriage and waterproof protection may be appropriate depending on the craft and trip.",
                ],
            },
            {
                "heading": "Prepare before maneuvering",
                "paragraphs": [
                    "Set lines, fenders, and needed equipment before approaching a dock, marina, lock, or anchorage. Reduce avoidable last-second deck movement and identify the intended maneuver in advance.",
                ],
            },
            {
                "heading": "Use an abort plan and keep shore informed",
                "paragraphs": [
                    "Decide what conditions, fatigue, equipment issue, or timing change will cause you to turn back, stop, or cancel. Do not allow a schedule to pressure you into unsafe conditions.",
                    "Report significant route or timing changes when practical, and close the float plan when the trip is safely complete.",
                ],
            },
        ],
        "key_things": [
            "Plan for separation from the boat before it happens.",
            "Keep a useful communication method personally accessible where appropriate.",
            "Prepare lines, fenders, and equipment before close maneuvering.",
            "Use conservative abort limits and keep the shore contact updated.",
        ],
        "related": [
            ("Solo Boating Safety Guide", GUIDE_URL),
            ("Shore Contact Guide", "https://floatplanwizard.com/shore-contact-overdue-boater/"),
            ("Why Use a Float Plan", "https://floatplanwizard.com/why-use-a-float-plan/"),
        ],
    },
]


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def strip_markup(value: str) -> str:
    value = re.sub(r"<cfoutput>[\s\S]*?</cfoutput>", "", value, flags=re.IGNORECASE)
    value = re.sub(r"<[^>]+>", "", value)
    return normalize_text(html.unescape(value))


def parse_checklists() -> dict[str, dict[str, object]]:
    source = GUIDE_SOURCE.read_text(encoding="utf-8")
    section_pattern = re.compile(
        r'<section aria-labelledby="solo-checklist-(?P<id>[^"]+)">\s*'
        r'<h3[^>]*>(?P<title>[\s\S]*?)</h3>[\s\S]*?'
        r'<ul class="fpw-solo-checklist">(?P<body>[\s\S]*?)</ul>\s*</section>',
        re.IGNORECASE,
    )
    item_pattern = re.compile(
        r'<li><label><input type="checkbox"><span>(?P<item>[\s\S]*?)</span></label></li>',
        re.IGNORECASE,
    )
    parsed: dict[str, dict[str, object]] = {}
    for match in section_pattern.finditer(source):
        group_id = match.group("id")
        parsed[group_id] = {
            "title": strip_markup(match.group("title")),
            "items": [strip_markup(item.group("item")) for item in item_pattern.finditer(match.group("body"))],
        }

    if set(parsed) != set(EXPECTED_COUNTS):
        raise ValueError(f"Checklist groups differ from expected source: {sorted(parsed)}")
    for group_id, expected_count in EXPECTED_COUNTS.items():
        actual_count = len(parsed[group_id]["items"])
        if actual_count != expected_count:
            raise ValueError(f"Checklist {group_id} has {actual_count} items; expected {expected_count}")
    if sum(len(group["items"]) for group in parsed.values()) != 84:
        raise ValueError("Checklist total must remain exactly 84")
    return parsed


class Checkbox(Flowable):
    def __init__(self, size: float = 9.0):
        super().__init__()
        self.size = size

    def wrap(self, avail_width: float, avail_height: float) -> tuple[float, float]:
        return self.size + 2, self.size + 2

    def draw(self) -> None:
        self.canv.setStrokeColor(TEAL)
        self.canv.setLineWidth(1.1)
        self.canv.rect(1, 1, self.size, self.size, fill=0, stroke=1)


class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, metadata: dict[str, str], footer_title: str, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states: list[dict[str, object]] = []
        self._footer_title = footer_title
        self.setTitle(metadata["title"])
        self.setAuthor(metadata["author"])
        self.setSubject(metadata["subject"])
        self.setKeywords(metadata["keywords"])
        self.setCreator("FloatPlanWizard deterministic ReportLab generator")

    def showPage(self) -> None:
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self) -> None:
        total_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_footer(total_pages)
            super().showPage()
        super().save()

    def _draw_footer(self, total_pages: int) -> None:
        width, _ = letter
        self.saveState()
        self.setStrokeColor(LINE)
        self.setLineWidth(0.5)
        self.line(0.55 * inch, 0.53 * inch, width - 0.55 * inch, 0.53 * inch)
        self.setFont("Helvetica", 7)
        self.setFillColor(MUTED)
        self.drawString(0.55 * inch, 0.34 * inch, "FloatPlanWizard.com")
        self.drawCentredString(width / 2, 0.34 * inch, self._footer_title)
        self.drawRightString(width - 0.55 * inch, 0.34 * inch, f"Page {self._pageNumber} of {total_pages}")
        self.restoreState()


def page_frame(canv: canvas.Canvas, doc: SimpleDocTemplate) -> None:
    width, height = letter
    canv.saveState()
    canv.setFillColor(NAVY)
    canv.rect(0, height - 0.39 * inch, width, 0.39 * inch, fill=1, stroke=0)
    canv.setFillColor(CYAN)
    canv.rect(0, height - 0.42 * inch, width, 0.03 * inch, fill=1, stroke=0)
    canv.setFont("Helvetica-Bold", 7.6)
    canv.setFillColor(WHITE)
    canv.drawString(0.55 * inch, height - 0.25 * inch, SERIES_LABEL.upper())
    canv.restoreState()


def build_styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "Series": ParagraphStyle(
            "Series",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=8,
            leading=10,
            textColor=TEAL,
            alignment=TA_LEFT,
            spaceAfter=4,
            uppercase=True,
        ),
        "Title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=20,
            leading=22,
            textColor=NAVY,
            alignment=TA_LEFT,
            spaceAfter=5,
        ),
        "Subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=12.5,
            textColor=TEAL,
            spaceAfter=7,
        ),
        "Purpose": ParagraphStyle(
            "Purpose",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10,
            leading=13,
            textColor=INK,
        ),
        "H2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=13,
            leading=15,
            textColor=NAVY,
            spaceBefore=8,
            spaceAfter=4,
            keepWithNext=True,
        ),
        "H3": ParagraphStyle(
            "H3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=12,
            textColor=TEAL,
            spaceBefore=5,
            spaceAfter=3,
            keepWithNext=True,
        ),
        "Body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=11.7,
            textColor=INK,
            spaceAfter=4.5,
        ),
        "Bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.8,
            leading=11.4,
            textColor=INK,
            leftIndent=16,
            firstLineIndent=0,
            bulletIndent=5,
            spaceAfter=2,
        ),
        "Callout": ParagraphStyle(
            "Callout",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=9.8,
            leading=12.5,
            textColor=DEEP_BLUE,
        ),
        "Checklist": ParagraphStyle(
            "Checklist",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.7,
            leading=11.2,
            textColor=INK,
        ),
        "Small": ParagraphStyle(
            "Small",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=7.3,
            leading=9,
            textColor=MUTED,
            spaceAfter=3,
        ),
        "Link": ParagraphStyle(
            "Link",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.5,
            leading=11,
            textColor=TEAL,
            leftIndent=10,
            bulletIndent=0,
            spaceAfter=2,
        ),
        "CenterSmall": ParagraphStyle(
            "CenterSmall",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=8,
            leading=10,
            textColor=TEAL,
            alignment=TA_CENTER,
        ),
    }


def text_paragraph(value: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(html.escape(value), style)


def heading_and_first(heading: str, first: str, styles: dict[str, ParagraphStyle]) -> KeepTogether:
    return KeepTogether([
        text_paragraph(heading, styles["H3"]),
        text_paragraph(first, styles["Body"]),
    ])


def callout_box(value: str, styles: dict[str, ParagraphStyle]) -> Table:
    table = Table([[Paragraph(f"<b>{html.escape(value)}</b>", styles["Callout"])]], colWidths=[7.15 * inch])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PALE_CYAN),
        ("BOX", (0, 0), (-1, -1), 0.8, CYAN),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return table


def checklist_table(items: list[str], styles: dict[str, ParagraphStyle]) -> Table:
    data = [[Checkbox(), text_paragraph(item, styles["Checklist"])] for item in items]
    table = Table(data, colWidths=[0.22 * inch, 6.93 * inch], repeatRows=0, splitByRow=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (0, -1), 0),
        ("RIGHTPADDING", (0, 0), (0, -1), 4),
        ("LEFTPADDING", (1, 0), (1, -1), 0),
        ("RIGHTPADDING", (1, 0), (1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 2.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5),
        ("LINEBELOW", (0, 0), (-1, -2), 0.25, colors.HexColor("#dce6eb")),
    ]))
    return table


def key_things_box(items: list[str], styles: dict[str, ParagraphStyle]) -> Table:
    content = [text_paragraph("Key things to remember", styles["H3"])]
    content.extend(Paragraph(html.escape(item), styles["Bullet"], bulletText="-") for item in items)
    table = Table([[content]], colWidths=[7.15 * inch])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PALE_BLUE),
        ("BOX", (0, 0), (-1, -1), 0.6, LINE),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return table


def logo_banner() -> Table:
    logo = Image(str(LOGO_PATH), width=4.4 * inch, height=1.1 * inch)
    table = Table([[logo]], colWidths=[7.15 * inch])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), NAVY),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]))
    return table


def build_story(pamphlet: dict[str, object], checklist: dict[str, object], styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    story: list[Flowable] = [
        logo_banner(),
        Spacer(1, 6),
        text_paragraph(SERIES_LABEL, styles["Series"]),
        text_paragraph(str(pamphlet["title"]), styles["Title"]),
    ]
    if pamphlet.get("subtitle"):
        story.append(text_paragraph(str(pamphlet["subtitle"]), styles["Subtitle"]))

    purpose_table = Table(
        [[text_paragraph(str(pamphlet["purpose"]), styles["Purpose"])]],
        colWidths=[7.15 * inch],
    )
    purpose_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PALE_CYAN),
        ("LINEBEFORE", (0, 0), (0, -1), 4, CYAN),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.extend([purpose_table, Spacer(1, 7), text_paragraph("Why this checklist matters", styles["H2"])])
    story.extend(text_paragraph(value, styles["Body"]) for value in pamphlet["why"])

    for value in pamphlet.get("callouts", []):
        story.extend([Spacer(1, 3), callout_box(str(value), styles), Spacer(1, 3)])

    story.append(text_paragraph("What to think about", styles["H2"]))
    for section in pamphlet["sections"]:
        paragraphs = section.get("paragraphs", [])
        if paragraphs:
            story.append(heading_and_first(section["heading"], paragraphs[0], styles))
            story.extend(text_paragraph(value, styles["Body"]) for value in paragraphs[1:])
        else:
            story.append(text_paragraph(section["heading"], styles["H3"]))
        story.extend(Paragraph(html.escape(item), styles["Bullet"], bulletText="-") for item in section.get("bullets", []))

    story.extend([Spacer(1, 3), key_things_box(pamphlet["key_things"], styles), Spacer(1, 5)])
    story.append(text_paragraph(f'{checklist["title"]} checklist', styles["H2"]))
    story.append(text_paragraph(
        "Use this checklist before departure. Marking an item does not replace the operator's responsibility to confirm what is appropriate and required for the actual vessel, activity, location, and conditions.",
        styles["Body"],
    ))
    story.extend([Spacer(1, 2), checklist_table(checklist["items"], styles), Spacer(1, 7)])

    story.append(text_paragraph("Related guidance", styles["H2"]))
    for label, url in pamphlet["related"]:
        link = f'<link href="{html.escape(url)}" color="#0b6f78"><u>{html.escape(label)}</u></link>'
        story.append(Paragraph(link, styles["Link"], bulletText="-"))

    story.append(text_paragraph("Turn the checklist into a real trip plan", styles["H2"]))
    story.append(text_paragraph(COMMON_PROMOTION, styles["Body"]))
    story.append(text_paragraph(
        "For solo boaters, FloatPlanWizard puts the information a shore contact may need into one organized workflow: vessel and operator details, passengers when applicable, route, departure, destination, timing, shore contact, trip sharing, and supported scheduled check-in information.",
        styles["Body"],
    ))
    story.append(text_paragraph(
        "FloatPlanWizard is built specifically to make float-plan preparation, sharing, and automated trip monitoring practical for recreational boaters - including people who boat alone.",
        styles["Body"],
    ))
    story.append(text_paragraph(MONITORING_LIMIT, styles["Small"]))

    site_link = f'<link href="{SITE_URL}" color="#0b6f78"><u>FloatPlanWizard.com</u></link>'
    guide_link = f'<link href="{GUIDE_URL}" color="#0b6f78"><u>Read the complete Solo Boating Safety Guide</u></link>'
    links_table = Table(
        [[Paragraph(site_link, styles["CenterSmall"]), Paragraph(guide_link, styles["CenterSmall"])]],
        colWidths=[3.1 * inch, 4.05 * inch],
    )
    links_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PALE_CYAN),
        ("BOX", (0, 0), (-1, -1), 0.6, CYAN),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.extend([Spacer(1, 3), links_table, Spacer(1, 7)])

    story.append(HRFlowable(width="100%", thickness=0.6, color=LINE, spaceBefore=2, spaceAfter=6))
    story.append(Paragraph(f"<b>Safety note:</b> {html.escape(DISCLAIMER)}", styles["Small"]))
    story.append(text_paragraph(f"Published {PUBLICATION_DATE}", styles["Small"]))
    return story


def add_pdf_metadata(pdf_path: Path, pamphlet: dict[str, object]) -> None:
    reader = PdfReader(str(pdf_path))
    writer = PdfWriter()
    writer.clone_document_from_reader(reader)
    writer.add_metadata({
        "/Title": str(pamphlet["title"]),
        "/Author": "FloatPlanWizard",
        "/Subject": f'{SERIES_LABEL}: {pamphlet["purpose"]}',
        "/Keywords": "FloatPlanWizard, solo boating, boating safety, float plan, checklist",
        "/Creator": "FloatPlanWizard deterministic ReportLab generator",
        "/Producer": "FloatPlanWizard",
    })
    writer.root_object[NameObject("/Lang")] = TextStringObject("en-US")
    rewritten = pdf_path.with_suffix(".metadata.pdf")
    with rewritten.open("wb") as output_stream:
        writer.write(output_stream)
    rewritten.replace(pdf_path)


def generate_one(pamphlet: dict[str, object], checklist: dict[str, object], styles: dict[str, ParagraphStyle]) -> Path:
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
    output_path = DOWNLOADS_DIR / str(pamphlet["filename"])
    working_path = output_path.with_suffix(".working.pdf")
    metadata = {
        "title": str(pamphlet["title"]),
        "author": "FloatPlanWizard",
        "subject": f'{SERIES_LABEL}: {pamphlet["purpose"]}',
        "keywords": "FloatPlanWizard, solo boating, boating safety, float plan, checklist",
    }
    document = SimpleDocTemplate(
        str(working_path),
        pagesize=letter,
        rightMargin=0.425 * inch,
        leftMargin=0.425 * inch,
        topMargin=0.50 * inch,
        bottomMargin=0.62 * inch,
        title=str(pamphlet["title"]),
        author="FloatPlanWizard",
        subject=metadata["subject"],
    )
    document.build(
        build_story(pamphlet, checklist, styles),
        onFirstPage=page_frame,
        onLaterPages=page_frame,
        canvasmaker=partial(
            NumberedCanvas,
            metadata=metadata,
            footer_title=str(pamphlet["short_title"]),
        ),
    )
    working_path.replace(output_path)
    add_pdf_metadata(output_path, pamphlet)
    return output_path


def extracted_pdf_text(reader: PdfReader) -> str:
    return normalize_text(" ".join((page.extract_text() or "") for page in reader.pages))


def validate_pdfs(checklists: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    results = []
    total_items = 0
    for pamphlet in PAMPHLETS:
        pdf_path = DOWNLOADS_DIR / str(pamphlet["filename"])
        if not pdf_path.exists() or pdf_path.read_bytes()[:4] != b"%PDF":
            raise ValueError(f"Missing or invalid PDF: {pdf_path}")
        reader = PdfReader(str(pdf_path))
        page_count = len(reader.pages)
        if not 2 <= page_count <= 5:
            raise ValueError(f"{pdf_path.name} has {page_count} pages; expected 2-5")
        for page_index, page in enumerate(reader.pages, start=1):
            media_box = page.mediabox
            if abs(float(media_box.width) - 612) > 0.5 or abs(float(media_box.height) - 792) > 0.5:
                raise ValueError(f"{pdf_path.name} page {page_index} is not US Letter")
            if len(normalize_text(page.extract_text() or "")) < 120:
                raise ValueError(f"{pdf_path.name} page {page_index} appears blank")

        metadata = reader.metadata or {}
        if metadata.get("/Title") != pamphlet["title"]:
            raise ValueError(f"Incorrect title metadata in {pdf_path.name}")
        if metadata.get("/Author") != "FloatPlanWizard":
            raise ValueError(f"Incorrect author metadata in {pdf_path.name}")
        if reader.trailer["/Root"].get("/Lang") != "en-US":
            raise ValueError(f"Missing en-US document language in {pdf_path.name}")

        checklist = checklists[str(pamphlet["group_id"])]
        item_count = len(checklist["items"])
        total_items += item_count
        pdf_text = extracted_pdf_text(reader)
        missing_items = [item for item in checklist["items"] if normalize_text(str(item)) not in pdf_text]
        if missing_items:
            raise ValueError(f"Checklist mismatch in {pdf_path.name}: {missing_items}")
        for forbidden in [
            "professional monitoring",
            "guaranteed live tracking",
            "guaranteed current location",
            "dispatches rescue",
            "contacts emergency services",
        ]:
            if forbidden in pdf_text.lower() and f"not {forbidden}" not in pdf_text.lower():
                raise ValueError(f"Unsupported phrase in {pdf_path.name}: {forbidden}")

        link_count = sum(
            1
            for page in reader.pages
            for annotation in (page.get("/Annots") or [])
            if annotation.get_object().get("/Subtype") == "/Link"
        )
        if link_count < 3:
            raise ValueError(f"Expected working link annotations in {pdf_path.name}")
        results.append({
            "filename": pdf_path.name,
            "title": pamphlet["title"],
            "pages": page_count,
            "items": item_count,
            "bytes": pdf_path.stat().st_size,
            "links": link_count,
        })

    if total_items != 84:
        raise ValueError(f"Generated checklist total is {total_items}; expected 84")
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing generated PDFs without regenerating")
    args = parser.parse_args()

    if not GUIDE_SOURCE.exists():
        raise SystemExit(f"Guide source not found: {GUIDE_SOURCE}")
    if not LOGO_PATH.exists():
        raise SystemExit(f"Print logo not found: {LOGO_PATH}")

    checklists = parse_checklists()
    if not args.check:
        styles = build_styles()
        for pamphlet in PAMPHLETS:
            generate_one(pamphlet, checklists[str(pamphlet["group_id"])], styles)

    results = validate_pdfs(checklists)
    for result in results:
        print(
            f'{result["filename"]}: {result["pages"]} pages, '
            f'{result["items"]} checklist items, {result["links"]} links, '
            f'{result["bytes"]} bytes'
        )
    print(f"Validated {len(results)} PDFs with {sum(result['items'] for result in results)} checklist items total.")


if __name__ == "__main__":
    main()
