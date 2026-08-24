from __future__ import annotations

import hashlib
import json
import subprocess
import unittest
import zipfile
from pathlib import Path, PurePosixPath

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PUBLISHING_ROOT = ROOT / "publishing/common-boating-emergencies"
REVIEW_ROOT = PUBLISHING_ROOT / "review"
PACKAGE_NAME = "common-boating-emergencies-owner-review"
STAGING_ROOT = REVIEW_ROOT / PACKAGE_NAME
ZIP_PATH = REVIEW_ROOT / f"{PACKAGE_NAME}.zip"
PUBLIC_ROOT = ROOT / "assets/images/boating-guides/common-boating-emergencies"
SOURCE_ROOT = PUBLISHING_ROOT / "assets/source"
ENGINE_FAILURE_STEM = "boat-engine-failure-drift-anchor"
NEW_ENGINE_FAILURE_MASTER_SHA256 = "874786a1ced2174bf3e59d71d51302c89fd309f2e6d5c44c07617c3ea21fcdc7"
OLD_ENGINE_FAILURE_HASHES = {
    "96275e4a3863b04b2d8ce4db196484be7fba5ff5414e85b2e358a55fc4c1be3d",
    "6af7223aa9739d58ddc50fcbd47c395f796e10f8206dcacf88dcb3f054a4ca19",
    "21652fc573088dca1bf764eab628f2407e1bcc402e651b794fe574919f76f482",
    "3e0b9dcf46ea5edeecdb73d7c2b20d99ed37984dcc6f329fbb0c8a2b2ea07d7a",
    "eb2977d3cd0e8d067ac5a2d0a248cb2aa6577d493cea9cfefc86fac242405b66",
    "1dc23a184ff8ac456fe36cf964ff3ff223ea45e7ae9798588f43adf9f9aac348",
    "4218bac62ead3390f95a0fe317fab87bbd7a32ee8eb04ee83cf59b9aa6a8fe06",
}
GROUNDING_STEM = "boat-grounding-stop-assess"
NEW_GROUNDING_MASTER_SHA256 = "57d7176b62f083692e1534f9693261642dabefeaf27ec60e02090447aae893d6"
OLD_GROUNDING_HASHES = {
    "aeb8357e5ef8c385e2d23a017a9385a3043cfd81438fdec09cfd2be61c724d34",
    "e012b771e3521e51763d1afade52f457b169965c72cb37883ecfb3c48e411de6",
    "25d0b7d9f59a297c51eb4c53c81f2d0826414403187ce431c7cfa7f7721e7812",
    "533a66687aa10aa9822ee24f4dbb97e52230d6ed93f28b75f99c86f73e98ed9a",
    "24b8bd2dc71b4e36f1dd19ed6fa14a400f79611386dd034dc4a8b894b8c6f860",
    "5a95fcf9805932d7f633122e341af8bf1fa9bc732885766086a86ced31eab493",
    "0e552a7ba8ecf6ba876ae9796db986ceaccd54738b231c199144cb1de0ab7f27",
}
PERSON_OVERBOARD_STEM = "person-overboard-controlled-recovery"
NEW_PERSON_OVERBOARD_MASTER_SHA256 = "71956fe70976378d4fcbf8565e445bb9ead8af34c11cadd3b16d807bc65d960b"
OLD_PERSON_OVERBOARD_HASHES = {
    "5bcb2e94c17a25d302edd64485d534715fc7e8cce649a8fc8c679e7f7803e9c5",
    "2986f56d929565225c578e5071fb572befd1f0db3ba9cebcf4365c2e57cba22a",
    "da2ada4dc524b9b897cb835235a183884d860fc0493040c2bd325fbdb12f1b4b",
    "0b2095eb1938e53a368eae7036c34c1d374fd24222b370bb843ad0b4f708f8bf",
    "e0ffb31fac5c897956538e0c09ffbb238048d38d67340afe853cdbfdeacc1375",
    "6b6e8e3c77ce63aa51de3a3d73bdd9eefa36e677018bb081cf9d51330252efaa",
    "e7a3788f2565275864256e42b9e5745b1338c6a337d454eb89bd7a8d4c12020b",
}
FIRE_STEM = "boat-engine-compartment-fire-response"
NEW_FIRE_MASTER_SHA256 = "08f2822ae9530cb0f065e01606d8302ac126741c6fa96c675a23fa0ace739d1b"
OLD_FIRE_HASHES = {
    "0ecefa1aed09838d5979dfadf9a5b1bb1834bbf1c081b2d912ea77b99f39dc66",
    "ce486745a871d5986350c6bb05489ec0f89555b25eb31238027011ed2ef3825d",
    "a70425c5ae5c491705abf1fe469aab6237cacbab731eb8e6f2c8920a0899412a",
    "66777582cc59eca976da9faf14e7db418a05054080ea868333e7b371cf33685f",
    "1347c47a0eaaed6cf60449f0840c23b79fbc40076335b8441414a1607ac34636",
    "b2f05f8f587932e0bdb2cfadb7fb43b7a2d3a7e689988ecd13dd95eab14e0ce4",
    "99c46759cf7d6086c5d8c1a4c0ed3d50aff3663f3fb78f0a7070b817fe1f860e",
    "40688bbd826af7b9f4c8085bd9f8dc9b730d1083a5122756ac3629396a543773",
    "1601a496af1e74de996509dee3e7891d47b7db216c6648695cc73f6b6b867ea6",
    "10d29e9d0aabc00ce7543373b7b282d53cb55590e23a2d7e9e8f4ed0041c689a",
    "b33976f3304fb0d8716c9dd16f886922a34f3e3e7311e9fa0714925df2c2c3f7",
    "6c25bc1cbc6247506b06985218cc7d2f84cd4aed92935d214fe857d98e526051",
    "f86bc6a3683da52fdc474a67d15e124e140ea7411b5e3db7b69d8edc445167fd",
    "1e67b35af41adfb17a70940b0fa492fa7055afd83b85e7cac1886f43d72c61d5",
}
STORM_STEM = "boating-storm-early-shelter-decision"
NEW_STORM_MASTER_SHA256 = "e405bd28aaff2a9c033c56d66960cbdc48f4a93ffe9de93d5c4b1234bca8586a"
OLD_STORM_HASHES = {
    "57f1275c429743712e837673d76e03ed792b34473ea4509bbbd163f28a73039f",
    "04ebdfc621258dac2ce6ce1a785a4852ced9249847d0f3b810ed7b272592eb68",
    "f52b751ff0adee498183319fb76a9dbd17e12da2c6caf88088474efc0811606e",
    "74b49ac4ebf886ec548c5c1b6bbdad19f7214e251292e9a6e48587119a279acd",
    "9537d429ea4f909c7b14084631c1283641063a790774e3ec39a00b60622c885e",
    "5c3e1ff6d73c8a51c4dbf4ca4b7a577cf7aa0b72c58b021acb62a6bbb91b3d08",
    "2e39e6e8ece4088e6e0c56288dde21626db73e84ca4b3b48bf112fd5eadcf0e0",
    "a0aaae8400b3ac6351d74c2f1c80d5a49ccc04264d6b808d0568a5cac8075c40",
    "853fbea715ba1d411bdcf60c248116af3f58bc73827b6c49c17e9d9dabb36fd3",
    "06e8c16da6476aac8944d3c57b57449550c3d2eaa98c34c46b392cb445bbfccd",
    "2c520029658eceb5dbb5f348b9cc603499b9ea68c02aa81f4db35ab6156768e7",
    "6f6ea9301da7dadc24f130572be13151a19ae72642f3192d9c7e310cbd5a0daa",
    "3f08905ae1fe9eaa138816c7e57c6e800c3bf83fa8182c6fbe55220d65243789",
    "9e73baf72d87c6826aa644702ec7eb18d58418078895105601f129f99a965446",
}
MAYDAY_STEM = "marine-vhf-mayday-prepared-card"
NEW_MAYDAY_MASTER_SHA256 = "12ec5c95a1881bbb853185610b402d980a40f75f876310a1915dd40e697e975c"
OLD_MAYDAY_HASHES = {
    "1558b8e3758700f49e663c44b84a89342b06ac94b4d0cdd6c2a12f6d34abd3f5",
    "82ccdf0ef437470c02dff8f00cc2fb188764fce469ce5ca6678531302c2771f8",
    "c5410a9d9f498a592076de4ed3c0bda1b9c18eaa3b6ab2c0a54eb62b21d5b898",
    "2c4fe4bbd606496d231eb2a009fc3152508f0605ef96f8ea155f917546a9cd63",
    "17ba109b849bd6a881b03686ad56584a16a4b57264fc7e30c4b16a68c77d184b",
    "191c6f1278660a0d2d0c24a30b12e558df30a9948e439b2fad34ead3038dda89",
    "0b00286e3fde131994b2af095b9078d5478fedbf04e7d5261b89f0b75e11612f",
}
OVERDUE_STEM = "overdue-boater-response-information-chain"
NEW_OVERDUE_MASTER_SHA256 = "2b5d215bb93f11ae40602c8446d2f04b93e2ed7abfd174e456f52131d55d310d"
OLD_OVERDUE_HASHES = {
    "41881efc6f04f3debc14cbf6ebdcc9679685b88afddee7b4278e08f1fdd29d30",
    "84d2a1799a90a42d508062b12d02f2e053595e6c998d1be405d6b3285af1ac15",
    "7d9885c263fd670708d89f83374ea34bd89699418c26fd0f68d68fd210ad4926",
    "ee890e63d91d8ec254b9b3752de5ca75a3b05e14e8cb6f7feb0478e05f9f759e",
    "f95d7e23567063681f48c0f3eb5672951806a4b7665fab6ede08f47377668967",
    "b3ef04396b38898c6634aef5eda1dfd33e2600df328acbcac65409d5e8b1b43c",
    "576369d0bb539550a0662d04b7f648b57b3fe1826ebb67cb0615367b3f1ac159",
}

STEMS = (
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

MOBILE_STEMS = (
    "person-overboard-controlled-recovery",
    "boat-taking-on-water-checkpoints",
    "boat-engine-compartment-fire-response",
    "boating-storm-early-shelter-decision",
    "boat-carbon-monoxide-danger-zones",
    "boat-grounding-stop-assess",
    "marine-vhf-mayday-prepared-card",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class CommonBoatingEmergenciesPhase3Tests(unittest.TestCase):
    def test_owner_review_package_has_every_required_artifact(self) -> None:
        self.assertTrue(ZIP_PATH.is_file())
        self.assertGreater(ZIP_PATH.stat().st_size, 0)
        with zipfile.ZipFile(ZIP_PATH) as archive:
            self.assertIsNone(archive.testzip())
            names = set(archive.namelist())
            prefix = f"{PACKAGE_NAME}/"
            required = {
                f"{prefix}README.md",
                f"{prefix}CHANGELOG.md",
                f"{prefix}physical-print-checklist.md",
                f"{prefix}contact-sheet/common-boating-emergencies-contact-sheet.png",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
                f"{prefix}pdf-renders/emergency-card-4x6-page-1-front.png",
                f"{prefix}pdf-renders/emergency-card-4x6-page-2-back.png",
                f"{prefix}pdf-renders/emergency-card-letter-page-1-fronts.png",
                f"{prefix}pdf-renders/emergency-card-letter-page-2-backs.png",
                f"{prefix}pdfs/floatplanwizard-boating-emergency-card-4x6.pdf",
                f"{prefix}pdfs/floatplanwizard-boating-emergency-card-letter.pdf",
            }
            required.update(f"{prefix}masters/{stem}-master.png" for stem in STEMS)
            required.update(
                f"{prefix}mobile-review/{stem}-mobile-375w.png"
                for stem in MOBILE_STEMS
            )
            required.add(
                f"{prefix}mobile-review/{MAYDAY_STEM}-mobile-320w.png"
            )
            self.assertTrue(required.issubset(names), sorted(required - names))

            for stem in STEMS:
                packaged = archive.read(f"{prefix}masters/{stem}-master.png")
                self.assertEqual(
                    hashlib.sha256(packaged).hexdigest(),
                    sha256(SOURCE_ROOT / f"{stem}-master.png"),
                )

            for filename in (
                "floatplanwizard-boating-emergency-card-4x6.pdf",
                "floatplanwizard-boating-emergency-card-letter.pdf",
            ):
                packaged = archive.read(f"{prefix}pdfs/{filename}")
                self.assertEqual(
                    hashlib.sha256(packaged).hexdigest(),
                    sha256(ROOT / "downloads" / filename),
                )

            self.assertEqual(len(names), len(archive.namelist()))
            for name in names:
                archive_path = PurePosixPath(name)
                self.assertFalse(archive_path.is_absolute(), name)
                self.assertNotIn("..", archive_path.parts, name)
                self.assertTrue(name.startswith(prefix), name)
                self.assertFalse(any(part.startswith(".") for part in archive_path.parts), name)
                self.assertFalse(name.endswith((".bak", ".backup", ".orig", "~")), name)

    def test_contact_sheet_mobile_and_pdf_page_renders_are_valid_pngs(self) -> None:
        contact_sheet = (
            STAGING_ROOT
            / "contact-sheet/common-boating-emergencies-contact-sheet.png"
        )
        with Image.open(contact_sheet) as image:
            self.assertEqual(image.format, "PNG")
            self.assertGreaterEqual(image.width, 2400)
            self.assertGreaterEqual(image.height, 2400)

        for stem in MOBILE_STEMS:
            with Image.open(
                STAGING_ROOT / f"mobile-review/{stem}-mobile-375w.png"
            ) as image:
                self.assertEqual(image.format, "PNG")
                self.assertEqual(image.width, 415)
                self.assertGreater(image.height, 300)

        with Image.open(
            STAGING_ROOT / f"mobile-review/{MAYDAY_STEM}-mobile-320w.png"
        ) as image:
            self.assertEqual(image.format, "PNG")
            self.assertEqual(image.width, 360)
            self.assertGreater(image.height, 300)

        for filename in (
            "emergency-card-4x6-page-1-front.png",
            "emergency-card-4x6-page-2-back.png",
            "emergency-card-letter-page-1-fronts.png",
            "emergency-card-letter-page-2-backs.png",
        ):
            with Image.open(STAGING_ROOT / "pdf-renders" / filename) as image:
                self.assertEqual(image.format, "PNG")
                self.assertGreater(image.width, 1000)
                self.assertGreater(image.height, 700)

    def test_inventory_counts_totals_and_largest_files_match_repository(self) -> None:
        inventory = json.loads(
            (STAGING_ROOT / "inventory/asset-inventory.json").read_text()
        )
        self.assertEqual(
            inventory["counts"],
            {
                "public_derivatives": 72,
                "source_masters": 12,
                "download_pdfs": 2,
            },
        )
        public_total = sum(path.stat().st_size for path in PUBLIC_ROOT.iterdir())
        source_total = sum(
            (SOURCE_ROOT / f"{stem}-master.png").stat().st_size for stem in STEMS
        )
        pdf_total = sum(
            (ROOT / "downloads" / filename).stat().st_size
            for filename in (
                "floatplanwizard-boating-emergency-card-4x6.pdf",
                "floatplanwizard-boating-emergency-card-letter.pdf",
            )
        )
        self.assertEqual(inventory["totals"]["public_derivative_bytes"], public_total)
        self.assertEqual(inventory["totals"]["source_master_bytes"], source_total)
        self.assertEqual(inventory["totals"]["download_pdf_bytes"], pdf_total)
        self.assertEqual(
            inventory["totals"]["repository_asset_bytes"],
            public_total + source_total + pdf_total,
        )
        self.assertEqual(len(inventory["assets"]), 86)
        top_ten = inventory["ten_largest_files"]
        self.assertEqual(len(top_ten), 10)
        self.assertEqual(
            [row["bytes"] for row in top_ten],
            sorted((row["bytes"] for row in top_ten), reverse=True),
        )

    def test_replacement_manifest_matches_every_current_derivative(self) -> None:
        manifest = json.loads(
            (PUBLISHING_ROOT / "assets/image-derivatives-manifest.json").read_text()
        )
        assets = {asset["stem"]: asset for asset in manifest["assets"]}
        for stem in (
            ENGINE_FAILURE_STEM,
            GROUNDING_STEM,
            PERSON_OVERBOARD_STEM,
            "boat-engine-compartment-fire-response",
            "boat-carbon-monoxide-danger-zones",
            MAYDAY_STEM,
            OVERDUE_STEM,
        ):
            asset = assets[stem]
            source = SOURCE_ROOT / f"{stem}-master.png"
            self.assertEqual(asset["source_sha256"], sha256(source))
            expected_names = {
                f"{stem}-640w.jpg",
                f"{stem}-640w.webp",
                f"{stem}-960w.jpg",
                f"{stem}-960w.webp",
                f"{stem}.jpg",
                f"{stem}.webp",
            }
            self.assertEqual(
                {row["file"] for row in asset["derivatives"]},
                expected_names,
            )
            for row in asset["derivatives"]:
                derivative = PUBLIC_ROOT / row["file"]
                self.assertEqual(row["sha256"], sha256(derivative))
                self.assertEqual(row["bytes"], derivative.stat().st_size)

    def test_owner_approved_fire_replacement_contains_no_stale_hashes(self) -> None:
        manifest_path = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
        manifest_text = manifest_path.read_text()
        manifest = json.loads(manifest_text)
        fire_asset = next(
            asset for asset in manifest["assets"] if asset["stem"] == FIRE_STEM
        )
        self.assertEqual(fire_asset["source_width"], 1672)
        self.assertEqual(fire_asset["source_height"], 941)
        self.assertEqual(fire_asset["source_sha256"], NEW_FIRE_MASTER_SHA256)
        self.assertEqual(
            sha256(SOURCE_ROOT / f"{FIRE_STEM}-master.png"),
            NEW_FIRE_MASTER_SHA256,
        )
        for old_hash in OLD_FIRE_HASHES:
            self.assertNotIn(old_hash, manifest_text)

        with zipfile.ZipFile(ZIP_PATH) as archive:
            prefix = f"{PACKAGE_NAME}/"
            packaged_master = archive.read(
                f"{prefix}masters/{FIRE_STEM}-master.png"
            )
            self.assertEqual(
                hashlib.sha256(packaged_master).hexdigest(),
                NEW_FIRE_MASTER_SHA256,
            )
            for info in archive.infolist():
                self.assertNotIn(
                    hashlib.sha256(archive.read(info)).hexdigest(),
                    OLD_FIRE_HASHES,
                    info.filename,
                )
            for text_name in (
                f"{prefix}CHANGELOG.md",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
            ):
                packaged_text = archive.read(text_name).decode("utf-8")
                for old_hash in OLD_FIRE_HASHES:
                    self.assertNotIn(old_hash, packaged_text, text_name)

    def test_owner_approved_engine_failure_replacement_contains_no_stale_hashes(self) -> None:
        manifest_path = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
        manifest_text = manifest_path.read_text()
        manifest = json.loads(manifest_text)
        asset = next(
            row for row in manifest["assets"] if row["stem"] == ENGINE_FAILURE_STEM
        )
        self.assertEqual(asset["source_width"], 1672)
        self.assertEqual(asset["source_height"], 941)
        self.assertEqual(asset["source_sha256"], NEW_ENGINE_FAILURE_MASTER_SHA256)
        self.assertEqual(
            sha256(SOURCE_ROOT / f"{ENGINE_FAILURE_STEM}-master.png"),
            NEW_ENGINE_FAILURE_MASTER_SHA256,
        )
        for old_hash in OLD_ENGINE_FAILURE_HASHES:
            self.assertNotIn(old_hash, manifest_text)

        with zipfile.ZipFile(ZIP_PATH) as archive:
            prefix = f"{PACKAGE_NAME}/"
            packaged_master = archive.read(
                f"{prefix}masters/{ENGINE_FAILURE_STEM}-master.png"
            )
            self.assertEqual(
                hashlib.sha256(packaged_master).hexdigest(),
                NEW_ENGINE_FAILURE_MASTER_SHA256,
            )
            for info in archive.infolist():
                self.assertNotIn(
                    hashlib.sha256(archive.read(info)).hexdigest(),
                    OLD_ENGINE_FAILURE_HASHES,
                    info.filename,
                )
            for text_name in (
                f"{prefix}CHANGELOG.md",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
            ):
                packaged_text = archive.read(text_name).decode("utf-8")
                for old_hash in OLD_ENGINE_FAILURE_HASHES:
                    self.assertNotIn(old_hash, packaged_text, text_name)

    def test_owner_approved_grounding_replacement_contains_no_stale_hashes(self) -> None:
        manifest_path = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
        manifest_text = manifest_path.read_text()
        manifest = json.loads(manifest_text)
        asset = next(
            row for row in manifest["assets"] if row["stem"] == GROUNDING_STEM
        )
        self.assertEqual(asset["source_width"], 1672)
        self.assertEqual(asset["source_height"], 941)
        self.assertEqual(asset["source_sha256"], NEW_GROUNDING_MASTER_SHA256)
        self.assertEqual(
            sha256(SOURCE_ROOT / f"{GROUNDING_STEM}-master.png"),
            NEW_GROUNDING_MASTER_SHA256,
        )
        for old_hash in OLD_GROUNDING_HASHES:
            self.assertNotIn(old_hash, manifest_text)

        with zipfile.ZipFile(ZIP_PATH) as archive:
            prefix = f"{PACKAGE_NAME}/"
            packaged_master = archive.read(
                f"{prefix}masters/{GROUNDING_STEM}-master.png"
            )
            self.assertEqual(
                hashlib.sha256(packaged_master).hexdigest(),
                NEW_GROUNDING_MASTER_SHA256,
            )
            for info in archive.infolist():
                self.assertNotIn(
                    hashlib.sha256(archive.read(info)).hexdigest(),
                    OLD_GROUNDING_HASHES,
                    info.filename,
                )
            for text_name in (
                f"{prefix}CHANGELOG.md",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
            ):
                packaged_text = archive.read(text_name).decode("utf-8")
                for old_hash in OLD_GROUNDING_HASHES:
                    self.assertNotIn(old_hash, packaged_text, text_name)

    def test_owner_approved_person_overboard_replacement_contains_no_stale_hashes(self) -> None:
        manifest_path = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
        manifest_text = manifest_path.read_text()
        manifest = json.loads(manifest_text)
        asset = next(
            row for row in manifest["assets"] if row["stem"] == PERSON_OVERBOARD_STEM
        )
        self.assertEqual(asset["source_width"], 1672)
        self.assertEqual(asset["source_height"], 941)
        self.assertEqual(asset["source_sha256"], NEW_PERSON_OVERBOARD_MASTER_SHA256)
        self.assertEqual(
            sha256(SOURCE_ROOT / f"{PERSON_OVERBOARD_STEM}-master.png"),
            NEW_PERSON_OVERBOARD_MASTER_SHA256,
        )
        for old_hash in OLD_PERSON_OVERBOARD_HASHES:
            self.assertNotIn(old_hash, manifest_text)

        with zipfile.ZipFile(ZIP_PATH) as archive:
            prefix = f"{PACKAGE_NAME}/"
            packaged_master = archive.read(
                f"{prefix}masters/{PERSON_OVERBOARD_STEM}-master.png"
            )
            self.assertEqual(
                hashlib.sha256(packaged_master).hexdigest(),
                NEW_PERSON_OVERBOARD_MASTER_SHA256,
            )
            for info in archive.infolist():
                self.assertNotIn(
                    hashlib.sha256(archive.read(info)).hexdigest(),
                    OLD_PERSON_OVERBOARD_HASHES,
                    info.filename,
                )
            for text_name in (
                f"{prefix}CHANGELOG.md",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
            ):
                packaged_text = archive.read(text_name).decode("utf-8")
                for old_hash in OLD_PERSON_OVERBOARD_HASHES:
                    self.assertNotIn(old_hash, packaged_text, text_name)

    def test_owner_approved_storm_replacement_contains_no_stale_hashes(self) -> None:
        manifest_path = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
        manifest_text = manifest_path.read_text()
        manifest = json.loads(manifest_text)
        storm_asset = next(
            asset for asset in manifest["assets"] if asset["stem"] == STORM_STEM
        )
        self.assertEqual(storm_asset["source_width"], 1672)
        self.assertEqual(storm_asset["source_height"], 941)
        self.assertEqual(storm_asset["source_sha256"], NEW_STORM_MASTER_SHA256)
        self.assertEqual(
            sha256(SOURCE_ROOT / f"{STORM_STEM}-master.png"),
            NEW_STORM_MASTER_SHA256,
        )
        for old_hash in OLD_STORM_HASHES:
            self.assertNotIn(old_hash, manifest_text)

        with zipfile.ZipFile(ZIP_PATH) as archive:
            prefix = f"{PACKAGE_NAME}/"
            packaged_master = archive.read(
                f"{prefix}masters/{STORM_STEM}-master.png"
            )
            self.assertEqual(
                hashlib.sha256(packaged_master).hexdigest(),
                NEW_STORM_MASTER_SHA256,
            )
            for info in archive.infolist():
                self.assertNotIn(
                    hashlib.sha256(archive.read(info)).hexdigest(),
                    OLD_STORM_HASHES,
                    info.filename,
                )
            for text_name in (
                f"{prefix}CHANGELOG.md",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
            ):
                packaged_text = archive.read(text_name).decode("utf-8")
                for old_hash in OLD_STORM_HASHES:
                    self.assertNotIn(old_hash, packaged_text, text_name)

    def test_owner_approved_overdue_replacement_contains_no_stale_hashes(self) -> None:
        manifest_path = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
        manifest_text = manifest_path.read_text()
        manifest = json.loads(manifest_text)
        asset = next(
            row for row in manifest["assets"] if row["stem"] == OVERDUE_STEM
        )
        self.assertEqual(asset["source_width"], 1672)
        self.assertEqual(asset["source_height"], 941)
        self.assertEqual(asset["source_sha256"], NEW_OVERDUE_MASTER_SHA256)
        self.assertEqual(
            sha256(SOURCE_ROOT / f"{OVERDUE_STEM}-master.png"),
            NEW_OVERDUE_MASTER_SHA256,
        )
        for old_hash in OLD_OVERDUE_HASHES:
            self.assertNotIn(old_hash, manifest_text)

        with zipfile.ZipFile(ZIP_PATH) as archive:
            prefix = f"{PACKAGE_NAME}/"
            packaged_master = archive.read(
                f"{prefix}masters/{OVERDUE_STEM}-master.png"
            )
            self.assertEqual(
                hashlib.sha256(packaged_master).hexdigest(),
                NEW_OVERDUE_MASTER_SHA256,
            )
            for info in archive.infolist():
                self.assertNotIn(
                    hashlib.sha256(archive.read(info)).hexdigest(),
                    OLD_OVERDUE_HASHES,
                    info.filename,
                )
            for text_name in (
                f"{prefix}CHANGELOG.md",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
            ):
                packaged_text = archive.read(text_name).decode("utf-8")
                for old_hash in OLD_OVERDUE_HASHES:
                    self.assertNotIn(old_hash, packaged_text, text_name)

    def test_owner_approved_mayday_replacement_contains_no_stale_hashes(self) -> None:
        manifest_path = PUBLISHING_ROOT / "assets/image-derivatives-manifest.json"
        manifest_text = manifest_path.read_text()
        manifest = json.loads(manifest_text)
        mayday_asset = next(
            asset for asset in manifest["assets"] if asset["stem"] == MAYDAY_STEM
        )
        self.assertEqual(mayday_asset["source_width"], 1448)
        self.assertEqual(mayday_asset["source_height"], 1086)
        self.assertEqual(mayday_asset["source_sha256"], NEW_MAYDAY_MASTER_SHA256)
        self.assertEqual(
            sha256(SOURCE_ROOT / f"{MAYDAY_STEM}-master.png"),
            NEW_MAYDAY_MASTER_SHA256,
        )
        for old_hash in OLD_MAYDAY_HASHES:
            self.assertNotIn(old_hash, manifest_text)

        with zipfile.ZipFile(ZIP_PATH) as archive:
            prefix = f"{PACKAGE_NAME}/"
            packaged_master = archive.read(
                f"{prefix}masters/{MAYDAY_STEM}-master.png"
            )
            self.assertEqual(
                hashlib.sha256(packaged_master).hexdigest(),
                NEW_MAYDAY_MASTER_SHA256,
            )
            for info in archive.infolist():
                self.assertNotIn(
                    hashlib.sha256(archive.read(info)).hexdigest(),
                    OLD_MAYDAY_HASHES,
                    info.filename,
                )
            for text_name in (
                f"{prefix}CHANGELOG.md",
                f"{prefix}inventory/asset-inventory.json",
                f"{prefix}inventory/asset-inventory.csv",
                f"{prefix}inventory/asset-inventory.md",
            ):
                packaged_text = archive.read(text_name).decode("utf-8")
                for old_hash in OLD_MAYDAY_HASHES:
                    self.assertNotIn(old_hash, packaged_text, text_name)

    def test_production_web_config_denies_guide_publishing_subtree(self) -> None:
        web_config = (ROOT / "web.config").read_text(encoding="utf-8-sig")
        self.assertIn(
            '<match url="^publishing/common-boating-emergencies(?:/.*)?$" '
            'ignoreCase="true" />',
            web_config,
        )
        self.assertIn('statusCode="404"', web_config)

    def test_review_and_junk_artifacts_are_excluded_from_git(self) -> None:
        tracked_review = subprocess.run(
            ["git", "ls-files", "--", "publishing/common-boating-emergencies/review"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assertEqual(tracked_review, "")

        ignored_paths = (
            "publishing/common-boating-emergencies/review/common-boating-emergencies-owner-review.zip",
            "publishing/common-boating-emergencies/review/common-boating-emergencies-owner-review/pdf-renders/emergency-card-4x6-page-1-front.png",
            "publishing/common-boating-emergencies/review/.DS_Store",
            "publishing/common-boating-emergencies/review/card.backup",
            "publishing/common-boating-emergencies/review/card.orig",
            "publishing/common-boating-emergencies/review/card~",
        )
        for ignored_path in ignored_paths:
            result = subprocess.run(
                ["git", "check-ignore", "--quiet", ignored_path],
                cwd=ROOT,
            )
            self.assertEqual(result.returncode, 0, ignored_path)

        changed_paths = subprocess.run(
            ["git", "diff", "--name-only", "-z", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
        ).stdout.split(b"\0")
        for raw_path in changed_paths:
            if not raw_path:
                continue
            path = raw_path.decode()
            self.assertFalse(path.endswith(".DS_Store"), path)
            self.assertFalse(path.endswith((".bak", ".backup", ".orig", "~")), path)


if __name__ == "__main__":
    unittest.main()
