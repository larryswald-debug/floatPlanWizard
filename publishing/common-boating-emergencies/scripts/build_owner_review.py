#!/usr/bin/env python3
"""Build the non-public Common Boating Emergencies owner-review package."""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[3]
PUBLISHING_ROOT = ROOT / "publishing/common-boating-emergencies"
SOURCE_DIR = PUBLISHING_ROOT / "assets/source"
PUBLIC_DIR = ROOT / "assets/images/boating-guides/common-boating-emergencies"
DOWNLOAD_DIR = ROOT / "downloads"
REVIEW_DIR = PUBLISHING_ROOT / "review"
PACKAGE_NAME = "common-boating-emergencies-owner-review"
STAGING_DIR = REVIEW_DIR / PACKAGE_NAME
ZIP_PATH = REVIEW_DIR / f"{PACKAGE_NAME}.zip"
MANIFEST_PATH = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
REVIEW_DATE = "August 22, 2026"
ZIP_TIMESTAMP = (2026, 8, 22, 12, 0, 0)

FONT_REGULAR = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
FONT_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")

ASSETS = (
    ("common-boating-emergencies-hero", "Common boating emergencies hero"),
    ("boating-emergency-pace-first-minute", "P.A.C.E. first-minute sequence"),
    ("boat-engine-failure-drift-anchor", "Engine failure, drift, and anchoring"),
    ("boat-taking-on-water-checkpoints", "Taking-on-water inspection areas"),
    ("boat-grounding-stop-assess", "Grounding: stop and assess"),
    ("person-overboard-controlled-recovery", "Controlled person-overboard recovery"),
    ("boat-engine-compartment-fire-response", "Cabin-cruiser fuel-dock fire"),
    ("boating-storm-early-shelter-decision", "Marked-channel approach before severe weather"),
    ("marine-vhf-mayday-prepared-card", "Prepared VHF emergency call"),
    ("capsize-stay-with-boat-visibility", "Stay-with-the-boat visibility"),
    ("boat-carbon-monoxide-danger-zones", "Carbon-monoxide danger zones"),
    ("overdue-boater-response-information-chain", "Overdue-boater information chain"),
)

MOBILE_REVIEW_STEMS = (
    "person-overboard-controlled-recovery",
    "boat-taking-on-water-checkpoints",
    "boat-engine-compartment-fire-response",
    "boating-storm-early-shelter-decision",
    "boat-carbon-monoxide-danger-zones",
    "boat-grounding-stop-assess",
    "marine-vhf-mayday-prepared-card",
)

PDFS = (
    (
        "floatplanwizard-boating-emergency-card-4x6.pdf",
        ("emergency-card-4x6-page-1-front.png", "emergency-card-4x6-page-2-back.png"),
    ),
    (
        "floatplanwizard-boating-emergency-card-letter.pdf",
        ("emergency-card-letter-page-1-fronts.png", "emergency-card-letter-page-2-backs.png"),
    ),
)

PRINT_CHECKLIST = """# Physical print checklist

Review date: August 22, 2026

## 4x6 two-sided card

- [ ] Confirm the finished page is landscape 6 x 4 inches.
- [ ] Print page 1 as the front and page 2 as the back.
- [ ] Select 100% or Actual Size. Disable Fit, Shrink, and Scale to Fit.
- [ ] Start with short-edge duplex for the landscape card; printer-driver labels vary, so confirm the back is upright before producing additional copies.
- [ ] Confirm the front/back top edges and side margins align.
- [ ] Confirm all body text remains comfortably readable at the finished size.
- [ ] Confirm every vessel-information line accepts handwriting without crowding.
- [ ] Confirm no text, border, or line is clipped.
- [ ] Confirm pale fills and rules do not cause excessive ink coverage.

## Letter two-up sheet

- [ ] Confirm the paper is US Letter, portrait, 8.5 x 11 inches.
- [ ] Print page 1 fronts and page 2 backs.
- [ ] Select 100% or Actual Size. Disable Fit, Shrink, and Scale to Fit.
- [ ] Use long-edge duplex for the portrait Letter sheet.
- [ ] Confirm each back aligns behind its corresponding front.
- [ ] Cut on the corner marks and confirm each finished card is 6 x 4 inches.
- [ ] Confirm the smallest finished text is readable under normal lighting.
- [ ] Confirm vessel-information lines remain writable after cutting.
- [ ] Confirm there is no clipping, overlap, missing glyph, blank region, or excessive ink coverage.

Record printer model, driver, paper stock, duplex setting, and any measured offset with the owner-review decision.
"""

CHANGE_LOG = """# Owner-review change log

Review date: August 22, 2026

- Replaced the severe-weather illustration with the owner-approved cabin cruiser moving through a marked channel between red and green markers toward protected water, with dark storm clouds and heavy rain behind the boat.
- Replaced the engine-compartment fire-response illustration with the owner-approved 35-foot cabin cruiser burning at a fuel dock, including fire and smoke at the rear engine compartment and spilled fuel burning on the water near the stern.
- Updated the fuel-dock fire illustration with the revised owner-approved view of the cabin cruiser, rear engine-compartment fire and smoke, and burning fuel on the water.
- Replaced the carbon-monoxide illustration with a conceptual external-backdraft scene that begins at a stern exhaust outlet and highlights the swim platform, canvas-enclosed cockpit, and cabin entrance.
- Replaced the engine-failure illustration with the owner-approved cabin-cruiser scene showing an engine-compartment check, a radio call, and an anchor being lowered from the bow.
- Replaced the grounding illustration with the owner-approved cabin-cruiser scene showing a life-jacketed boater checking water depth beside the bow while another remains at the helm.
- Replaced the person-overboard illustration with the owner-approved cabin-cruiser scene showing a ring buoy with a retrieval line being thrown toward a life-jacketed person in the water.
- Replaced the Mayday/VHF illustration with the owner-approved helm scene showing two life-jacketed boaters, the operator using a connected fixed-mount VHF microphone, and a prepared emergency card beside the controls.
- Replaced the overdue-boater illustration with the owner-approved three-panel scene showing a boater at a marina, a shore contact reviewing the vessel and route, and a rescue coordinator viewing the same information.
- Added the required explanatory captions for the fire, carbon-monoxide, person-overboard, overdue-boater information-chain, and P.A.C.E. illustrations.
- Changed the Mayday line to `THIS IS [BOAT NAME] ×3`.
- Changed the DSC instruction to `DSC alert first if MMSI/GPS are configured; then voice on Ch 16.`
- Rebuilt both tagged emergency-card PDFs and their page-review renders.
"""


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def human_bytes(value: int) -> str:
    units = ("B", "KiB", "MiB", "GiB")
    amount = float(value)
    for unit in units:
        if amount < 1024 or unit == units[-1]:
            return f"{amount:.1f} {unit}" if unit != "B" else f"{int(amount)} B"
        amount /= 1024
    raise AssertionError("unreachable")


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    if not path.is_file():
        raise FileNotFoundError(f"Required review font not found: {path}")
    return ImageFont.truetype(str(path), size)


def build_contact_sheet(output_path: Path) -> None:
    columns = 3
    rows = 4
    panel_width = 820
    panel_height = 620
    margin = 34
    title_height = 76
    sheet = Image.new(
        "RGB",
        (margin * 2 + columns * panel_width, title_height + margin + rows * panel_height),
        "#eaf1f5",
    )
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(FONT_BOLD, 34)
    label_font = load_font(FONT_BOLD, 23)
    file_font = load_font(FONT_REGULAR, 17)
    draw.text(
        (margin, 20),
        "FloatPlanWizard Common Boating Emergencies - Owner Review Contact Sheet",
        font=title_font,
        fill="#08273d",
    )

    for index, (stem, label) in enumerate(ASSETS):
        column = index % columns
        row = index // columns
        x = margin + column * panel_width
        y = title_height + row * panel_height
        draw.rounded_rectangle(
            (x + 8, y + 8, x + panel_width - 8, y + panel_height - 8),
            radius=12,
            fill="#ffffff",
            outline="#aebbc4",
            width=2,
        )
        master_path = SOURCE_DIR / f"{stem}-master.png"
        with Image.open(master_path) as source:
            master_size = source.size
            image = ImageOps.contain(
                source.convert("RGB"),
                (panel_width - 48, 480),
                Image.Resampling.LANCZOS,
            )
        image_x = x + (panel_width - image.width) // 2
        image_y = y + 24
        sheet.paste(image, (image_x, image_y))
        label_y = y + 520
        draw.text(
            (x + 24, label_y),
            f"{index + 1:02d}. {label}",
            font=label_font,
            fill="#08273d",
        )
        draw.text(
            (x + 24, label_y + 30),
            f"{stem}-master.png | {master_size[0]} x {master_size[1]}",
            font=file_font,
            fill="#52616c",
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, "PNG", optimize=True)


def build_mobile_review(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    title_font = load_font(FONT_BOLD, 18)
    note_font = load_font(FONT_REGULAR, 15)
    for stem in MOBILE_REVIEW_STEMS:
        review_widths = (375, 320) if stem == "marine-vhf-mayday-prepared-card" else (375,)
        source_path = PUBLIC_DIR / f"{stem}-640w.webp"
        for review_width in review_widths:
            with Image.open(source_path) as source:
                image = ImageOps.contain(
                    source.convert("RGB"),
                    (review_width, 1000),
                    Image.Resampling.LANCZOS,
                )
            canvas = Image.new("RGB", (review_width + 40, image.height + 92), "#ffffff")
            canvas.paste(image, (20, 58))
            draw = ImageDraw.Draw(canvas)
            draw.text((20, 14), stem, font=title_font, fill="#08273d")
            draw.text(
                (20, 36),
                f"{review_width} px full-frame mobile review - no crop",
                font=note_font,
                fill="#52616c",
            )
            canvas.save(
                output_dir / f"{stem}-mobile-{review_width}w.png",
                "PNG",
                optimize=True,
            )


def render_pdf_pages(output_dir: Path) -> None:
    pdftoppm = shutil.which("pdftoppm")
    if not pdftoppm:
        raise FileNotFoundError("Poppler pdftoppm is required for owner-review renders.")
    output_dir.mkdir(parents=True, exist_ok=True)
    for pdf_name, output_names in PDFS:
        prefix = output_dir / Path(pdf_name).stem
        subprocess.run(
            [
                pdftoppm,
                "-png",
                "-r",
                "200",
                str(DOWNLOAD_DIR / pdf_name),
                str(prefix),
            ],
            check=True,
        )
        generated = sorted(output_dir.glob(f"{prefix.name}-*.png"))
        if len(generated) != len(output_names):
            raise RuntimeError(
                f"Expected {len(output_names)} rendered pages for {pdf_name}, got {len(generated)}."
            )
        for source, output_name in zip(generated, output_names, strict=True):
            source.replace(output_dir / output_name)


def image_record(scope: str, path: Path) -> dict[str, object]:
    with Image.open(path) as image:
        return {
            "scope": scope,
            "path": str(path.relative_to(ROOT)),
            "format": image.format,
            "width": image.width,
            "height": image.height,
            "dimensions": f"{image.width} x {image.height} px",
            "bytes": path.stat().st_size,
            "sha256": file_sha256(path),
        }


def pdf_record(path: Path) -> dict[str, object]:
    reader = PdfReader(path, strict=True)
    first_page = reader.pages[0]
    width = float(first_page.mediabox.width)
    height = float(first_page.mediabox.height)
    return {
        "scope": "download_pdf",
        "path": str(path.relative_to(ROOT)),
        "format": "PDF",
        "width": width,
        "height": height,
        "dimensions": f"{width:g} x {height:g} pt; {len(reader.pages)} pages",
        "bytes": path.stat().st_size,
        "sha256": file_sha256(path),
        "tagged": "/StructTreeRoot" in reader.trailer["/Root"],
    }


def build_inventory(output_dir: Path) -> dict[str, object]:
    records: list[dict[str, object]] = []
    for path in sorted(PUBLIC_DIR.iterdir()):
        if path.is_file() and path.suffix.lower() in {".jpg", ".webp"}:
            records.append(image_record("public_derivative", path))
    for stem, _ in ASSETS:
        records.append(image_record("source_master", SOURCE_DIR / f"{stem}-master.png"))
    for pdf_name, _ in PDFS:
        records.append(pdf_record(DOWNLOAD_DIR / pdf_name))

    public_total = sum(int(row["bytes"]) for row in records if row["scope"] == "public_derivative")
    source_total = sum(int(row["bytes"]) for row in records if row["scope"] == "source_master")
    pdf_total = sum(int(row["bytes"]) for row in records if row["scope"] == "download_pdf")
    top_ten = sorted(records, key=lambda row: int(row["bytes"]), reverse=True)[:10]
    inventory = {
        "review_date": REVIEW_DATE,
        "counts": {
            "public_derivatives": sum(row["scope"] == "public_derivative" for row in records),
            "source_masters": sum(row["scope"] == "source_master" for row in records),
            "download_pdfs": sum(row["scope"] == "download_pdf" for row in records),
        },
        "totals": {
            "public_derivative_bytes": public_total,
            "source_master_bytes": source_total,
            "download_pdf_bytes": pdf_total,
            "repository_asset_bytes": public_total + source_total + pdf_total,
        },
        "ten_largest_files": top_ten,
        "assets": records,
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "asset-inventory.json").write_text(
        json.dumps(inventory, indent=2) + "\n",
        encoding="utf-8",
    )
    with (output_dir / "asset-inventory.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=("scope", "path", "format", "dimensions", "bytes", "sha256"),
        )
        writer.writeheader()
        for row in records:
            writer.writerow({field: row[field] for field in writer.fieldnames})

    markdown = [
        "# Common Boating Emergencies asset inventory",
        "",
        f"Review date: {REVIEW_DATE}",
        "",
        f"- Public derivatives: {inventory['counts']['public_derivatives']} files, "
        f"{public_total:,} bytes ({human_bytes(public_total)})",
        f"- Source masters: {inventory['counts']['source_masters']} files, "
        f"{source_total:,} bytes ({human_bytes(source_total)})",
        f"- Download PDFs: {inventory['counts']['download_pdfs']} files, "
        f"{pdf_total:,} bytes ({human_bytes(pdf_total)})",
        f"- Repository production/review-source assets: {public_total + source_total + pdf_total:,} "
        f"bytes ({human_bytes(public_total + source_total + pdf_total)})",
        "",
        "## Ten largest files",
        "",
        "| Rank | Scope | File | Dimensions | Bytes |",
        "|---:|---|---|---|---:|",
    ]
    for index, row in enumerate(top_ten, 1):
        markdown.append(
            f"| {index} | {row['scope']} | `{row['path']}` | "
            f"{row['dimensions']} | {int(row['bytes']):,} |"
        )
    markdown.extend(
        [
            "",
            "## Complete asset list",
            "",
            "| Scope | File | Format | Dimensions | Bytes |",
            "|---|---|---|---|---:|",
        ]
    )
    for row in records:
        markdown.append(
            f"| {row['scope']} | `{row['path']}` | {row['format']} | "
            f"{row['dimensions']} | {int(row['bytes']):,} |"
        )
    (output_dir / "asset-inventory.md").write_text(
        "\n".join(markdown) + "\n",
        encoding="utf-8",
    )
    return inventory


def write_review_notes(output_dir: Path, inventory: dict[str, object]) -> None:
    pdf_status = {
        row["path"]: bool(row.get("tagged"))
        for row in inventory["assets"]
        if row["scope"] == "download_pdf"
    }
    readme = f"""# FloatPlanWizard Common Boating Emergencies owner review

Review date: {REVIEW_DATE}

This package is a non-public review artifact. It is excluded from Git and the guide-specific
`publishing/common-boating-emergencies/` web path is denied by server configuration.

Contents:

- `contact-sheet/common-boating-emergencies-contact-sheet.png`: labeled twelve-image overview.
- `masters/`: twelve full-resolution production PNG masters.
- `mobile-review/`: seven 375 px full-frame safety-critical mobile presentations, plus a 320 px Mayday/VHF presentation.
- `pdf-renders/`: PNG render of every page of both emergency-card PDFs.
- `pdfs/`: the two actual production PDF downloads, copied byte-for-byte for owner review.
- `inventory/`: JSON, CSV, and Markdown inventory with totals and the ten largest files.
- `physical-print-checklist.md`: required manual print validation.
- `CHANGELOG.md`: concise list of the image, caption, and emergency-card corrections.

## Automated structural/tagging validation

- 4x6 card tagged: {pdf_status['downloads/floatplanwizard-boating-emergency-card-4x6.pdf']}
- Letter card tagged: {pdf_status['downloads/floatplanwizard-boating-emergency-card-letter.pdf']}
- Automated tests check the structure tree, language, title display preference, semantic roles, parent tree, logical marked-content order, and decorative artifacts.

## Visual render validation

- Every page of both PDFs is rendered to PNG at 200 DPI for clipping, overlap, orientation, and missing-glyph review.

## Manual screen-reader validation still required

- Automated structure checks do not replace manual reading-order and announcement testing with assistive technology.

## Manual physical print and duplex validation still required

- Print, duplex, align, cut, measure, and inspect both formats using `physical-print-checklist.md`.
"""
    (output_dir / "README.md").write_text(readme, encoding="utf-8")
    (output_dir / "CHANGELOG.md").write_text(CHANGE_LOG, encoding="utf-8")
    (output_dir / "physical-print-checklist.md").write_text(
        PRINT_CHECKLIST,
        encoding="utf-8",
    )


def build_zip(staging_dir: Path, zip_path: Path) -> None:
    zip_path.unlink(missing_ok=True)
    with zipfile.ZipFile(
        zip_path,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for path in sorted(staging_dir.rglob("*")):
            if not path.is_file():
                continue
            relative = Path(PACKAGE_NAME) / path.relative_to(staging_dir)
            info = zipfile.ZipInfo(str(relative), ZIP_TIMESTAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)


def main() -> None:
    if STAGING_DIR.exists():
        shutil.rmtree(STAGING_DIR)
    STAGING_DIR.mkdir(parents=True)

    masters_dir = STAGING_DIR / "masters"
    masters_dir.mkdir()
    for stem, _ in ASSETS:
        source = SOURCE_DIR / f"{stem}-master.png"
        if not source.is_file():
            raise FileNotFoundError(source)
        shutil.copy2(source, masters_dir / source.name)

    pdfs_dir = STAGING_DIR / "pdfs"
    pdfs_dir.mkdir()
    for pdf_name, _ in PDFS:
        source = DOWNLOAD_DIR / pdf_name
        if not source.is_file():
            raise FileNotFoundError(source)
        shutil.copy2(source, pdfs_dir / pdf_name)

    build_contact_sheet(
        STAGING_DIR / "contact-sheet/common-boating-emergencies-contact-sheet.png"
    )
    build_mobile_review(STAGING_DIR / "mobile-review")
    render_pdf_pages(STAGING_DIR / "pdf-renders")
    inventory = build_inventory(STAGING_DIR / "inventory")
    write_review_notes(STAGING_DIR, inventory)
    build_zip(STAGING_DIR, ZIP_PATH)
    print(f"Built owner-review package: {ZIP_PATH}")
    print(f"Package size: {ZIP_PATH.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
