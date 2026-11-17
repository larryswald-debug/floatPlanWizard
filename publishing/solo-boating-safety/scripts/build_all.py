#!/usr/bin/env python3
"""Validate owner artwork and rebuild every Solo Boating Safety publication."""

from build_graphics import build as build_graphics
from build_publications import build_all_publications
from posthog_client import posthog_client
from posthog_logs import posthog_logger


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
    posthog_logger.info(
        "publication build completed",
        extra={
            "entry_point": "build_all",
            "graphics_png_count": sum(
                path.suffix.lower() == ".png" for path in graphics
            ),
            "publication_output_count": len(publications),
        },
    )
    if posthog_client:
        posthog_client.capture(
            event="publication_build_completed",
            properties={
                "entry_point": "build_all",
                "graphics_png_count": sum(
                    path.suffix.lower() == ".png" for path in graphics
                ),
                "publication_output_count": len(publications),
            },
        )


if __name__ == "__main__":
    main()
