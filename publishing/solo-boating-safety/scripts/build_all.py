#!/usr/bin/env python3
"""Validate owner artwork and rebuild every Solo Boating Safety publication."""

from build_graphics import build as build_graphics
from build_publications import build_all_publications


def main() -> None:
    graphics = build_graphics()
    publications = build_all_publications()
    print(
        "Validated "
        f"{sum(path.suffix.lower() == '.png' for path in graphics)} "
        "owner-supplied publication figures."
    )
    for publication in publications:
        print(f"Built {publication}")


if __name__ == "__main__":
    main()
