#!/usr/bin/env python3
"""Validate the owner-supplied Solo Boating Safety figure assets.

The artwork in assets/graphics is authoritative owner-supplied publication art.
This module deliberately does not redraw, reinterpret, or rasterize the figures.
Figures 1-1, 2-1, 2-2, 3-1, 3-2, 3-3, 3-4, 4-1, 4-2, 5-1, 6-1, 7-1, 8-1, and 10-1 are later PNG-only
replacements; every other figure retains its SVG master and PNG publication export.
"""

from __future__ import annotations

from json import load
from pathlib import Path

from lxml import etree
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GRAPHICS = ROOT / "assets" / "graphics"
SOURCE = GRAPHICS / "source"
EXPORT = GRAPHICS / "export"
MANIFEST = GRAPHICS / "graphics-manifest.json"


EXPECTED_FIGURES = (
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
)
PNG_ONLY_FIGURES = {
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


def build() -> list[Path]:
    """Validate and return the existing owner-supplied figure assets."""
    if not MANIFEST.is_file():
        raise FileNotFoundError(f"Owner graphics manifest is missing: {MANIFEST}")

    with MANIFEST.open(encoding="utf-8") as handle:
        entries = load(handle)
    manifest_names = tuple(entry.get("name", "") for entry in entries)
    if manifest_names != EXPECTED_FIGURES:
        raise ValueError(
            "Owner graphics manifest does not match the required ordered figure mapping: "
            f"{manifest_names}"
        )

    expected_svg_names = {
        f"{name}.svg" for name in EXPECTED_FIGURES if name not in PNG_ONLY_FIGURES
    }
    expected_png_names = {f"{name}.png" for name in EXPECTED_FIGURES}
    actual_svg_names = {path.name for path in SOURCE.glob("*.svg")}
    actual_png_names = {path.name for path in EXPORT.glob("*.png")}
    if actual_svg_names != expected_svg_names:
        raise ValueError(f"SVG asset set mismatch: {sorted(actual_svg_names)}")
    if actual_png_names != expected_png_names:
        raise ValueError(f"PNG asset set mismatch: {sorted(actual_png_names)}")

    outputs: list[Path] = []
    for entry in entries:
        name = entry["name"]
        png_path = EXPORT / entry["png"]
        svg_name = entry.get("svg")
        if png_path.name != f"{name}.png":
            raise ValueError(f"Manifest filename mismatch for {name}")
        if name in PNG_ONLY_FIGURES:
            if svg_name is not None:
                raise ValueError(f"{name} must remain explicitly PNG-only in the manifest")
        else:
            if svg_name != f"{name}.svg":
                raise ValueError(f"Manifest SVG filename mismatch for {name}")
            svg_path = SOURCE / svg_name
            etree.parse(str(svg_path))
            outputs.append(svg_path)
        with Image.open(png_path) as image:
            expected_size, expected_mode = EXPECTED_PNG_SPECS.get(
                name, ((1600, 900), "RGB")
            )
            if image.size != expected_size or image.mode != expected_mode:
                raise ValueError(
                    f"{png_path.name} is {image.size} {image.mode}; "
                    f"expected {expected_size} {expected_mode}"
                )
            image.verify()
        outputs.append(png_path)
    return outputs


if __name__ == "__main__":
    validated = build()
    print(
        "Validated "
        f"{sum(path.suffix.lower() == '.png' for path in validated)} "
        "owner-supplied publication figures."
    )
