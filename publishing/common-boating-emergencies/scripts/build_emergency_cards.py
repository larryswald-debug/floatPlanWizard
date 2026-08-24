#!/usr/bin/env python3
"""Build the downloadable FloatPlanWizard boating emergency cards."""

from __future__ import annotations

from contextlib import contextmanager
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from pypdf.generic import (
    ArrayObject,
    BooleanObject,
    DictionaryObject,
    NameObject,
    NullObject,
    NumberObject,
    TextStringObject,
)
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.pdfdoc import PDFString
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph


ROOT = Path(__file__).resolve().parents[3]
OUTPUT_4X6 = ROOT / "downloads/floatplanwizard-boating-emergency-card-4x6.pdf"
OUTPUT_LETTER = ROOT / "downloads/floatplanwizard-boating-emergency-card-letter.pdf"

FONT_DIR = Path("/System/Library/Fonts/Supplemental")
FONT_REGULAR = FONT_DIR / "Arial Narrow.ttf"
FONT_BOLD = FONT_DIR / "Arial Narrow Bold.ttf"

NAVY = colors.HexColor("#08273D")
BLUE = colors.HexColor("#176A93")
ORANGE = colors.HexColor("#C94F28")
INK = colors.HexColor("#14212B")
MID = colors.HexColor("#52616C")
LINE = colors.HexColor("#AEBBC4")
PALE = colors.HexColor("#F3F7F9")
WHITE = colors.white

CARD_WIDTH = 6 * inch
CARD_HEIGHT = 4 * inch
REVISION = "Revision: August 22, 2026"
FOUR_BY_SIX_FOOTER = (
    "Revision: August 22, 2026 | Print at 100% / Actual Size | Short-edge duplex"
)

PACE_ITEMS = (
    ("P - People", "Life jackets on. Count everyone. Treat immediate injury. Assign jobs."),
    (
        "A - Assess",
        "Position &bull; people aboard &bull; weather/drift &bull; fire/fuel &bull; flooding &bull; propulsion/steering &bull; nearby hazards.",
    ),
    (
        "C - Control",
        "Neutral/stop propulsion when needed. Stop leak/fire/fuel only if safe. Anchor only if suitable. Keep lookout.",
    ),
    (
        "E - Emergency call",
        "Mayday for grave/imminent danger. Pan-Pan for urgent safety problem. DSC alert first if MMSI/GPS are configured; then voice on Ch 16. Give position early.",
    ),
)

MAYDAY_LINES = (
    "<b>MAYDAY, MAYDAY, MAYDAY</b>",
    "THIS IS <b>[BOAT NAME]</b> &times;3",
    "Call sign/registration <b>[________]</b>",
    "MAYDAY <b>[BOAT NAME]</b>",
    "POSITION <b>[lat/long or clear location]</b>",
    "WE ARE <b>[nature of distress]</b>",
    "WE NEED <b>[assistance]</b>",
    "<b>[number]</b> PEOPLE ABOARD; <b>[injuries/medical]</b>",
    "BOAT IS <b>[length/type/color]</b>",
    "OTHER: <b>[drift, hazards, PFDs, beacon]</b>",
    "<b>OVER</b>",
)

BOAT_FIELDS = (
    "Boat name: ____________________",
    "Registration/call sign: ____________________",
    "MMSI: ____________________",
    "Length/type/color: ____________________",
    "Emergency equipment locations:<br/>VHF ____ / EPIRB-PLB ____<br/>first aid ____ / extinguishers ____<br/>seacocks ____",
    "Shore contact: ____________________<br/>Phone: ____________________",
)


class TaggedCanvas(canvas.Canvas):
    """ReportLab canvas that records semantic structure and marked content."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.tag_pages: list[list[dict[str, object]]] = [[]]
        self._tag_stack: list[list[dict[str, object]]] = [self.tag_pages[0]]
        self._next_mcid = 0

    @contextmanager
    def structure(self, role: str):
        node: dict[str, object] = {"role": role, "children": []}
        self._tag_stack[-1].append(node)
        children = node["children"]
        if not isinstance(children, list):
            raise RuntimeError("Invalid PDF structure node.")
        self._tag_stack.append(children)
        try:
            yield
        finally:
            self._tag_stack.pop()

    @contextmanager
    def marked_content(self, role: str):
        mcid = self._next_mcid
        self._next_mcid += 1
        self._tag_stack[-1].append({"role": role, "mcid": mcid})
        self.addLiteral(f"/{role} <</MCID {mcid}>> BDC")
        try:
            yield
        finally:
            self.addLiteral("EMC")

    @contextmanager
    def artifact(self):
        self.addLiteral("/Artifact BMC")
        try:
            yield
        finally:
            self.addLiteral("EMC")

    def showPage(self) -> None:
        if len(self._tag_stack) != 1:
            raise RuntimeError("Unclosed PDF structure container at page boundary.")
        super().showPage()
        self.tag_pages.append([])
        self._tag_stack = [self.tag_pages[-1]]
        self._next_mcid = 0

    def finalized_tag_pages(self) -> list[list[dict[str, object]]]:
        pages = list(self.tag_pages)
        while pages and not pages[-1]:
            pages.pop()
        return pages


def add_pdf_structure(pdf_path: Path, tag_pages: list[list[dict[str, object]]]) -> None:
    """Attach a standard structure tree and parent tree to marked ReportLab pages."""
    reader = PdfReader(pdf_path, strict=True)
    writer = PdfWriter()
    writer.clone_document_from_reader(reader)
    if len(writer.pages) != len(tag_pages):
        raise RuntimeError(
            f"Tag plan/page mismatch for {pdf_path}: {len(tag_pages)} plans, "
            f"{len(writer.pages)} pages."
        )

    struct_root = DictionaryObject({NameObject("/Type"): NameObject("/StructTreeRoot")})
    struct_root_ref = writer._add_object(struct_root)
    parent_arrays: list[ArrayObject] = []

    for page_index, page in enumerate(writer.pages):
        max_mcid = -1

        def find_max_mcid(nodes: list[dict[str, object]]) -> None:
            nonlocal max_mcid
            for node in nodes:
                if "mcid" in node:
                    max_mcid = max(max_mcid, int(node["mcid"]))
                children = node.get("children")
                if isinstance(children, list):
                    find_max_mcid(children)

        find_max_mcid(tag_pages[page_index])
        parent_arrays.append(ArrayObject([NullObject() for _ in range(max_mcid + 1)]))
        page[NameObject("/StructParents")] = NumberObject(page_index)
        page[NameObject("/Tabs")] = NameObject("/S")

    def build_node(
        node: dict[str, object],
        parent_ref,
        page_index: int,
    ):
        element = DictionaryObject(
            {
                NameObject("/Type"): NameObject("/StructElem"),
                NameObject("/S"): NameObject(f"/{node['role']}"),
                NameObject("/P"): parent_ref,
            }
        )
        element_ref = writer._add_object(element)
        if "mcid" in node:
            mcid = int(node["mcid"])
            element[NameObject("/Pg")] = writer.pages[page_index].indirect_reference
            element[NameObject("/K")] = NumberObject(mcid)
            parent_arrays[page_index][mcid] = element_ref
            return element_ref

        children = node.get("children")
        if not isinstance(children, list):
            raise RuntimeError(f"Container structure node lacks children: {node}")
        element[NameObject("/K")] = ArrayObject(
            [build_node(child, element_ref, page_index) for child in children]
        )
        return element_ref

    document = DictionaryObject(
        {
            NameObject("/Type"): NameObject("/StructElem"),
            NameObject("/S"): NameObject("/Document"),
            NameObject("/P"): struct_root_ref,
        }
    )
    document_ref = writer._add_object(document)
    document_children = []
    for page_index, page_nodes in enumerate(tag_pages):
        document_children.extend(
            build_node(node, document_ref, page_index) for node in page_nodes
        )
    document[NameObject("/K")] = ArrayObject(document_children)

    parent_tree_numbers = ArrayObject()
    for page_index, parents in enumerate(parent_arrays):
        parent_tree_numbers.extend([NumberObject(page_index), parents])
    parent_tree = DictionaryObject({NameObject("/Nums"): parent_tree_numbers})
    struct_root[NameObject("/K")] = ArrayObject([document_ref])
    struct_root[NameObject("/ParentTree")] = writer._add_object(parent_tree)
    struct_root[NameObject("/ParentTreeNextKey")] = NumberObject(len(parent_arrays))

    catalog = writer.root_object
    catalog[NameObject("/StructTreeRoot")] = struct_root_ref
    catalog[NameObject("/MarkInfo")] = DictionaryObject(
        {
            NameObject("/Marked"): BooleanObject(True),
            NameObject("/Suspects"): BooleanObject(False),
        }
    )
    catalog[NameObject("/Lang")] = TextStringObject("en-US")
    catalog[NameObject("/ViewerPreferences")] = DictionaryObject(
        {NameObject("/DisplayDocTitle"): BooleanObject(True)}
    )
    writer.pdf_header = b"%PDF-1.7"

    tagged_path = pdf_path.with_suffix(".tagged.pdf")
    with tagged_path.open("wb") as stream:
        writer.write(stream)
    tagged_path.replace(pdf_path)


def register_fonts() -> None:
    for path in (FONT_REGULAR, FONT_BOLD):
        if not path.is_file():
            raise FileNotFoundError(f"Required PDF font not found: {path}")
    pdfmetrics.registerFont(TTFont("CardRegular", str(FONT_REGULAR)))
    pdfmetrics.registerFont(TTFont("CardBold", str(FONT_BOLD)))


def style(
    name: str,
    *,
    size: float,
    leading: float,
    color: colors.Color = INK,
    bold: bool = False,
    alignment: int = TA_LEFT,
    space_after: float = 0,
) -> ParagraphStyle:
    return ParagraphStyle(
        name,
        fontName="CardBold" if bold else "CardRegular",
        fontSize=size,
        leading=leading,
        textColor=color,
        alignment=alignment,
        spaceAfter=space_after,
        allowWidows=0,
        allowOrphans=0,
    )


TITLE = style("Title", size=18, leading=20, color=NAVY, bold=True)
SUBTITLE = style("Subtitle", size=11, leading=12, color=BLUE, bold=True)
PACE_HEADING = style("PaceHeading", size=12.5, leading=13.5, color=NAVY, bold=True)
PACE_BODY = style("PaceBody", size=11.4, leading=12.6)
BACK_HEADING = style("BackHeading", size=12.3, leading=13.2, color=NAVY, bold=True)
BACK_BODY = style("BackBody", size=11.2, leading=12.2)
BACK_BODY_TIGHT = style("BackBodyTight", size=10.9, leading=11.8)
FOOTER = style("Footer", size=8.5, leading=9.5, color=MID, alignment=TA_CENTER)
DISCLAIMER = style("Disclaimer", size=10.2, leading=11.2, color=MID, alignment=TA_CENTER)
SHEET_NOTE = style("SheetNote", size=9.5, leading=11, color=MID, alignment=TA_CENTER)


def set_metadata(pdf: canvas.Canvas, title: str, subject: str) -> None:
    pdf.setTitle(title)
    pdf.setAuthor("FloatPlanWizard")
    pdf.setSubject(subject)
    pdf.setCreator("FloatPlanWizard deterministic ReportLab emergency-card builder")
    pdf.setProducer("FloatPlanWizard")
    pdf._doc.Catalog.Lang = PDFString("en-US")


def draw_paragraph(
    pdf: TaggedCanvas,
    text: str,
    paragraph_style: ParagraphStyle,
    x: float,
    top: float,
    width: float,
    max_height: float,
    *,
    role: str = "P",
) -> float:
    paragraph = Paragraph(text, paragraph_style)
    used_width, used_height = paragraph.wrap(width, max_height)
    if used_height > max_height + 0.01:
        raise RuntimeError(f"Paragraph does not fit: {text[:60]}")
    with pdf.marked_content(role):
        paragraph.drawOn(pdf, x, top - used_height)
    return used_height


def draw_card_frame(pdf: TaggedCanvas, x: float, y: float) -> None:
    with pdf.artifact():
        pdf.saveState()
        pdf.setFillColor(WHITE)
        pdf.rect(x, y, CARD_WIDTH, CARD_HEIGHT, fill=1, stroke=0)
        pdf.setStrokeColor(LINE)
        pdf.setLineWidth(0.7)
        pdf.rect(x + 0.5, y + 0.5, CARD_WIDTH - 1, CARD_HEIGHT - 1, fill=0, stroke=1)
        pdf.restoreState()


def draw_front(
    pdf: TaggedCanvas,
    x: float = 0,
    y: float = 0,
    framed: bool = True,
    footer_text: str = REVISION,
) -> None:
    if framed:
        draw_card_frame(pdf, x, y)

    margin = 15
    content_x = x + margin
    content_top = y + CARD_HEIGHT - 13
    content_width = CARD_WIDTH - 2 * margin

    used = draw_paragraph(
        pdf,
        "First 60 seconds - P.A.C.E.",
        TITLE,
        content_x,
        content_top,
        content_width,
        24,
        role="H1",
    )
    subtitle_top = content_top - used - 1
    used += 1 + draw_paragraph(
        pdf,
        "FloatPlanWizard Boating Emergency Card",
        SUBTITLE,
        content_x,
        subtitle_top,
        content_width,
        15,
    )

    grid_top = content_top - used - 8
    grid_bottom = y + 25
    grid_height = grid_top - grid_bottom
    gap = 8
    cell_width = (content_width - gap) / 2
    cell_height = (grid_height - gap) / 2

    for index, (heading, body) in enumerate(PACE_ITEMS):
        row = index // 2
        column = index % 2
        cell_x = content_x + column * (cell_width + gap)
        cell_y = grid_top - (row + 1) * cell_height - row * gap
        with pdf.artifact():
            pdf.setFillColor(PALE)
            pdf.setStrokeColor(LINE)
            pdf.roundRect(cell_x, cell_y, cell_width, cell_height, 5, fill=1, stroke=1)
        block_top = cell_y + cell_height - 7
        with pdf.structure("Sect"):
            heading_height = draw_paragraph(
                pdf,
                heading,
                PACE_HEADING,
                cell_x + 8,
                block_top,
                cell_width - 16,
                18,
                role="H2",
            )
            draw_paragraph(
                pdf,
                body,
                PACE_BODY,
                cell_x + 8,
                block_top - heading_height - 2,
                cell_width - 16,
                cell_height - heading_height - 15,
            )

    draw_paragraph(pdf, footer_text, FOOTER, content_x, y + 17, content_width, 11)


def draw_back(
    pdf: TaggedCanvas,
    x: float = 0,
    y: float = 0,
    framed: bool = True,
    footer_text: str = REVISION,
) -> None:
    if framed:
        draw_card_frame(pdf, x, y)

    margin = 15
    content_x = x + margin
    content_top = y + CARD_HEIGHT - 13
    content_width = CARD_WIDTH - 2 * margin

    title_height = draw_paragraph(
        pdf,
        "Mayday voice script - VHF Channel 16",
        TITLE,
        content_x,
        content_top,
        content_width,
        24,
        role="H1",
    )
    columns_top = content_top - title_height - 7
    columns_bottom = y + 23
    columns_height = columns_top - columns_bottom
    gap = 12
    left_width = 222
    right_width = content_width - left_width - gap

    left_top = columns_top
    with pdf.structure("L"):
        for line in MAYDAY_LINES:
            with pdf.structure("LI"):
                with pdf.structure("LBody"):
                    height = draw_paragraph(
                        pdf, line, BACK_BODY, content_x, left_top, left_width, 25
                    )
            left_top -= height + 0.5
    left_top -= 2
    draw_paragraph(
        pdf,
        "Stay by the radio. Repeat if no answer. Follow Coast Guard instructions. If time is critical, say position and danger before lower-priority detail.",
        BACK_BODY_TIGHT,
        content_x,
        left_top,
        left_width,
        left_top - columns_bottom,
    )

    divider_x = content_x + left_width + gap / 2
    with pdf.artifact():
        pdf.setStrokeColor(LINE)
        pdf.setLineWidth(0.7)
        pdf.line(divider_x, columns_bottom, divider_x, columns_top)

    right_x = content_x + left_width + gap
    right_top = columns_top
    heading_height = draw_paragraph(
        pdf,
        "Boat-specific fields",
        BACK_HEADING,
        right_x,
        right_top,
        right_width,
        18,
        role="H2",
    )
    right_top -= heading_height + 3
    with pdf.structure("L"):
        for field in BOAT_FIELDS:
            with pdf.structure("LI"):
                with pdf.structure("LBody"):
                    height = draw_paragraph(
                        pdf,
                        field,
                        BACK_BODY_TIGHT,
                        right_x,
                        right_top,
                        right_width,
                        52,
                    )
            right_top -= height + 3

    right_top -= 1
    draw_paragraph(
        pdf,
        "P.A.C.E. is a FloatPlanWizard quick-recall framework; follow official responder instructions.",
        DISCLAIMER,
        right_x,
        right_top,
        right_width,
        right_top - columns_bottom,
    )
    draw_paragraph(pdf, footer_text, FOOTER, content_x, y + 17, content_width, 11)


def draw_cut_marks(pdf: TaggedCanvas, x: float, y: float) -> None:
    length = 10
    offset = 4
    with pdf.artifact():
        pdf.saveState()
        pdf.setStrokeColor(MID)
        pdf.setLineWidth(0.5)
        for corner_x, horizontal_sign in ((x, -1), (x + CARD_WIDTH, 1)):
            for corner_y, vertical_sign in ((y, -1), (y + CARD_HEIGHT, 1)):
                pdf.line(
                    corner_x + horizontal_sign * offset,
                    corner_y,
                    corner_x + horizontal_sign * (offset + length),
                    corner_y,
                )
                pdf.line(
                    corner_x,
                    corner_y + vertical_sign * offset,
                    corner_x,
                    corner_y + vertical_sign * (offset + length),
                )
        pdf.restoreState()


def build_4x6() -> None:
    pdf = TaggedCanvas(
        str(OUTPUT_4X6),
        pagesize=landscape((4 * inch, 6 * inch)),
        pageCompression=1,
        initialFontName="CardRegular",
        initialFontSize=12,
        initialLeading=14.4,
    )
    set_metadata(
        pdf,
        "FloatPlanWizard Boating Emergency Card - 4x6",
        "Two-sided 4x6-inch P.A.C.E. and Mayday quick-reference card.",
    )
    with pdf.structure("Sect"):
        draw_front(pdf, footer_text=FOUR_BY_SIX_FOOTER)
    pdf.showPage()
    with pdf.structure("Sect"):
        draw_back(pdf, footer_text=FOUR_BY_SIX_FOOTER)
    pdf.showPage()
    pdf.save()
    add_pdf_structure(OUTPUT_4X6, pdf.finalized_tag_pages())


def build_letter() -> None:
    page_width, page_height = letter
    card_x = (page_width - CARD_WIDTH) / 2
    card_positions = (432, 72)
    pdf = TaggedCanvas(
        str(OUTPUT_LETTER),
        pagesize=letter,
        pageCompression=1,
        initialFontName="CardRegular",
        initialFontSize=12,
        initialLeading=14.4,
    )
    set_metadata(
        pdf,
        "FloatPlanWizard Boating Emergency Card - Letter Two-Up",
        "Letter-size two-up printable P.A.C.E. and Mayday emergency cards at actual 4x6-inch size.",
    )

    draw_paragraph(
        pdf,
        "FRONT - Print at 100% / Actual Size. Cut on the corner marks.",
        SHEET_NOTE,
        36,
        page_height - 16,
        page_width - 72,
        14,
    )
    for card_y in card_positions:
        with pdf.structure("Sect"):
            draw_front(pdf, card_x, card_y)
            draw_cut_marks(pdf, card_x, card_y)
    draw_paragraph(
        pdf,
        "For two-sided cards, print the next page on the reverse using your printer's long-edge duplex setting.",
        SHEET_NOTE,
        36,
        26,
        page_width - 72,
        14,
    )
    pdf.showPage()

    draw_paragraph(
        pdf,
        "BACK - Print at 100% / Actual Size. Cut on the corner marks.",
        SHEET_NOTE,
        36,
        page_height - 16,
        page_width - 72,
        14,
    )
    for card_y in card_positions:
        with pdf.structure("Sect"):
            draw_back(pdf, card_x, card_y)
            draw_cut_marks(pdf, card_x, card_y)
    draw_paragraph(
        pdf,
        "Two-up preserves the actual 4x6-inch card dimensions and approximately 12-point body text.",
        SHEET_NOTE,
        36,
        26,
        page_width - 72,
        14,
    )
    pdf.showPage()
    pdf.save()
    add_pdf_structure(OUTPUT_LETTER, pdf.finalized_tag_pages())


def main() -> None:
    register_fonts()
    OUTPUT_4X6.parent.mkdir(parents=True, exist_ok=True)
    build_4x6()
    build_letter()
    print(f"Built {OUTPUT_4X6}")
    print(f"Built {OUTPUT_LETTER}")


if __name__ == "__main__":
    main()
