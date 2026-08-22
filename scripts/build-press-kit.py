#!/usr/bin/env python3
"""Build the synchronized FloatPlanWizard press PDFs and distribution ZIP."""

from __future__ import annotations

import shutil
import tempfile
import zipfile
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
PRESS_DIR = REPO_ROOT / "assets" / "press"
SOCIAL_IMAGE = REPO_ROOT / "assets" / "images" / "social" / "floatplanwizard-social-preview-20260730.png"
COLOR_LOGO = PRESS_DIR / "logo.png"
CONTACT_FILE = PRESS_DIR / "media-contact.txt"
README_FILE = PRESS_DIR / "README.txt"
RELEASE_PDF = PRESS_DIR / "floatplanwizard-launch-press-release.pdf"
FACT_SHEET_PDF = PRESS_DIR / "floatplanwizard-fact-sheet.pdf"
MEDIA_KIT_ZIP = PRESS_DIR / "floatplanwizard-media-kit.zip"

UPDATED_DATE = "August 20, 2026"
NAVY = colors.HexColor("#061725")
CYAN = colors.HexColor("#20D8D4")
MUTED = colors.HexColor("#536575")
LIGHT = colors.HexColor("#EAF3F7")
WHITE = colors.white

HOME_URL = "https://floatplanwizard.com"
SOLO_URL = f"{HOME_URL}/solo-boating-safety-guide/"
SHORE_URL = f"{HOME_URL}/shore-contact-overdue-boater/"
FUEL_URL = f"{HOME_URL}/boat-fuel-calculator/"
LOCKS_URL = f"{HOME_URL}/great-loop/locks/"
CONTACT_EMAIL = "support@floatplanwizard.com"


def _styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "kicker": ParagraphStyle(
            "Kicker",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=8.5,
            leading=10,
            textColor=CYAN,
            spaceAfter=5,
        ),
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=22,
            leading=25,
            textColor=NAVY,
            alignment=0,
            spaceAfter=7,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.2,
            leading=14.2,
            textColor=MUTED,
            spaceAfter=10,
        ),
        "date": ParagraphStyle(
            "Date",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=8.5,
            leading=10,
            textColor=MUTED,
            spaceAfter=8,
        ),
        "heading": ParagraphStyle(
            "Heading",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=13.2,
            leading=16,
            textColor=NAVY,
            spaceBefore=7,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9.1,
            leading=12.7,
            textColor=NAVY,
            spaceAfter=6,
        ),
        "small": ParagraphStyle(
            "Small",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.5,
            leading=11.5,
            textColor=NAVY,
            spaceAfter=4,
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.8,
            leading=11.8,
            leftIndent=2,
            textColor=NAVY,
        ),
        "quote": ParagraphStyle(
            "Quote",
            parent=base["BodyText"],
            fontName="Helvetica-Oblique",
            fontSize=9,
            leading=12.7,
            textColor=WHITE,
            spaceAfter=0,
        ),
        "fact_label": ParagraphStyle(
            "FactLabel",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=8.5,
            leading=11,
            textColor=NAVY,
        ),
        "fact_value": ParagraphStyle(
            "FactValue",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.5,
            leading=11,
            textColor=NAVY,
        ),
        "contact": ParagraphStyle(
            "Contact",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.5,
            textColor=NAVY,
        ),
        "footer": ParagraphStyle(
            "Footer",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=7.5,
            leading=9,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
    }


def _on_page(canvas, doc) -> None:
    canvas.saveState()
    width, height = letter
    canvas.setFillColor(NAVY)
    canvas.setFont("Helvetica-Bold", 8)
    canvas.drawString(0.72 * inch, height - 0.42 * inch, f"FloatPlanWizard Press & Media Kit | Updated {UPDATED_DATE}")
    canvas.setFillColor(CYAN)
    canvas.rect(0.72 * inch, height - 0.51 * inch, width - 1.44 * inch, 1.4, fill=1, stroke=0)
    canvas.setFillColor(MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(width - 0.72 * inch, height - 0.42 * inch, f"Page {doc.page}")
    canvas.setFont("Helvetica", 7.5)
    canvas.drawCentredString(width / 2, 0.34 * inch, HOME_URL)
    canvas.restoreState()


def _document(path: Path, title: str, subject: str) -> BaseDocTemplate:
    doc = BaseDocTemplate(
        str(path),
        pagesize=letter,
        leftMargin=0.72 * inch,
        rightMargin=0.72 * inch,
        topMargin=0.72 * inch,
        bottomMargin=0.58 * inch,
        title=title,
        author="FloatPlanWizard",
        subject=subject,
        keywords="FloatPlanWizard, float plan, recreational boating, solo boating, boating safety",
        pageCompression=1,
    )
    frame = Frame(
        doc.leftMargin,
        doc.bottomMargin,
        doc.width,
        doc.height,
        leftPadding=0,
        rightPadding=0,
        topPadding=0,
        bottomPadding=0,
    )
    doc.addPageTemplates([PageTemplate(id="press", frames=[frame], onPage=_on_page)])
    return doc


def _brand_logo() -> Image:
    return Image(str(COLOR_LOGO), width=2.5 * inch, height=0.625 * inch)


def _paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(text, style)


def _bullet_list(items: list[str], style: ParagraphStyle) -> ListFlowable:
    return ListFlowable(
        [ListItem(_paragraph(item, style), leftIndent=12) for item in items],
        bulletType="bullet",
        start="circle",
        bulletFontName="Helvetica",
        bulletFontSize=6,
        bulletColor=CYAN,
        leftIndent=14,
        bulletOffsetY=1,
        spaceAfter=5,
    )


def _quote_table(styles: dict[str, ParagraphStyle]) -> Table:
    quote = (
        '"Boating safety tools only help if people actually use them. I wanted a faster way to prepare and share a '
        'float plan without recreating the same information for every trip. FloatPlanWizard is built to give everyday '
        'boaters an easy way to plan a trip, share important details, and keep trusted contacts informed."<br/>'
        '<font name="Helvetica-Bold">- Larry Wald, Founder</font>'
    )
    table = Table([[_paragraph(quote, styles["quote"])]], colWidths=[7.06 * inch])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), NAVY),
                ("BOX", (0, 0), (-1, -1), 0.8, CYAN),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                ("TOPPADDING", (0, 0), (-1, -1), 9),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
            ]
        )
    )
    return table


def _contact_block(styles: dict[str, ParagraphStyle]) -> Table:
    contact = _paragraph(
        '<b>Larry Wald</b><br/>Owner / Developer<br/>FloatPlanWizard.com<br/>'
        f'Email: <link href="mailto:{CONTACT_EMAIL}" color="#087F86">{CONTACT_EMAIL}</link><br/>'
        f'Website: <link href="{HOME_URL}" color="#087F86">{HOME_URL}</link>',
        styles["contact"],
    )
    table = Table([[contact]], colWidths=[7.06 * inch])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), LIGHT),
                ("LINEBEFORE", (0, 0), (0, -1), 3, CYAN),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                ("TOPPADDING", (0, 0), (-1, -1), 9),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
            ]
        )
    )
    return table


def build_release_pdf() -> None:
    styles = _styles()
    doc = _document(
        RELEASE_PDF,
        "Solo Boater Builds FloatPlanWizard to Make Float Plans Easier and More Accessible to Recreational Boaters",
        "Updated FloatPlanWizard launch press release",
    )
    story = [
        _brand_logo(),
        Spacer(1, 8),
        _paragraph("FOR IMMEDIATE RELEASE", styles["kicker"]),
        _paragraph(
            "Solo Boater Builds FloatPlanWizard to Make Float Plans Easier and More Accessible to Recreational Boaters",
            styles["title"],
        ),
        _paragraph(f"Originally released June 7, 2026 | Updated {UPDATED_DATE}", styles["date"]),
        _paragraph(
            "A solo boater's personal safety need grew into a recreational-boating platform with free membership, "
            "optional Premium trips, and expanding public planning and safety resources.",
            styles["subtitle"],
        ),
        _paragraph(f"GULF HARBORS, Fla. - June 7, 2026 (updated {UPDATED_DATE})", styles["date"]),
        _paragraph(
            "FloatPlanWizard.com, a boating trip-planning and float-plan platform created by Gulf Harbors resident "
            "Larry Wald, launched to help recreational boaters prepare trips, send float plans, and share useful "
            "information with trusted contacts.",
            styles["body"],
        ),
        _paragraph(
            "Wald is a longtime recreational and solo boater with approximately 55 years on the water. He first built "
            "the concept because, when boating alone, he wanted a quick and practical way to tell his family or shore "
            "contact where he planned to go and provide useful information if he failed to return. FloatPlanWizard grew "
            "from that personal safety need into a broader recreational-boating planning and safety platform. Wald is "
            "also a retired professional web developer with approximately 30 years of professional web-development "
            "experience.",
            styles["body"],
        ),
        Spacer(1, 3),
        _quote_table(styles),
        PageBreak(),
        Spacer(1, 12),
        _paragraph("Free Membership with Optional Premium Trips", styles["heading"]),
        _paragraph(
            "FloatPlanWizard is designed to reduce the time and repetitive effort involved in creating, sharing, and "
            "monitoring a "
            "float plan. Membership is free, including full trip planning and Basic float-plan sending. Every new "
            "member receives one complimentary Premium Send Credit for one complete Premium trip. The credit is used "
            "on the first successful Premium Save &amp; Send.",
            styles["body"],
        ),
        _paragraph(
            "Free members can save vessel, operator, passenger, shore-contact, waypoint, and trip information and "
            "maintain multiple Draft float plans.",
            styles["body"],
        ),
        _paragraph(
            "After the complimentary credit is used, additional Premium trips can be purchased individually for "
            "$4.99, through Monthly Premium for $9.99/month, or through Annual Premium for $89/year. Individual "
            "Premium trip access currently lasts up to 21 days.",
            styles["body"],
        ),
        _paragraph(
            "Premium trips add <b>Active Cruise tools, Premium trip monitoring, and a private Trip page that can be "
            "shared with family and shore contacts so they can follow trip status and progress</b>. Route planning "
            "and Basic float-plan sending remain free.",
            styles["body"],
        ),
        _paragraph("New Free Public Boating Resources", styles["heading"]),
        _paragraph(
            "Since the original June launch, FloatPlanWizard has expanded its free public resources with a "
            f'<link href="{SOLO_URL}" color="#087F86">Solo Boating Safety Guide</link>, a '
            f'<link href="{SHORE_URL}" color="#087F86">Shore Contact / Overdue Boater Guide</link>, a '
            f'<link href="{FUEL_URL}" color="#087F86">Boat Fuel Calculator</link>, and Great Loop planning '
            f'libraries that include public <link href="{LOCKS_URL}" color="#087F86">lock information</link>. '
            "These resources extend the platform's safety and trip-planning mission beyond registered members.",
            styles["body"],
        ),
        _paragraph("Safety Notice", styles["heading"]),
        _paragraph(
            "FloatPlanWizard is not an emergency dispatch, rescue, or distress-response service. In an emergency, "
            "boaters should use official emergency channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB, "
            "flares, or other accepted emergency methods.",
            styles["body"],
        ),
        _paragraph("About FloatPlanWizard", styles["heading"]),
        _paragraph(
            "FloatPlanWizard.com is a recreational-boating trip-planning and float-plan platform built by a solo "
            "boater. Free membership includes route planning, saved boating and trip information, multiple Draft "
            "float plans, and Basic float-plan sending. Optional Premium trips add operational, monitoring, delivery, "
            "and sharing features, while public guides and planning tools remain available without an account.",
            styles["body"],
        ),
        _paragraph("Media Contact", styles["heading"]),
        _contact_block(styles),
    ]
    doc.build(story)


def build_fact_sheet_pdf() -> None:
    styles = _styles()
    doc = _document(
        FACT_SHEET_PDF,
        "FloatPlanWizard Fact Sheet",
        "Current FloatPlanWizard company, membership, founder, pricing, and public-resource facts",
    )
    facts = [
        ("Website", f'<link href="{HOME_URL}" color="#087F86">{HOME_URL}</link>'),
        ("Founder", "Larry Wald, Founder; longtime recreational and solo boater"),
        (
            "Founder bio",
            "Solo boater and retired professional web developer with approximately 55 years on the water and "
            "approximately 30 years of professional web-development experience.",
        ),
        ("Location", "Gulf Harbors, Florida"),
        ("Category", "Boating safety, float plans, and recreational-boating trip planning"),
        ("Audience", "Recreational boaters"),
        ("Membership", "Free planning and Basic sending, with optional Premium trips"),
    ]
    fact_rows = [
        [_paragraph(f"<b>{label}</b>", styles["fact_label"]), _paragraph(value, styles["fact_value"])]
        for label, value in facts
    ]
    fact_table = Table(fact_rows, colWidths=[1.12 * inch, 5.94 * inch], repeatRows=0)
    fact_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 0), (-1, -1), [colors.white, LIGHT]),
                ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#C8D7DE")),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story = [
        _brand_logo(),
        Spacer(1, 8),
        _paragraph("PRESS &amp; MEDIA KIT", styles["kicker"]),
        _paragraph("FloatPlanWizard Fact Sheet", styles["title"]),
        _paragraph(f"Updated {UPDATED_DATE}", styles["date"]),
        _paragraph(
            "FloatPlanWizard helps recreational boaters plan routes, organize trip details, send float plans, and "
            "keep trusted contacts informed, with free membership and optional Premium trip features.",
            styles["subtitle"],
        ),
        _paragraph("Quick Facts", styles["heading"]),
        fact_table,
        _paragraph("Why It Was Built", styles["heading"]),
        _paragraph(
            "As a solo boater, Larry Wald wanted a quick, practical way to tell his family or a shore contact where "
            "he was going, when he expected to return, and what information they would need if he failed to return. "
            "That personal safety need grew into FloatPlanWizard's broader recreational-boating planning and safety "
            "platform.",
            styles["small"],
        ),
        _paragraph("Current Membership Model", styles["heading"]),
        _bullet_list(
            [
                "Free membership, route planning, and Basic float-plan sending",
                "Saved vessel, operator, passenger, shore-contact, waypoint, and trip information",
                "One complimentary Premium Send Credit for every new member",
                "The complimentary credit is used on the first successful Premium Save &amp; Send",
                "Single Premium trip: $4.99",
                "Monthly Premium: $9.99/month",
                "Annual Premium: $89/year",
                "Single-trip Premium access lasts up to 21 days",
            ],
            styles["bullet"],
        ),
        PageBreak(),
        Spacer(1, 12),
        _paragraph("Free Public Boating Resources", styles["heading"]),
        _bullet_list(
            [
                f'<link href="{SOLO_URL}" color="#087F86">Solo Boating Safety Guide</link>',
                f'<link href="{SHORE_URL}" color="#087F86">Shore Contact / Overdue Boater Guide</link>',
                f'<link href="{FUEL_URL}" color="#087F86">Boat Fuel Calculator</link>',
                f'<link href="{LOCKS_URL}" color="#087F86">Great Loop Lock Library</link>',
            ],
            styles["bullet"],
        ),
        _paragraph("Suggested Story Angles", styles["heading"]),
        _bullet_list(
            [
                "Solo boater builds a float-plan platform from a personal family-safety need",
                "Saved information reduces the time and repetitive effort involved in future float plans",
                "Public guides help solo boaters and shore contacts prepare for overdue situations",
                "Great Loop planning libraries organize public lock and route information",
            ],
            styles["bullet"],
        ),
        _paragraph("Safety Notice", styles["heading"]),
        _paragraph(
            "FloatPlanWizard is not an emergency dispatch, rescue, or distress-response service. In an emergency, "
            "boaters should use official emergency channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB, "
            "flares, or other accepted emergency methods.",
            styles["body"],
        ),
        _paragraph("Media Contact", styles["heading"]),
        _contact_block(styles),
    ]
    doc.build(story)


def build_zip() -> None:
    entries = {
        RELEASE_PDF: RELEASE_PDF.name,
        FACT_SHEET_PDF: FACT_SHEET_PDF.name,
        COLOR_LOGO: "floatplanwizard-logo-color.png",
        SOCIAL_IMAGE: SOCIAL_IMAGE.name,
        CONTACT_FILE: CONTACT_FILE.name,
        README_FILE: README_FILE.name,
    }
    with tempfile.TemporaryDirectory(prefix="fpw-media-kit-") as temp_dir:
        temp_zip = Path(temp_dir) / MEDIA_KIT_ZIP.name
        with zipfile.ZipFile(temp_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for source, archive_name in entries.items():
                archive.write(source, arcname=archive_name)
        shutil.copyfile(temp_zip, MEDIA_KIT_ZIP)


def main() -> None:
    for required in (COLOR_LOGO, SOCIAL_IMAGE, CONTACT_FILE, README_FILE):
        if not required.is_file():
            raise FileNotFoundError(required)
    build_release_pdf()
    build_fact_sheet_pdf()
    build_zip()
    print(RELEASE_PDF)
    print(FACT_SHEET_PDF)
    print(MEDIA_KIT_ZIP)


if __name__ == "__main__":
    main()
