#!/usr/bin/env python3
"""Build responsive public derivatives for the Common Boating Emergencies guide."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[3]
PUBLIC_DIR = ROOT / "assets/images/boating-guides/common-boating-emergencies"
SOURCE_DIR = ROOT / "publishing/common-boating-emergencies/assets/source"
MANIFEST_PATH = ROOT / "publishing/common-boating-emergencies/assets/image-derivatives-manifest.json"

ASSETS = (
    "common-boating-emergencies-hero",
    "boating-emergency-pace-first-minute",
    "boat-engine-failure-drift-anchor",
    "boat-taking-on-water-checkpoints",
    "boat-grounding-stop-assess",
    "person-overboard-controlled-recovery",
    "boat-engine-compartment-fire-response",
    "boating-storm-early-shelter-decision",
    "marine-vhf-mayday-prepared-card",
    "capsize-stay-with-boat-visibility",
    "boat-carbon-monoxide-danger-zones",
    "overdue-boater-response-information-chain",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def derivative_name(stem: str, width: int, full_width: int, suffix: str) -> str:
    width_part = "" if width == full_width else f"-{width}w"
    return f"{stem}{width_part}.{suffix}"


def build_asset(stem: str) -> dict[str, object]:
    source_path = SOURCE_DIR / f"{stem}-master.png"
    if not source_path.is_file():
        raise FileNotFoundError(f"Missing image master: {source_path}")

    with Image.open(source_path) as source:
        source = ImageOps.exif_transpose(source).convert("RGB")
        full_width, full_height = source.size
        widths = [width for width in (640, 960, full_width) if width <= full_width]
        widths = sorted(set(widths))
        derivatives: list[dict[str, object]] = []

        for width in widths:
            height = round(full_height * width / full_width)
            image = source if width == full_width else source.resize((width, height), Image.Resampling.LANCZOS)

            for suffix in ("webp", "jpg"):
                filename = derivative_name(stem, width, full_width, suffix)
                output_path = PUBLIC_DIR / filename
                if suffix == "webp":
                    image.save(output_path, "WEBP", quality=82, method=6, exact=True)
                else:
                    image.save(
                        output_path,
                        "JPEG",
                        quality=84,
                        optimize=True,
                        progressive=True,
                        subsampling="4:2:0",
                    )
                derivatives.append(
                    {
                        "file": filename,
                        "format": suffix,
                        "width": width,
                        "height": height,
                        "bytes": output_path.stat().st_size,
                        "sha256": sha256(output_path),
                    }
                )

    return {
        "stem": stem,
        "source": source_path.relative_to(ROOT).as_posix(),
        "source_width": full_width,
        "source_height": full_height,
        "source_sha256": sha256(source_path),
        "derivatives": derivatives,
    }


def main() -> None:
    PUBLIC_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)

    expected_names: set[str] = set()
    assets = []
    for stem in ASSETS:
        asset = build_asset(stem)
        assets.append(asset)
        expected_names.update(item["file"] for item in asset["derivatives"])

    for path in PUBLIC_DIR.iterdir():
        if path.is_file() and path.suffix.lower() in {".jpg", ".webp"} and path.name not in expected_names:
            raise RuntimeError(f"Unexpected derivative in output directory: {path}")

    manifest = {
        "builder": "publishing/common-boating-emergencies/scripts/build_images.py",
        "public_directory": PUBLIC_DIR.relative_to(ROOT).as_posix(),
        "formats": ["webp", "jpg"],
        "responsive_widths": [640, 960, "source_width"],
        "assets": assets,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(f"Built {sum(len(asset['derivatives']) for asset in assets)} derivatives for {len(assets)} assets.")
    print(f"Manifest: {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
