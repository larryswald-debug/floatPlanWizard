from __future__ import annotations

import unittest
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]


class EmergencyCardPdfTests(unittest.TestCase):
    def setUp(self) -> None:
        self.four_by_six = PdfReader(
            ROOT / "downloads/floatplanwizard-boating-emergency-card-4x6.pdf",
            strict=True,
        )
        self.letter = PdfReader(
            ROOT / "downloads/floatplanwizard-boating-emergency-card-letter.pdf",
            strict=True,
        )

    @staticmethod
    def normalized_text(reader: PdfReader) -> str:
        return " ".join(
            "\n".join(page.extract_text() or "" for page in reader.pages).split()
        )

    def assert_page_size(self, reader: PdfReader, width: int, height: int) -> None:
        for page in reader.pages:
            self.assertAlmostEqual(float(page.mediabox.width), width, delta=0.1)
            self.assertAlmostEqual(float(page.mediabox.height), height, delta=0.1)
            self.assertEqual(page.cropbox, page.mediabox)

    def assert_embedded_card_fonts(self, reader: PdfReader) -> None:
        found = set()
        for page in reader.pages:
            for font_ref in page["/Resources"]["/Font"].values():
                font = font_ref.get_object()
                base_font = str(font.get("/BaseFont", ""))
                if "ArialNarrow" not in base_font:
                    continue
                descriptor_ref = font.get("/FontDescriptor")
                self.assertIsNotNone(descriptor_ref, base_font)
                descriptor = descriptor_ref.get_object()
                self.assertTrue(
                    any(key in descriptor for key in ("/FontFile", "/FontFile2", "/FontFile3")),
                    base_font,
                )
                found.add(base_font.split("+")[-1])
        self.assertEqual(found, {"ArialNarrow", "ArialNarrow-Bold"})

    def test_metadata_language_pages_and_dimensions(self) -> None:
        self.assertEqual(len(self.four_by_six.pages), 2)
        self.assertEqual(len(self.letter.pages), 2)
        self.assert_page_size(self.four_by_six, 432, 288)
        self.assert_page_size(self.letter, 612, 792)

        for reader, expected_title in (
            (self.four_by_six, "FloatPlanWizard Boating Emergency Card - 4x6"),
            (self.letter, "FloatPlanWizard Boating Emergency Card - Letter Two-Up"),
        ):
            self.assertEqual(reader.metadata.title, expected_title)
            self.assertEqual(reader.metadata.author, "FloatPlanWizard")
            self.assertEqual(reader.trailer["/Root"]["/Lang"], "en-US")
            self.assert_embedded_card_fonts(reader)

    def test_four_by_six_has_selectable_front_then_back_content(self) -> None:
        front = " ".join((self.four_by_six.pages[0].extract_text() or "").split())
        back = " ".join((self.four_by_six.pages[1].extract_text() or "").split())

        front_markers = (
            "First 60 seconds - P.A.C.E.",
            "P - People",
            "A - Assess",
            "C - Control",
            "E - Emergency call",
            "Revision: August 22, 2026",
        )
        back_markers = (
            "Mayday voice script - VHF Channel 16",
            "MAYDAY, MAYDAY, MAYDAY",
            "POSITION [lat/long or clear location]",
            "Boat-specific fields",
            "P.A.C.E. is a FloatPlanWizard quick-recall framework; follow official responder instructions.",
            "Revision: August 22, 2026",
        )
        self.assertEqual([front.index(marker) for marker in front_markers], sorted(front.index(marker) for marker in front_markers))
        self.assertEqual([back.index(marker) for marker in back_markers], sorted(back.index(marker) for marker in back_markers))
        self.assertNotIn("\ufffd", front + back)

    def test_letter_pdf_is_two_up_at_actual_card_size_with_front_and_back(self) -> None:
        text = self.normalized_text(self.letter)
        self.assertEqual(text.count("First 60 seconds - P.A.C.E."), 2)
        self.assertEqual(text.count("MAYDAY, MAYDAY, MAYDAY"), 2)
        self.assertEqual(text.count("Revision: August 22, 2026"), 4)
        self.assertIn("Print at 100% / Actual Size", text)
        self.assertIn("Cut on the corner marks", text)
        self.assertIn("Two-up preserves the actual 4x6-inch card dimensions", text)
        self.assertNotIn("\ufffd", text)


if __name__ == "__main__":
    unittest.main()
