#!/usr/bin/env python3
"""Deterministic structural validation for the Solo Boating Safety publications."""

from __future__ import annotations

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import re
import sys
from zipfile import ZIP_STORED, ZipFile

from lxml import etree, html
from PIL import Image
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
MANUSCRIPT = ROOT / "manuscript" / "solo-boating-safety.html"
GRAPHICS = ROOT / "assets" / "graphics"
DIST = ROOT / "dist"
PDF = DIST / "floatplanwizard-solo-boating-safety-guide.pdf"
EPUB = DIST / "solo-boating-safety-a-practical-guide.epub"
DOCX = DIST / "solo-boating-safety-kindle-source.docx"
COVER = DIST / "solo-boating-safety-cover.jpg"
DOWNLOAD_PDF = REPO / "downloads" / PDF.name
DOWNLOAD_EPUB = REPO / "downloads" / EPUB.name

EXPECTED_CHAPTERS = 14
EXPECTED_FIGURES = 17
EXPECTED_CHECKLIST = 84
EXPECTED_GROUPS = [12, 7, 10, 14, 12, 19, 10]
EXPECTED_PAMPHLETS = [
    "solo-boater-trip-planning-guide.pdf",
    "solo-boater-vessel-information-guide.pdf",
    "solo-boater-personal-safety-guide.pdf",
    "solo-boater-weather-guide.pdf",
    "solo-boater-communications-guide.pdf",
    "solo-boater-boat-readiness-guide.pdf",
    "solo-boater-precautions-guide.pdf",
]
EXPECTED_GRAPHIC_NAMES = [
    "figure-1-1-safety-layers",
    "figure-2-1-float-plan-anatomy",
    "figure-2-2-shore-contact-timeline",
    "figure-3-1-plan-for-separation",
    "figure-3-2-reboarding-problem",
    "figure-3-3-engine-cutoff",
    "figure-3-4-gear-with-you-vs-boat",
    "figure-4-1-communication-redundancy",
    "figure-4-2-dsc",
    "figure-5-1-weather-decision",
    "figure-6-1-cold-water",
    "figure-7-1-vessel-readiness",
    "figure-8-1-paddlecraft-recovery",
    "figure-10-1-different-craft",
    "figure-11-1-change-plan",
    "figure-11-2-tech-failures",
    "figure-14-1-five-minute-routine",
]
PNG_ONLY_GRAPHICS = {
    "figure-1-1-safety-layers",
    "figure-2-1-float-plan-anatomy",
    "figure-2-2-shore-contact-timeline",
    "figure-3-1-plan-for-separation",
    "figure-3-2-reboarding-problem",
    "figure-3-3-engine-cutoff",
    "figure-3-4-gear-with-you-vs-boat",
    "figure-4-1-communication-redundancy",
    "figure-4-2-dsc",
    "figure-5-1-weather-decision",
    "figure-6-1-cold-water",
    "figure-7-1-vessel-readiness",
    "figure-8-1-paddlecraft-recovery",
    "figure-10-1-different-craft",
    "figure-11-1-change-plan",
    "figure-11-2-tech-failures",
    "figure-14-1-five-minute-routine",
}
EXPECTED_PNG_SPECS = {
    "figure-1-1-safety-layers": ((1672, 941), "RGB"),
    "figure-2-1-float-plan-anatomy": ((1672, 941), "RGB"),
    "figure-2-2-shore-contact-timeline": ((1672, 941), "RGB"),
    "figure-3-1-plan-for-separation": ((1448, 1086), "RGB"),
    "figure-3-2-reboarding-problem": ((1429, 941), "RGB"),
    "figure-3-3-engine-cutoff": ((1448, 1086), "RGB"),
    "figure-3-4-gear-with-you-vs-boat": ((1536, 1024), "RGB"),
    "figure-4-1-communication-redundancy": ((1672, 941), "RGB"),
    "figure-4-2-dsc": ((1672, 941), "RGB"),
    "figure-5-1-weather-decision": ((1672, 941), "RGB"),
    "figure-6-1-cold-water": ((1672, 941), "RGB"),
    "figure-7-1-vessel-readiness": ((1448, 1086), "RGB"),
    "figure-8-1-paddlecraft-recovery": ((1671, 941), "RGB"),
    "figure-10-1-different-craft": ((1672, 941), "RGB"),
    "figure-11-1-change-plan": ((1536, 1024), "RGB"),
    "figure-11-2-tech-failures": ((1672, 941), "RGB"),
    "figure-14-1-five-minute-routine": ((1672, 941), "RGB"),
}


class Validation:
    def __init__(self):
        self.errors: list[str] = []
        self.notes: list[str] = []

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def note(self, message: str) -> None:
        self.notes.append(message)


def file_sha(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def expected_checklist_field_names(root) -> list[str]:
    names = []
    groups = root.xpath('//section[contains(concat(" ", normalize-space(@class), " "), " checklist-group ")]')
    for group in groups:
        group_slug = re.sub(
            r"[^a-z0-9]+",
            "_",
            group.get("id", "checklist").removeprefix("checklist-").lower(),
        ).strip("_")
        items = group.xpath('./ul[contains(concat(" ", normalize-space(@class), " "), " checklist ")]/li')
        names.extend(f"ch13_{group_slug}_{index:02d}" for index, _ in enumerate(items, start=1))
    return names


def validate_manuscript(check: Validation):
    root = html.parse(str(MANUSCRIPT)).getroot()
    chapters = root.xpath('//section[contains(concat(" ", normalize-space(@class), " "), " chapter ")]')
    figures = root.xpath("//figure")
    checklist_items = root.xpath('//ul[contains(concat(" ", normalize-space(@class), " "), " checklist ")]/li')
    groups = root.xpath('//section[contains(concat(" ", normalize-space(@class), " "), " checklist-group ")]')
    check.require(len(chapters) == EXPECTED_CHAPTERS, f"manuscript chapter count is {len(chapters)}, expected {EXPECTED_CHAPTERS}")
    check.require(len(figures) == EXPECTED_FIGURES, f"manuscript figure count is {len(figures)}, expected {EXPECTED_FIGURES}")
    check.require(len(checklist_items) == EXPECTED_CHECKLIST, f"checklist item count is {len(checklist_items)}, expected {EXPECTED_CHECKLIST}")
    group_counts = [len(group.xpath('.//ul[contains(concat(" ", normalize-space(@class), " "), " checklist ")]/li')) for group in groups]
    check.require(group_counts == EXPECTED_GROUPS, f"checklist group counts are {group_counts}, expected {EXPECTED_GROUPS}")

    ids = root.xpath("//@id")
    check.require(len(ids) == len(set(ids)), "manuscript contains duplicate IDs")
    headings = root.xpath("//h1 | //h2 | //h3")
    check.require(all(" ".join(h.itertext()).strip() for h in headings), "manuscript contains an empty heading")
    check.require(all(" ".join(li.itertext()).strip() for li in checklist_items),
                  "a checklist item is empty")
    check.require(all(not " ".join(li.itertext()).strip().startswith("CHECK -") for li in checklist_items),
                  "a checklist item still contains the obsolete CHECK - prefix")
    field_names = expected_checklist_field_names(root)
    check.require(len(field_names) == len(set(field_names)) == EXPECTED_CHECKLIST,
                  "Chapter 13 checklist field names are not unique and complete")

    for figure in figures:
        image = figure.find("img")
        caption = figure.find("figcaption")
        check.require(image is not None and bool((image.get("alt") or "").strip()), f"{figure.get('id')} lacks alt text")
        check.require(caption is not None and bool(" ".join(caption.itertext()).strip()), f"{figure.get('id')} lacks a caption")
        if image is not None:
            path = (MANUSCRIPT.parent / image.get("src", "")).resolve()
            check.require(path.is_file(), f"missing figure export: {path}")

    hrefs = root.xpath("//a/@href")
    check.require(all(href.startswith("https://") for href in hrefs), "manuscript contains a non-HTTPS hyperlink")
    check.require(not any("localhost" in h or "127.0.0.1" in h or "utm_" in h for h in hrefs),
                  "manuscript contains a local, staging, or tracked hyperlink")
    check.require(not root.xpath("//script | //iframe"), "manuscript contains script or iframe content")
    check.note(f"manuscript: {len(chapters)} chapters, {len(figures)} figures, {len(checklist_items)} checklist items")
    check.note(f"manuscript word count: {len(' '.join(root.itertext()).split())}")
    return root


def validate_graphics(check: Validation) -> None:
    svgs = sorted((GRAPHICS / "source").glob("*.svg"))
    pngs = sorted((GRAPHICS / "export").glob("*.png"))
    expected_svg_names = sorted(set(EXPECTED_GRAPHIC_NAMES) - PNG_ONLY_GRAPHICS)
    check.require(len(svgs) == len(expected_svg_names), f"SVG count is {len(svgs)}, expected {len(expected_svg_names)}")
    check.require(len(pngs) == EXPECTED_FIGURES, f"PNG count is {len(pngs)}, expected {EXPECTED_FIGURES}")
    check.require(
        [path.stem for path in svgs] == expected_svg_names,
        "SVG filenames do not match the required owner-supplied figure mapping",
    )
    check.require(
        [path.stem for path in pngs] == sorted(EXPECTED_GRAPHIC_NAMES),
        "PNG filenames do not match the required owner-supplied figure mapping",
    )
    for svg in svgs:
        try:
            etree.parse(str(svg))
        except Exception as error:
            check.errors.append(f"invalid SVG {svg.name}: {error}")
    for png in pngs:
        try:
            with Image.open(png) as image:
                expected_size, expected_mode = EXPECTED_PNG_SPECS.get(
                    png.stem, ((1600, 900), "RGB")
                )
                check.require(image.size == expected_size, f"{png.name} is {image.size}, expected {expected_size}")
                check.require(image.mode == expected_mode, f"{png.name} is {image.mode}, expected {expected_mode}")
                image.verify()
        except Exception as error:
            check.errors.append(f"invalid PNG {png.name}: {error}")


def validate_pdf(check: Validation, manuscript_root) -> None:
    check.require(PDF.is_file() and PDF.stat().st_size > 100_000, "PDF is missing or implausibly small")
    if not PDF.is_file():
        return
    reader = PdfReader(str(PDF))
    check.require(len(reader.pages) >= 25, f"PDF has only {len(reader.pages)} pages")
    check.require(reader.metadata.title == "Solo Boating Safety: A Practical Guide from Kayaks to Cruisers", "PDF title metadata mismatch")
    check.require(reader.metadata.author == "Larry W.", "PDF author metadata mismatch")
    try:
        outline = reader.outline
        check.require(len(outline) >= EXPECTED_CHAPTERS, "PDF outline/bookmarks are incomplete")
    except Exception as error:
        check.errors.append(f"PDF outline could not be read: {error}")
    links = 0
    widgets = []
    widget_pages = []
    extracted = []
    for page_index, page in enumerate(reader.pages):
        extracted.append(page.extract_text() or "")
        for annotation in page.get("/Annots", []):
            obj = annotation.get_object()
            if obj.get("/Subtype") == "/Link":
                links += 1
            if obj.get("/Subtype") == "/Widget" and obj.get("/FT") == "/Btn":
                widgets.append(obj)
                widget_pages.append(page_index)
    full_text = "\n".join(extracted)
    for chapter in manuscript_root.xpath('//section[contains(concat(" ", normalize-space(@class), " "), " chapter ")]/h1'):
        title = " ".join(chapter.itertext()).strip()
        check.require(title in full_text, f"PDF text is missing {title}")
    expected_fields = expected_checklist_field_names(manuscript_root)
    fields = reader.get_fields() or {}
    check.require(set(fields) == set(expected_fields),
                  f"PDF field names differ from the expected {EXPECTED_CHECKLIST} Chapter 13 names")
    check.require(len(widgets) == EXPECTED_CHECKLIST,
                  f"PDF has {len(widgets)} checkbox widgets, expected {EXPECTED_CHECKLIST}")
    widget_names = [str(widget.get("/T", "")) for widget in widgets]
    check.require(set(widget_names) == set(expected_fields),
                  "PDF widget names are not unique and complete")
    check.require(all(widget.get("/V") == "/Off" and widget.get("/AS") == "/Off" for widget in widgets),
                  "a PDF checkbox is not initially unchecked")
    check.require(all(int(widget.get("/F", 0)) & 4 for widget in widgets),
                  "a PDF checkbox is not marked for printing")
    for widget in widgets:
        appearance = widget.get("/AP")
        normal = appearance.get_object().get("/N") if appearance is not None else None
        normal = normal.get_object() if normal is not None else None
        check.require(normal is not None and "/Off" in normal and "/Yes" in normal,
                      f"PDF checkbox {widget.get('/T', '(unnamed)')} lacks complete normal appearances")
    if widget_pages:
        chapter_13_matches = [index for index, text in enumerate(extracted) if "Chapter 13 -" in text]
        chapter_14_matches = [index for index, text in enumerate(extracted) if "Chapter 14 -" in text]
        chapter_13_page = chapter_13_matches[-1] if chapter_13_matches else None
        chapter_14_page = chapter_14_matches[-1] if chapter_14_matches else None
        check.require(
            chapter_13_page is not None and chapter_14_page is not None
            and all(chapter_13_page <= page < chapter_14_page for page in widget_pages),
            "a PDF checkbox widget appears outside Chapter 13",
        )
    check.require("CHECK -" not in full_text, "PDF still contains the obsolete CHECK - prefix")
    check.require(links >= 15, f"PDF contains only {links} link annotations")
    check.note(
        f"PDF: {len(reader.pages)} pages, {len(widgets)} printable checkbox widgets, "
        f"{links} link annotations, readable outline"
    )


def validate_epub(check: Validation) -> None:
    check.require(EPUB.is_file() and EPUB.stat().st_size > 100_000, "EPUB is missing or implausibly small")
    if not EPUB.is_file():
        return
    with ZipFile(EPUB) as archive:
        infos = archive.infolist()
        check.require(bool(infos) and infos[0].filename == "mimetype", "EPUB mimetype is not the first entry")
        check.require(bool(infos) and infos[0].compress_type == ZIP_STORED, "EPUB mimetype entry is compressed")
        check.require(archive.read("mimetype") == b"application/epub+zip", "EPUB mimetype value is incorrect")
        names = set(archive.namelist())
        xhtml_names = sorted(name for name in names if name.endswith(".xhtml"))
        image_names = sorted(name for name in names if name.startswith("EPUB/images/") and name.endswith(".png"))
        check.require(len(image_names) == EXPECTED_FIGURES, f"EPUB embeds {len(image_names)} diagrams, expected {EXPECTED_FIGURES}")
        check.require("EPUB/nav.xhtml" in names and "EPUB/package.opf" in names, "EPUB nav or package document missing")
        check.require(not any(name.lower().endswith(".js") for name in names), "EPUB contains JavaScript")
        checkbox_names = []
        checkbox_ids = []
        checkbox_labels = []
        print_boxes = 0
        for name in xhtml_names + ["EPUB/package.opf", "META-INF/container.xml"]:
            try:
                doc = etree.parse(BytesIO(archive.read(name)))
            except Exception as error:
                check.errors.append(f"invalid EPUB XML {name}: {error}")
                continue
            if name.endswith(".xhtml"):
                for image in doc.xpath("//*[local-name()='img']"):
                    check.require(bool((image.get("alt") or "").strip()), f"EPUB image in {name} lacks alt text")
                    check.require(not (image.get("src") or "").startswith(("http://", "https://")),
                                  f"EPUB has a remote image in {name}")
                check.require(not doc.xpath("//*[local-name()='script']"), f"EPUB contains script content in {name}")
                for link in doc.xpath("//*[local-name()='a']/@href"):
                    check.require(not link.startswith("http://"), f"EPUB has a non-HTTPS external link in {name}: {link}")
                inputs = doc.xpath("//*[local-name()='input' and @type='checkbox']")
                checkbox_names.extend(control.get("name", "") for control in inputs)
                checkbox_ids.extend(control.get("id", "") for control in inputs)
                check.require(all(bool((control.get("aria-label") or "").strip()) for control in inputs),
                              f"EPUB checkbox in {name} lacks an accessible label")
                checkbox_labels.extend(doc.xpath("//*[local-name()='label']/@for"))
                print_boxes += len(doc.xpath(
                    "//*[local-name()='span' and contains(concat(' ', normalize-space(@class), ' '), ' checklist-print-box ')]"
                ))
                text = " ".join(doc.xpath("//text()"))
                check.require("CHECK -" not in text, f"EPUB still contains the obsolete CHECK - prefix in {name}")
        nav = etree.parse(BytesIO(archive.read("EPUB/nav.xhtml")))
        nav_links = nav.xpath("//*[local-name()='nav' and @*[local-name()='type']='toc']//*[local-name()='a']/@href")
        manuscript_root = html.parse(str(MANUSCRIPT)).getroot()
        expected_fields = expected_checklist_field_names(manuscript_root)
        expected_ids = [f"checkbox-{name}" for name in expected_fields]
        check.require(checkbox_names == expected_fields,
                      f"EPUB checkbox names differ from the expected {EXPECTED_CHECKLIST} Chapter 13 names")
        check.require(checkbox_ids == expected_ids and checkbox_labels == expected_ids,
                      "EPUB checkbox IDs and label targets are not complete and ordered")
        check.require(print_boxes == EXPECTED_CHECKLIST,
                      f"EPUB has {print_boxes} print fallback boxes, expected {EXPECTED_CHECKLIST}")
        check.require(len(nav_links) >= EXPECTED_CHAPTERS, f"EPUB TOC has only {len(nav_links)} links")
        check.note(
            f"EPUB: {len(xhtml_names)} XHTML documents, {len(checkbox_names)} accessible checkbox controls, "
            f"{len(nav_links)} TOC links, {len(image_names)} diagrams"
        )


def validate_docx(check: Validation) -> None:
    check.require(DOCX.is_file() and DOCX.stat().st_size > 100_000, "DOCX is missing or implausibly small")
    if not DOCX.is_file():
        return
    with ZipFile(DOCX) as archive:
        check.require("word/document.xml" in archive.namelist(), "DOCX document.xml missing")
        document = etree.parse(BytesIO(archive.read("word/document.xml")))
        alt = document.xpath("//*[local-name()='docPr']/@descr")
        hyperlinks = document.xpath("//*[local-name()='hyperlink']")
        headings = document.xpath("//*[local-name()='pStyle' and starts-with(@*[local-name()='val'], 'Heading')]")
        namespaces = {
            "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
            "w14": "http://schemas.microsoft.com/office/word/2010/wordml",
        }
        controls = document.xpath("//w:sdt[w:sdtPr/w14:checkbox]", namespaces=namespaces)
        control_tags = document.xpath("//w:sdt[w:sdtPr/w14:checkbox]/w:sdtPr/w:tag/@w:val", namespaces=namespaces)
        aliases = document.xpath("//w:sdt[w:sdtPr/w14:checkbox]/w:sdtPr/w:alias/@w:val", namespaces=namespaces)
        checked = document.xpath("//w:sdt[w:sdtPr/w14:checkbox]/w:sdtPr/w14:checkbox/w14:checked/@w14:val", namespaces=namespaces)
        checked_states = document.xpath("//w:sdt[w:sdtPr/w14:checkbox]/w:sdtPr/w14:checkbox/w14:checkedState/@w14:val", namespaces=namespaces)
        unchecked_states = document.xpath("//w:sdt[w:sdtPr/w14:checkbox]/w:sdtPr/w14:checkbox/w14:uncheckedState/@w14:val", namespaces=namespaces)
        fallback_glyphs = document.xpath("//w:sdt[w:sdtPr/w14:checkbox]/w:sdtContent//w:t/text()", namespaces=namespaces)
        expected_fields = expected_checklist_field_names(html.parse(str(MANUSCRIPT)).getroot())
        check.require(len(alt) == EXPECTED_FIGURES, f"DOCX has {len(alt)} figure alt-text records, expected {EXPECTED_FIGURES}")
        check.require(all(value.strip() for value in alt), "DOCX contains empty figure alt text")
        check.require(len(hyperlinks) >= 15, f"DOCX has only {len(hyperlinks)} external hyperlinks")
        check.require(len(headings) >= EXPECTED_CHAPTERS, "DOCX heading structure is incomplete")
        check.require(len(controls) == EXPECTED_CHECKLIST,
                      f"DOCX has {len(controls)} checkbox content controls, expected {EXPECTED_CHECKLIST}")
        check.require(control_tags == expected_fields, "DOCX checkbox tags are not complete and ordered")
        check.require(len(aliases) == EXPECTED_CHECKLIST and all(alias.strip() for alias in aliases),
                      "a DOCX checkbox lacks an accessible alias")
        check.require(checked == ["0"] * EXPECTED_CHECKLIST, "a DOCX checkbox is not initially unchecked")
        check.require(checked_states == ["2612"] * EXPECTED_CHECKLIST,
                      "a DOCX checkbox lacks the expected checked-state glyph")
        check.require(unchecked_states == ["2610"] * EXPECTED_CHECKLIST,
                      "a DOCX checkbox lacks the expected unchecked-state glyph")
        check.require(fallback_glyphs == ["☐"] * EXPECTED_CHECKLIST,
                      "a DOCX checkbox lacks its visible print fallback glyph")
        document_text = " ".join(document.xpath("//w:t/text()", namespaces=namespaces))
        check.require("CHECK -" not in document_text, "DOCX still contains the obsolete CHECK - prefix")
        check.note(
            f"DOCX: {len(headings)} heading paragraphs, {len(controls)} checkbox content controls, "
            f"{len(alt)} alt-text records, {len(hyperlinks)} hyperlinks"
        )


def validate_distribution(check: Validation) -> None:
    if COVER.is_file():
        with Image.open(COVER) as cover:
            check.require(cover.size == (1600, 2560), f"cover size is {cover.size}, expected 1600x2560")
            check.require(cover.mode == "RGB", f"cover mode is {cover.mode}, expected RGB")
        check.require(COVER.stat().st_size < 5_000_000, "cover exceeds 5 MB")
    else:
        check.errors.append("standalone cover is missing")
    for source, public in ((PDF, DOWNLOAD_PDF), (EPUB, DOWNLOAD_EPUB)):
        check.require(public.is_file(), f"public download is missing: {public}")
        if source.is_file() and public.is_file():
            check.require(file_sha(source) == file_sha(public), f"public download differs from dist source: {public.name}")
    for pamphlet in EXPECTED_PAMPHLETS:
        path = REPO / "downloads" / pamphlet
        check.require(path.is_file() and path.stat().st_size > 10_000, f"existing pamphlet missing or too small: {pamphlet}")


def main() -> int:
    check = Validation()
    root = validate_manuscript(check)
    validate_graphics(check)
    validate_pdf(check, root)
    validate_epub(check)
    validate_docx(check)
    validate_distribution(check)
    for note in check.notes:
        print(f"PASS: {note}")
    if check.errors:
        for error in check.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"VALIDATION_FAILED: {len(check.errors)} error(s)", file=sys.stderr)
        return 1
    print("VALIDATION_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
