"""Shared PostHog client for the publishing scripts."""

from __future__ import annotations

import atexit
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from posthog import Posthog


ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")


def _missing_configuration_warning(variable: str) -> None:
    print(
        f"{variable} variable required by PostHog is missing or un-configured, "
        f"this causes events to be silently missed. This error stops appearing once "
        f"{variable} is configured",
        file=sys.stderr,
    )


def initialize_posthog() -> Posthog | None:
    """Create the process-wide PostHog client when configuration is available."""
    project_token = os.getenv("POSTHOG_PROJECT_TOKEN")
    host = os.getenv("POSTHOG_HOST")

    if not project_token:
        _missing_configuration_warning("POSTHOG_PROJECT_TOKEN")
    if not host:
        _missing_configuration_warning("POSTHOG_HOST")
    if not project_token or not host:
        return None

    return Posthog(
        project_token,
        host=host,
        enable_exception_autocapture=True,
    )


posthog_client = initialize_posthog()

if posthog_client:
    atexit.register(posthog_client.shutdown)
