"""Offline version-contract tests. Fixtures contain no real keys or personal data."""
import base64
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location("ios_preflight", Path(__file__).with_name("prepare_ios_beta.py"))
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
BUNDLE = "br.com.loumak.chamae.staging"


class VersionContractTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="chamae-version-test-")
        self.cwd = os.getcwd()
        os.chdir(self.folder.name)
        self.addCleanup(self.folder.cleanup)
        self.addCleanup(os.chdir, self.cwd)
        self.env = patch.dict(os.environ, {"BETA_BUILD_NUMBER": "3"}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        Path(".beta-build").mkdir()
        Path(".beta-build/ios-build-number.txt").write_text("3\n", encoding="utf8")
        self.logs = io.StringIO()
        self.output = contextlib.redirect_stdout(self.logs)
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def fixture_project(self):
        Path("ios/Runner").mkdir(parents=True)
        Path("ios/Runner/Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion": "$(FLUTTER_BUILD_NUMBER)"}))
        Path("ios/Runner.xcodeproj").mkdir()
        Path("ios/Runner.xcodeproj/project.pbxproj").write_text("PRODUCT_BUNDLE_IDENTIFIER = br.com.loumak.chamae;\n" * 3, encoding="utf8")
        key = "AIza" + "S" * 35  # synthetic parser fixture; never a real API key
        data = {"PROJECT_ID": "chamae-delivery-staging", "BUNDLE_ID": BUNDLE,
                "GCM_SENDER_ID": "591246287574", "GOOGLE_APP_ID": "1:591246287574:ios:deadbeef",
                "API_KEY": key, "STORAGE_BUCKET": "chamae-delivery-staging.appspot.com",
                "REVERSED_CLIENT_ID": "com.googleusercontent.apps.synthetic"}
        os.environ.update({"BETA_APP_ROLE": "client", "BETA_BUNDLE_ID": BUNDLE,
                           "APP_STORE_APPLE_ID": "12345", "CHAMAE_MAPS_IOS_API_KEY": key,
                           "BETA_IOS_FIREBASE_PLIST_BASE64": base64.b64encode(plistlib.dumps(data)).decode()})

    def fixture_generated(self, number="3", name="1.0.0"):
        Path("ios/Flutter").mkdir(parents=True, exist_ok=True)
        Path("ios/Flutter/Generated.xcconfig").write_text(
            "FLUTTER_BUILD_NUMBER=" + number + "\nFLUTTER_BUILD_NAME=" + name + "\n", encoding="utf8")

    def fixture_ipa(self, number="3", archive_number="3", signed=True, bundle=BUNDLE):
        Path("build/ios/ipa").mkdir(parents=True)
        info = {"CFBundleVersion": number, "CFBundleShortVersionString": "1.0.0", "CFBundleIdentifier": bundle}
        with zipfile.ZipFile("build/ios/ipa/synthetic.ipa", "w") as z:
            z.writestr("Payload/Synthetic.app/Info.plist", plistlib.dumps(info))
            z.writestr("Payload/Synthetic.app/GoogleService-Info.plist", plistlib.dumps({"PROJECT_ID":"chamae-delivery-staging","BUNDLE_ID":BUNDLE}))
            if signed:
                z.writestr("Payload/Synthetic.app/_CodeSignature/CodeResources", b"SYNTHETIC STRUCTURE ONLY")
                z.writestr("Payload/Synthetic.app/embedded.mobileprovision", b"SYNTHETIC STRUCTURE ONLY")
        target = Path("build/ios/archive/Synthetic.xcarchive/Products/Applications/Synthetic.app/Info.plist")
        target.parent.mkdir(parents=True)
        target.write_bytes(plistlib.dumps({**info,"CFBundleVersion":archive_number}))

    def test_selects_three_after_previously_uploaded_two(self):
        self.assertEqual(MOD.select_build_number("2"), "3")

    def test_occupied_three_selects_four(self):
        self.assertEqual(MOD.select_build_number("3"), "4")
        self.assertEqual(MOD.select_build_number("12"), "13")

    def test_selection_never_returns_two(self):
        for latest in ("0", "1"):
            self.assertEqual(MOD.select_build_number(latest), "3")

    def test_invalid_or_failed_lookup_is_not_silently_replaced(self):
        for latest in ("", "None", "error", "3.1", "-1", "2\n3", "999999999"):
            with self.assertRaises(ValueError):
                MOD.select_build_number(latest)

    def test_environment_two_is_rejected(self):
        for number in ("1", "2", "0", "3.0", "03", ""):
            with self.assertRaises(ValueError):
                MOD.valid_build_number(number)

    def test_preflight_records_three_without_changing_dynamic_bundle_version(self):
        self.fixture_project()
        MOD.prepare()
        self.assertEqual(Path(".beta-build/ios-build-number.txt").read_text().strip(), "3")
        self.assertEqual(plistlib.loads(Path("ios/Runner/Info.plist").read_bytes())["CFBundleVersion"], "$(FLUTTER_BUILD_NUMBER)")

    def test_preflight_refuses_two_before_materializing_configuration(self):
        self.fixture_project()
        os.environ["BETA_BUILD_NUMBER"] = "2"
        with self.assertRaisesRegex(ValueError, "MUST_EXCEED_2"):
            MOD.prepare()
        self.assertFalse(Path("ios/Runner/GoogleService-Info.plist").exists())

    def test_hardcoded_native_version_is_refused(self):
        self.fixture_project()
        Path("ios/Runner/Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion":"2"}))
        with self.assertRaisesRegex(ValueError, "DYNAMIC_IOS_BUILD_NUMBER_REQUIRED"):
            MOD.prepare()

    def test_generated_number_three_is_accepted(self):
        self.fixture_generated()
        MOD.verify_generated()

    def test_generated_old_number_or_wrong_version_is_refused(self):
        for number,name in (("2","1.0.0"),("3","1.0.1")):
            self.fixture_generated(number,name)
            with self.assertRaisesRegex(ValueError, "GENERATED_FLUTTER_VERSION_MISMATCH"):
                MOD.verify_generated()

    def test_number_cannot_change_between_stages(self):
        self.fixture_generated()
        os.environ["BETA_BUILD_NUMBER"] = "4"
        with self.assertRaisesRegex(ValueError, "CHANGED_BETWEEN_STEPS"):
            MOD.verify_generated()

    def test_archive_and_ipa_three_are_accepted(self):
        self.fixture_ipa()
        MOD.verify_ipa()

    def test_old_ipa_two_is_rejected_despite_environment_three(self):
        self.fixture_ipa(number="2")
        with self.assertRaisesRegex(ValueError, "SIGNED_IPA_OR_ARCHIVE_VERSION_MISMATCH"):
            MOD.verify_ipa()

    def test_archive_must_match_exported_ipa(self):
        self.fixture_ipa(archive_number="2")
        with self.assertRaisesRegex(ValueError, "SIGNED_IPA_OR_ARCHIVE_VERSION_MISMATCH"):
            MOD.verify_ipa()

    def test_unsigned_artifact_is_rejected(self):
        self.fixture_ipa(signed=False)
        with self.assertRaisesRegex(ValueError, "SIGNED_IPA_REQUIRED"):
            MOD.verify_ipa()

    def test_production_bundle_is_rejected(self):
        self.fixture_ipa(bundle="br.com.loumak.chamae")
        with self.assertRaisesRegex(ValueError, "SIGNED_IPA_OR_ARCHIVE_VERSION_MISMATCH"):
            MOD.verify_ipa()


if __name__ == "__main__":
    unittest.main(verbosity=2)
