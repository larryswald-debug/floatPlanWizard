"""Dedicated PostHog OTLP log exporter for publishing workflow milestones."""

from __future__ import annotations

import atexit
import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor


ROOT = Path(__file__).resolve().parents[1]
LOGGER_NAME = "floatplanwizard.posthog_logs"
load_dotenv(ROOT / ".env")


def initialize_posthog_logger() -> logging.Logger:
    """Configure an isolated logger so only purpose-written records are exported."""
    logger = logging.getLogger(LOGGER_NAME)
    logger.setLevel(logging.INFO)
    logger.propagate = False

    project_token = os.getenv("POSTHOG_PROJECT_TOKEN")
    host = os.getenv("POSTHOG_HOST")
    if not project_token or not host:
        logger.addHandler(logging.NullHandler())
        return logger

    logger_provider = LoggerProvider()
    exporter = OTLPLogExporter(
        endpoint=f"{host.rstrip('/')}/i/v1/logs",
        headers={"Authorization": f"Bearer {project_token}"},
        timeout=3,
    )
    logger_provider.add_log_record_processor(BatchLogRecordProcessor(exporter))
    logger.addHandler(LoggingHandler(logger_provider=logger_provider))
    atexit.register(logger_provider.shutdown, 3000)
    return logger


posthog_logger = initialize_posthog_logger()
