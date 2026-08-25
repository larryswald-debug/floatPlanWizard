from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from pypdf import PdfReader, PdfWriter
from pypdf.generic import ContentStream, NullObject


ROOT = Path(__file__).resolve().parents[1]
INDIVIDUAL_CARDS = {
    "first-60-seconds-pace.pdf": (),
    "mayday-vhf-channel-16-script.pdf": (
        "boat_name",
        "call_sign_or_registration",
        "boat_name_repeat",
        "position",
        "nature_of_distress",
        "assistance_requested",
        "people_aboard",
        "injuries_or_medical",
        "boat_description",
        "other_information",
    ),
    "pan-pan-vhf-channel-16-script.pdf": (
        "boat_name",
        "call_sign_or_registration",
        "boat_name_repeat",
        "position",
        "nature_of_urgent_problem",
        "assistance_requested",
        "people_aboard",
        "injuries_or_medical",
        "boat_description",
        "other_information",
    ),
    "boat-specific-emergency-fields.pdf": (
        "boat_name",
        "call_sign_or_registration",
        "mmsi",
        "boat_description",
        "vhf_location",
        "epirb_plb_location",
        "first_aid_location",
        "extinguisher_location",
        "seacock_location",
        "shore_contact_name",
        "shore_contact_phone",
    ),
}
MULTILINE_FIELDS = {
    "first-60-seconds-pace.pdf": (),
    "mayday-vhf-channel-16-script.pdf": (
        "nature_of_distress",
        "assistance_requested",
        "other_information",
    ),
    "pan-pan-vhf-channel-16-script.pdf": (
        "nature_of_urgent_problem",
        "assistance_requested",
        "other_information",
    ),
    "boat-specific-emergency-fields.pdf": (),
}


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
        self.individual = {
            filename: PdfReader(ROOT / "downloads" / filename, strict=True)
            for filename in INDIVIDUAL_CARDS
        }

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
            resources = page["/Resources"]["/Font"]
            selected_fonts = {
                str(operands[0])
                for operands, operator in ContentStream(
                    page.get_contents(), reader
                ).operations
                if operator == b"Tf"
            }
            for font_name in selected_fonts:
                font_ref = resources[font_name]
                font = font_ref.get_object()
                base_font = str(font.get("/BaseFont", ""))
                descriptor_ref = font.get("/FontDescriptor")
                self.assertIsNotNone(descriptor_ref, base_font)
                descriptor = descriptor_ref.get_object()
                self.assertTrue(
                    any(key in descriptor for key in ("/FontFile", "/FontFile2", "/FontFile3")),
                    base_font,
                )
                if "ArialNarrow" in base_font:
                    found.add(base_font.split("+")[-1])
        self.assertEqual(found, {"ArialNarrow", "ArialNarrow-Bold"})

    def assert_tagged_structure(self, reader: PdfReader) -> None:
        catalog = reader.trailer["/Root"]
        self.assertIn("/StructTreeRoot", catalog)
        self.assertEqual(catalog["/Lang"], "en-US")
        self.assertTrue(catalog["/MarkInfo"]["/Marked"])
        self.assertFalse(catalog["/MarkInfo"]["/Suspects"].value)
        self.assertTrue(catalog["/ViewerPreferences"]["/DisplayDocTitle"])

        struct_root = catalog["/StructTreeRoot"].get_object()
        self.assertIn("/ParentTree", struct_root)
        roles = []

        def collect_roles(value) -> None:
            current = value.get_object() if hasattr(value, "get_object") else value
            if not isinstance(current, dict):
                return
            if "/S" in current:
                roles.append(str(current["/S"]))
            children = current.get("/K")
            if isinstance(children, list):
                for child in children:
                    collect_roles(child)
            elif children is not None and not isinstance(children, (int, float, str)):
                collect_roles(children)

        collect_roles(struct_root)
        for role in ("/Document", "/Sect", "/H1", "/H2", "/P", "/L", "/LI", "/LBody"):
            self.assertIn(role, roles)

        parent_numbers = struct_root["/ParentTree"].get_object()["/Nums"]
        self.assertEqual(len(parent_numbers), len(reader.pages) * 2)
        for page_index, page in enumerate(reader.pages):
            self.assertEqual(page["/StructParents"], page_index)
            self.assertEqual(page["/Tabs"], "/S")
            self.assertEqual(parent_numbers[page_index * 2], page_index)
            parents = parent_numbers[page_index * 2 + 1]
            content = page.get_contents().get_data()
            self.assertEqual(len(parents), content.count(b"/MCID"))
            self.assertTrue(all(not isinstance(parent, NullObject) for parent in parents))
            self.assertGreater(content.count(b"/Artifact BMC"), 0)

    def assert_individual_tagged_structure(self, reader: PdfReader) -> None:
        catalog = reader.trailer["/Root"]
        self.assertIn("/StructTreeRoot", catalog)
        self.assertEqual(catalog["/Lang"], "en-US")
        self.assertTrue(catalog["/MarkInfo"]["/Marked"])
        self.assertFalse(catalog["/MarkInfo"]["/Suspects"].value)
        self.assertTrue(catalog["/ViewerPreferences"]["/DisplayDocTitle"])
        struct_root = catalog["/StructTreeRoot"].get_object()
        roles = []

        def collect_roles(value) -> None:
            current = value.get_object() if hasattr(value, "get_object") else value
            if not isinstance(current, dict):
                return
            if "/S" in current:
                roles.append(str(current["/S"]))
            children = current.get("/K")
            if isinstance(children, list):
                for child in children:
                    collect_roles(child)
            elif children is not None and not isinstance(children, (int, float, str)):
                collect_roles(children)

        collect_roles(struct_root)
        for role in ("/Document", "/Sect", "/H1", "/H2", "/P"):
            self.assertIn(role, roles)
        page = reader.pages[0]
        self.assertEqual(page["/Tabs"], "/S")
        self.assertEqual(page.cropbox, page.mediabox)
        self.assertGreater(page.get_contents().get_data().count(b"/Artifact BMC"), 0)

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
            self.assert_tagged_structure(reader)

    def test_four_by_six_has_selectable_front_then_back_content(self) -> None:
        front = " ".join((self.four_by_six.pages[0].extract_text() or "").split())
        back = " ".join((self.four_by_six.pages[1].extract_text() or "").split())

        front_markers = (
            "First 60 seconds - P.A.C.E.",
            "P - People",
            "A - Assess",
            "C - Control",
            "E - Emergency call",
            "Revision: August 22, 2026 | Print at 100% / Actual Size | Short-edge duplex",
        )
        back_markers = (
            "Mayday voice script - VHF Channel 16",
            "MAYDAY, MAYDAY, MAYDAY",
            "THIS IS [BOAT NAME] ×3",
            "POSITION [lat/long or clear location]",
            "Boat-specific fields",
            "P.A.C.E. is a FloatPlanWizard quick-recall framework; follow official responder instructions.",
            "Revision: August 22, 2026 | Print at 100% / Actual Size | Short-edge duplex",
        )
        self.assertEqual([front.index(marker) for marker in front_markers], sorted(front.index(marker) for marker in front_markers))
        self.assertEqual([back.index(marker) for marker in back_markers], sorted(back.index(marker) for marker in back_markers))
        self.assertNotIn("\ufffd", front + back)
        self.assertIn(
            "DSC alert first if MMSI/GPS are configured; then voice on Ch 16.",
            front,
        )
        self.assertNotIn("THIS IS [BOAT NAME] three times", back)
        self.assertNotIn("DSC first if configured", front)

    def test_letter_pdf_is_two_up_at_actual_card_size_with_front_and_back(self) -> None:
        text = self.normalized_text(self.letter)
        self.assertEqual(text.count("First 60 seconds - P.A.C.E."), 2)
        self.assertEqual(text.count("MAYDAY, MAYDAY, MAYDAY"), 2)
        self.assertEqual(text.count("THIS IS [BOAT NAME] ×3"), 2)
        self.assertEqual(
            text.count("DSC alert first if MMSI/GPS are configured; then voice on Ch 16."),
            2,
        )
        self.assertEqual(text.count("Revision: August 22, 2026"), 4)
        self.assertIn("Print at 100% / Actual Size", text)
        self.assertIn("Cut on the corner marks", text)
        self.assertIn("Two-up preserves the actual 4x6-inch card dimensions", text)
        self.assertNotIn("\ufffd", text)

    def test_individual_cards_are_single_page_letter_pdfs_with_live_tagged_text(self) -> None:
        expected_text = {
            "first-60-seconds-pace.pdf": (
                "FloatPlanWizard Boating Emergency Quick Reference",
                "Front",
                "First 60 seconds — P.A.C.E.",
                "P — People",
                "A — Assess",
                "C — Control",
                "E — Emergency call",
            ),
            "mayday-vhf-channel-16-script.pdf": (
                "Mayday voice script — VHF Channel 16",
                "MAYDAY, MAYDAY, MAYDAY",
                "THIS IS",
                "Call sign/registration",
                "POSITION",
                "WE ARE",
                "WE NEED",
                "PEOPLE ABOARD;",
                "BOAT IS",
                "OTHER:",
                "OVER",
                "Stay by the radio. Repeat if no answer.",
            ),
            "pan-pan-vhf-channel-16-script.pdf": (
                "URGENT — NOT DISTRESS",
                "PAN-PAN voice script — VHF Channel 16",
                "PAN-PAN, PAN-PAN, PAN-PAN",
                "ALL STATIONS, ALL STATIONS, ALL STATIONS",
                "WE HAVE",
                "WE REQUIRE",
                "Use PAN-PAN when the safety of the boat or a person is in jeopardy, but there is no grave and imminent danger.",
                "PAN-PAN is pronounced “pahn-pahn.”",
            ),
            "boat-specific-emergency-fields.pdf": (
                "Boat-specific fields",
                "Boat name:",
                "Registration/call sign:",
                "MMSI:",
                "Length/type/color:",
                "Emergency equipment locations:",
                "Shore contact:",
                "P.A.C.E. is a FloatPlanWizard quick-recall framework; follow official responder instructions.",
            ),
        }
        for filename, reader in self.individual.items():
            with self.subTest(filename=filename):
                self.assertEqual(len(reader.pages), 1)
                self.assert_page_size(reader, 612, 792)
                self.assertTrue(reader.metadata.title.startswith("FloatPlanWizard Boating Emergency Quick Reference - "))
                self.assertEqual(reader.metadata.author, "FloatPlanWizard")
                self.assert_embedded_card_fonts(reader)
                self.assert_individual_tagged_structure(reader)
                text = self.normalized_text(reader)
                for marker in expected_text[filename]:
                    self.assertIn(marker, text)
                self.assertIn(
                    "Keep this card where the operator and passengers can reach it. Follow official Coast Guard and emergency-responder instructions.",
                    text,
                )
                self.assertIn("FloatPlanWizard.com", text)
                self.assertNotIn("\ufffd", text)

    def test_fillable_cards_have_named_optional_fields_tooltips_and_safe_actions(self) -> None:
        for filename, expected_names in INDIVIDUAL_CARDS.items():
            reader = self.individual[filename]
            catalog = reader.trailer["/Root"]
            fields = reader.get_fields() or {}
            widgets = [
                annotation.get_object()
                for page in reader.pages
                for annotation in (page.get("/Annots") or [])
                if annotation.get_object().get("/Subtype") == "/Widget"
            ]
            with self.subTest(filename=filename):
                self.assertEqual(tuple(fields), expected_names)
                self.assertEqual(tuple(str(widget.get("/T")) for widget in widgets), expected_names)
                self.assertEqual(len(set(expected_names)), len(expected_names))
                self.assertNotIn("/OpenAction", catalog)
                self.assertNotIn("/AA", catalog)
                names = catalog.get("/Names")
                if names is not None:
                    self.assertNotIn("/JavaScript", names.get_object())
                if expected_names:
                    self.assertIn("/AcroForm", catalog)
                    self.assertNotIn("/XFA", catalog["/AcroForm"])
                else:
                    self.assertNotIn("/AcroForm", catalog)
                for widget in widgets:
                    field_name = str(widget.get("/T"))
                    self.assertTrue(str(widget.get("/TU", "")).strip())
                    self.assertEqual(int(widget.get("/Ff", 0)) & 2, 0)
                    self.assertEqual(
                        bool(int(widget.get("/Ff", 0)) & 4096),
                        field_name in MULTILINE_FIELDS[filename],
                    )
                    self.assertNotIn("/A", widget)
                    self.assertNotIn("/AA", widget)
                    self.assertEqual(str(widget.get("/V", "")), "")
                    normal_appearance = widget.get("/AP", {}).get("/N")
                    self.assertIsNotNone(normal_appearance)
                    self.assertGreater(len(normal_appearance.get_object().get_data()), 0)

    def test_filled_values_save_and_regenerated_appearances_remain_visible(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            for filename, expected_names in INDIVIDUAL_CARDS.items():
                if not expected_names:
                    continue
                reader = self.individual[filename]
                values = {
                    name: f"TEST {index + 1}"
                    for index, name in enumerate(expected_names)
                }
                writer = PdfWriter()
                writer.clone_document_from_reader(reader)
                writer.update_page_form_field_values(
                    None, values, auto_regenerate=False
                )
                target = Path(temporary_directory) / filename
                with target.open("wb") as stream:
                    writer.write(stream)
                reopened = PdfReader(target, strict=True)
                reopened_fields = reopened.get_fields() or {}
                widgets = [
                    annotation.get_object()
                    for page in reopened.pages
                    for annotation in (page.get("/Annots") or [])
                    if annotation.get_object().get("/Subtype") == "/Widget"
                ]
                with self.subTest(filename=filename):
                    self.assertEqual(tuple(reopened_fields), expected_names)
                    for widget in widgets:
                        name = str(widget["/T"])
                        self.assertEqual(str(widget["/V"]), values[name])
                        appearance = widget["/AP"]["/N"].get_object().get_data()
                        self.assertGreater(len(appearance), 0)


if __name__ == "__main__":
    unittest.main()
