#!/usr/bin/env python3
"""Build the individual fillable Common Boating Emergencies cards."""

from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.pdfbase import pdfmetrics

from build_emergency_cards import (
    INK,
    LINE,
    MID,
    NAVY,
    PALE,
    WHITE,
    TaggedCanvas,
    add_pdf_structure,
    draw_paragraph,
    register_fonts,
    set_metadata,
    style,
)


ROOT = Path(__file__).resolve().parents[3]
OUTPUTS = {
    "pace": ROOT / "downloads/first-60-seconds-pace.pdf",
    "mayday": ROOT / "downloads/mayday-vhf-channel-16-script.pdf",
    "pan_pan": ROOT / "downloads/pan-pan-vhf-channel-16-script.pdf",
    "boat_fields": ROOT / "downloads/boat-specific-emergency-fields.pdf",
}

TEAL = colors.HexColor("#168F8A")
RED = colors.HexColor("#B83B36")
AMBER = colors.HexColor("#A96808")
BLUE = colors.HexColor("#176A93")
FIELD_FILL = colors.HexColor("#FAFCFD")
FIELD_BORDER = colors.HexColor("#71818D")

PAGE_WIDTH, PAGE_HEIGHT = letter
SAFE_MARGIN = 42
CONTENT_LEFT = SAFE_MARGIN
CONTENT_WIDTH = PAGE_WIDTH - (SAFE_MARGIN * 2)
FOOTER_TOP = 78

COMMON_HEADER = style(
    "IndividualCommonHeader", size=10.5, leading=12, color=NAVY, bold=True
)
OVERLINE = style(
    "IndividualOverline", size=9.5, leading=11, color=TEAL, bold=True
)
CARD_TITLE = style(
    "IndividualCardTitle", size=20, leading=23, color=NAVY, bold=True
)
BODY = style("IndividualBody", size=11.2, leading=14.2)
BODY_BOLD = style("IndividualBodyBold", size=11.2, leading=14.2, bold=True)
BODY_SMALL = style("IndividualBodySmall", size=10.5, leading=13.5)
ITEM_HEADING = style(
    "IndividualItemHeading", size=12.2, leading=14, color=NAVY, bold=True
)
FOOTER = style("IndividualFooter", size=8.8, leading=11, color=MID, alignment=1)
SITE_FOOTER = style(
    "IndividualSiteFooter", size=9.2, leading=11, color=NAVY, bold=True, alignment=1
)

PACE_ITEMS = (
    ("P — People", "Life jackets on. Count everyone. Treat immediate injury. Assign jobs."),
    (
        "A — Assess",
        "Position &bull; people aboard &bull; weather/drift &bull; fire/fuel &bull; flooding &bull; propulsion/steering &bull; nearby hazards.",
    ),
    (
        "C — Control",
        "Neutral/stop propulsion when needed. Stop leak/fire/fuel only if safe. Anchor only if suitable. Keep lookout.",
    ),
    (
        "E — Emergency call",
        "Mayday for grave/imminent danger. Pan-Pan for urgent safety problem. VHF Ch 16; DSC first if configured. Give position early.",
    ),
)

FOOTER_TEXT = (
    "Keep this card where the operator and passengers can reach it. Follow official Coast Guard and emergency-responder instructions."
)


def new_canvas(path: Path, title: str) -> TaggedCanvas:
    path.parent.mkdir(parents=True, exist_ok=True)
    pdf = TaggedCanvas(
        str(path),
        pagesize=letter,
        pageCompression=1,
        invariant=1,
        initialFontName="CardRegular",
        initialFontSize=11,
        initialLeading=14,
    )
    set_metadata(
        pdf,
        f"FloatPlanWizard Boating Emergency Quick Reference - {title}",
        f"One-page boating emergency quick-reference card: {title}.",
    )
    return pdf


def draw_page_frame(pdf: TaggedCanvas, accent: colors.Color) -> None:
    with pdf.artifact():
        pdf.saveState()
        pdf.setFillColor(WHITE)
        pdf.rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, fill=1, stroke=0)
        pdf.setStrokeColor(LINE)
        pdf.setLineWidth(0.8)
        pdf.roundRect(
            SAFE_MARGIN,
            SAFE_MARGIN,
            CONTENT_WIDTH,
            PAGE_HEIGHT - (SAFE_MARGIN * 2),
            8,
            fill=0,
            stroke=1,
        )
        pdf.setFillColor(accent)
        pdf.rect(SAFE_MARGIN, PAGE_HEIGHT - SAFE_MARGIN - 7, CONTENT_WIDTH, 7, fill=1, stroke=0)
        pdf.restoreState()


def draw_header(
    pdf: TaggedCanvas,
    title: str,
    accent: colors.Color,
    overline: str | None = None,
) -> float:
    draw_page_frame(pdf, accent)
    top = PAGE_HEIGHT - SAFE_MARGIN - 22
    height = draw_paragraph(
        pdf,
        "FloatPlanWizard Boating Emergency Quick Reference",
        COMMON_HEADER,
        CONTENT_LEFT + 14,
        top,
        CONTENT_WIDTH - 28,
        18,
        role="H1",
    )
    top -= height + 7
    if overline:
        overline_style = OVERLINE.clone(f"Overline-{title}")
        overline_style.textColor = accent
        height = draw_paragraph(
            pdf,
            overline,
            overline_style,
            CONTENT_LEFT + 14,
            top,
            CONTENT_WIDTH - 28,
            16,
        )
        top -= height + 4
    height = draw_paragraph(
        pdf,
        title,
        CARD_TITLE,
        CONTENT_LEFT + 14,
        top,
        CONTENT_WIDTH - 28,
        52,
        role="H2",
    )
    top -= height + 9
    with pdf.artifact():
        pdf.setStrokeColor(accent)
        pdf.setLineWidth(1.2)
        pdf.line(CONTENT_LEFT + 14, top, CONTENT_LEFT + CONTENT_WIDTH - 14, top)
    return top - 14


def draw_footer(pdf: TaggedCanvas) -> None:
    with pdf.artifact():
        pdf.setStrokeColor(LINE)
        pdf.setLineWidth(0.7)
        pdf.line(
            CONTENT_LEFT + 14,
            FOOTER_TOP + 15,
            CONTENT_LEFT + CONTENT_WIDTH - 14,
            FOOTER_TOP + 15,
        )
    draw_paragraph(
        pdf,
        FOOTER_TEXT,
        FOOTER,
        CONTENT_LEFT + 14,
        FOOTER_TOP + 9,
        CONTENT_WIDTH - 28,
        26,
    )
    draw_paragraph(
        pdf,
        "FloatPlanWizard.com",
        SITE_FOOTER,
        CONTENT_LEFT + 14,
        57,
        CONTENT_WIDTH - 28,
        13,
    )


def draw_inline_text(
    pdf: TaggedCanvas,
    text: str,
    x: float,
    baseline: float,
    *,
    bold: bool = False,
    size: float = 11.2,
    color: colors.Color = INK,
    role: str = "P",
) -> float:
    font_name = "CardBold" if bold else "CardRegular"
    with pdf.marked_content(role):
        pdf.saveState()
        pdf.setFillColor(color)
        pdf.setFont(font_name, size)
        pdf.drawString(x, baseline, text)
        pdf.restoreState()
    return pdfmetrics.stringWidth(text, font_name, size)


def add_text_field(
    pdf: TaggedCanvas,
    *,
    name: str,
    tooltip: str,
    x: float,
    top: float,
    width: float,
    height: float = 20,
    multiline: bool = False,
) -> None:
    if width < 42:
        raise RuntimeError(f"Field is too narrow: {name} ({width})")
    pdf.acroForm.textfield(
        name=name,
        tooltip=tooltip,
        value="",
        x=x,
        y=top - height,
        width=width,
        height=height,
        borderStyle="solid",
        borderWidth=1,
        borderColor=FIELD_BORDER,
        fillColor=FIELD_FILL,
        textColor=INK,
        forceBorder=True,
        fontName="Helvetica",
        fontSize=10.5,
        fieldFlags=4096 if multiline else 0,
    )


def draw_inline_field_row(
    pdf: TaggedCanvas,
    top: float,
    parts: tuple[tuple, ...],
    *,
    height: float = 20,
    gap_after: float = 7,
) -> float:
    x = CONTENT_LEFT + 14
    baseline = top - 14
    for part in parts:
        if part[0] == "text":
            _, text, bold = part
            x += draw_inline_text(pdf, text, x, baseline, bold=bold)
        elif part[0] == "field":
            _, name, tooltip, width, multiline = part
            add_text_field(
                pdf,
                name=name,
                tooltip=tooltip,
                x=x,
                top=top,
                width=width,
                height=height,
                multiline=multiline,
            )
            x += width
        else:
            raise ValueError(f"Unsupported row part: {part[0]}")
    if x > CONTENT_LEFT + CONTENT_WIDTH - 14 + 0.1:
        raise RuntimeError(f"Inline row exceeds the safe content width: {parts}")
    return top - height - gap_after


def finish_pdf(pdf: TaggedCanvas, output: Path) -> None:
    pdf.showPage()
    pdf.save()
    add_pdf_structure(output, pdf.finalized_tag_pages())


def build_pace() -> None:
    output = OUTPUTS["pace"]
    title = "First 60 seconds — P.A.C.E."
    pdf = new_canvas(output, title)
    with pdf.structure("Sect"):
        top = draw_header(pdf, title, TEAL, "Front")
        cell_height = 104
        for heading, body in PACE_ITEMS:
            cell_bottom = top - cell_height
            if cell_bottom < FOOTER_TOP + 26:
                raise RuntimeError("P.A.C.E. card content does not fit one Letter page.")
            with pdf.artifact():
                pdf.setFillColor(PALE)
                pdf.setStrokeColor(LINE)
                pdf.roundRect(
                    CONTENT_LEFT + 14,
                    cell_bottom,
                    CONTENT_WIDTH - 28,
                    cell_height,
                    6,
                    fill=1,
                    stroke=1,
                )
                pdf.setFillColor(TEAL)
                pdf.rect(CONTENT_LEFT + 14, cell_bottom, 6, cell_height, fill=1, stroke=0)
            with pdf.structure("L"):
                with pdf.structure("LI"):
                    heading_height = draw_paragraph(
                        pdf,
                        heading,
                        ITEM_HEADING,
                        CONTENT_LEFT + 34,
                        top - 14,
                        CONTENT_WIDTH - 62,
                        20,
                        role="H3",
                    )
                    with pdf.structure("LBody"):
                        draw_paragraph(
                            pdf,
                            body,
                            BODY,
                            CONTENT_LEFT + 34,
                            top - 18 - heading_height,
                            CONTENT_WIDTH - 62,
                            56,
                        )
            top = cell_bottom - 10
        draw_footer(pdf)
    finish_pdf(pdf, output)


def build_mayday() -> None:
    output = OUTPUTS["mayday"]
    title = "Mayday voice script — VHF Channel 16"
    pdf = new_canvas(output, title)
    with pdf.structure("Sect"):
        top = draw_header(pdf, title, RED, "Back")
        top -= draw_paragraph(
            pdf,
            "<b>MAYDAY, MAYDAY, MAYDAY</b>",
            BODY_BOLD,
            CONTENT_LEFT + 14,
            top,
            CONTENT_WIDTH - 28,
            18,
        ) + 6
        top = draw_inline_field_row(pdf, top, (
            ("text", "THIS IS ", True),
            ("field", "boat_name", "Boat name", 270, False),
            ("text", " three times", False),
        ))
        top = draw_inline_field_row(pdf, top, (
            ("text", "Call sign/registration ", False),
            ("field", "call_sign_or_registration", "Call sign or vessel registration", 314, False),
        ))
        top = draw_inline_field_row(pdf, top, (
            ("text", "MAYDAY ", True),
            ("field", "boat_name_repeat", "Boat name repeated after Mayday", 350, False),
        ))
        top = draw_inline_field_row(pdf, top, (
            ("text", "POSITION ", True),
            ("field", "position", "Latitude and longitude or clear location", 350, False),
        ))
        top = draw_inline_field_row(pdf, top, (
            ("text", "WE ARE ", True),
            ("field", "nature_of_distress", "Nature of distress", 364, True),
        ), height=30)
        top = draw_inline_field_row(pdf, top, (
            ("text", "WE NEED ", True),
            ("field", "assistance_requested", "Assistance requested", 360, True),
        ), height=30)
        top = draw_inline_field_row(pdf, top, (
            ("field", "people_aboard", "Number of people aboard", 76, False),
            ("text", " PEOPLE ABOARD; ", True),
            ("field", "injuries_or_medical", "Injuries or medical information", 250, False),
        ))
        top = draw_inline_field_row(pdf, top, (
            ("text", "BOAT IS ", True),
            ("field", "boat_description", "Boat length, type, and color", 360, False),
        ))
        top = draw_inline_field_row(pdf, top, (
            ("text", "OTHER: ", True),
            ("field", "other_information", "Drift, hazards, PFDs, beacon, or other useful information", 370, True),
        ), height=38)
        top -= draw_paragraph(
            pdf, "<b>OVER</b>", BODY_BOLD, CONTENT_LEFT + 14, top, CONTENT_WIDTH - 28, 18
        ) + 8
        support = (
            "Stay by the radio. Repeat if no answer. Follow Coast Guard instructions. "
            "If time is critical, say position and danger before lower-priority detail."
        )
        if top - 50 < FOOTER_TOP + 26:
            raise RuntimeError("Mayday card content does not fit one Letter page.")
        draw_paragraph(pdf, support, BODY_SMALL, CONTENT_LEFT + 14, top, CONTENT_WIDTH - 28, 50)
        draw_footer(pdf)
    finish_pdf(pdf, output)


def build_pan_pan() -> None:
    output = OUTPUTS["pan_pan"]
    title = "PAN-PAN voice script — VHF Channel 16"
    pdf = new_canvas(output, title)
    with pdf.structure("Sect"):
        top = draw_header(pdf, title, AMBER, "URGENT — NOT DISTRESS")
        for signal in (
            "<b>PAN-PAN, PAN-PAN, PAN-PAN</b>",
            "<b>ALL STATIONS, ALL STATIONS, ALL STATIONS</b>",
        ):
            top -= draw_paragraph(
                pdf, signal, BODY_BOLD, CONTENT_LEFT + 14, top, CONTENT_WIDTH - 28, 18
            ) + 3
        top = draw_inline_field_row(pdf, top, (
            ("text", "THIS IS ", True),
            ("field", "boat_name", "Boat name", 270, False),
            ("text", " three times", False),
        ), gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("text", "Call sign/registration ", False),
            ("field", "call_sign_or_registration", "Call sign or vessel registration", 314, False),
        ), gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("text", "PAN-PAN ", True),
            ("field", "boat_name_repeat", "Boat name repeated after Pan-Pan", 346, False),
        ), gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("text", "POSITION ", True),
            ("field", "position", "Latitude and longitude or clear location", 350, False),
        ), gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("text", "WE HAVE ", True),
            ("field", "nature_of_urgent_problem", "Nature of urgent safety problem", 350, True),
        ), height=30, gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("text", "WE REQUIRE ", True),
            ("field", "assistance_requested", "Assistance requested", 330, True),
        ), height=30, gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("field", "people_aboard", "Number of people aboard", 76, False),
            ("text", " PEOPLE ABOARD; ", True),
            ("field", "injuries_or_medical", "Injuries or medical information", 250, False),
        ), gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("text", "BOAT IS ", True),
            ("field", "boat_description", "Boat length, type, and color", 360, False),
        ), gap_after=5)
        top = draw_inline_field_row(pdf, top, (
            ("text", "OTHER: ", True),
            ("field", "other_information", "Drift, nearby hazards, PFDs, beacon, or other useful information", 370, True),
        ), height=38, gap_after=5)
        top -= draw_paragraph(
            pdf, "<b>OVER</b>", BODY_BOLD, CONTENT_LEFT + 14, top, CONTENT_WIDTH - 28, 18
        ) + 7
        support_paragraphs = (
            "Use PAN-PAN when the safety of the boat or a person is in jeopardy, but there is no grave and imminent danger. If the situation becomes grave and imminent, transmit MAYDAY instead.",
            "Stay by the radio. Repeat the call if no answer is received, and follow Coast Guard instructions.",
            "PAN-PAN is pronounced “pahn-pahn.”",
        )
        for text in support_paragraphs:
            height = draw_paragraph(
                pdf, text, BODY_SMALL, CONTENT_LEFT + 14, top, CONTENT_WIDTH - 28, 48
            )
            top -= height + 5
        if top < FOOTER_TOP + 24:
            raise RuntimeError("PAN-PAN card content does not fit one Letter page.")
        draw_footer(pdf)
    finish_pdf(pdf, output)


def build_boat_fields() -> None:
    output = OUTPUTS["boat_fields"]
    title = "Boat-specific fields"
    pdf = new_canvas(output, title)
    with pdf.structure("Sect"):
        top = draw_header(pdf, title, BLUE)
        top = draw_inline_field_row(pdf, top, (
            ("text", "Boat name: ", False),
            ("field", "boat_name", "Boat name", 400, False),
        ), height=23, gap_after=12)
        top = draw_inline_field_row(pdf, top, (
            ("text", "Registration/call sign: ", False),
            ("field", "call_sign_or_registration", "Registration or call sign", 330, False),
        ), height=23, gap_after=12)
        top = draw_inline_field_row(pdf, top, (
            ("text", "MMSI: ", False),
            ("field", "mmsi", "Maritime Mobile Service Identity number", 420, False),
        ), height=23, gap_after=12)
        top = draw_inline_field_row(pdf, top, (
            ("text", "Length/type/color: ", False),
            ("field", "boat_description", "Boat length, type, and color", 352, False),
        ), height=23, gap_after=14)
        top -= draw_paragraph(
            pdf,
            "Emergency equipment locations:",
            ITEM_HEADING,
            CONTENT_LEFT + 14,
            top,
            CONTENT_WIDTH - 28,
            20,
            role="H3",
        ) + 7
        for left_label, left_name, left_tooltip, right_label, right_name, right_tooltip in (
            ("VHF ", "vhf_location", "VHF radio location", " / EPIRB-PLB ", "epirb_plb_location", "EPIRB or PLB location"),
            ("first aid ", "first_aid_location", "First-aid kit location", " / extinguishers ", "extinguisher_location", "Fire extinguisher locations"),
        ):
            top = draw_inline_field_row(pdf, top, (
                ("text", left_label, False),
                ("field", left_name, left_tooltip, 160, False),
                ("text", right_label, False),
                ("field", right_name, right_tooltip, 154, False),
            ), height=23, gap_after=12)
        top = draw_inline_field_row(pdf, top, (
            ("text", "seacocks ", False),
            ("field", "seacock_location", "Seacock locations", 390, False),
        ), height=23, gap_after=16)
        top = draw_inline_field_row(pdf, top, (
            ("text", "Shore contact: ", False),
            ("field", "shore_contact_name", "Shore contact name", 176, False),
            ("text", " / phone: ", False),
            ("field", "shore_contact_phone", "Shore contact phone number", 158, False),
        ), height=23, gap_after=18)
        disclaimer = "P.A.C.E. is a FloatPlanWizard quick-recall framework; follow official responder instructions."
        height = draw_paragraph(
            pdf, disclaimer, BODY_SMALL, CONTENT_LEFT + 14, top, CONTENT_WIDTH - 28, 40
        )
        top -= height
        if top < FOOTER_TOP + 24:
            raise RuntimeError("Boat-specific fields card does not fit one Letter page.")
        draw_footer(pdf)
    finish_pdf(pdf, output)


def main() -> None:
    register_fonts()
    build_pace()
    build_mayday()
    build_pan_pan()
    build_boat_fields()
    for path in OUTPUTS.values():
        print(f"Built {path}")


if __name__ == "__main__":
    main()
