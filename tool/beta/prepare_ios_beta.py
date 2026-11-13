"""Codemagic preflight: use genuine STAGING exports, never production defaults."""
import base64
import json
import os
from pathlib import Path
import plistlib
import re
import sys


def require(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError("MISSING_" + name)
    return value


def prepare():
    role = require("BETA_APP_ROLE")
    bundle = require("BETA_BUNDLE_ID")
    expected = {"client": "br.com.loumak.chamae.staging",
                "courier": "br.com.loumak.chamae.motoboy.staging"}
    if expected.get(role) != bundle:
        raise ValueError("BETA_BUNDLE_ID_MISMATCH")
    number = require("BETA_BUILD_NUMBER")
    if not re.fullmatch(r"[1-9][0-9]{0,8}", number):
        raise ValueError("INVALID_UNIQUE_BETA_BUILD_NUMBER")
    if not re.fullmatch(r"[1-9][0-9]+", require("APP_STORE_APPLE_ID")):
        raise ValueError("INVALID_APP_STORE_APPLE_ID")
    data = plistlib.loads(base64.b64decode(require("BETA_IOS_FIREBASE_PLIST_BASE64"), validate=True))
    if (data.get("PROJECT_ID") != "chamae-delivery-staging" or
            data.get("BUNDLE_ID") != bundle or
            data.get("GCM_SENDER_ID") != "591246287574" or
            not re.fullmatch(r"1:591246287574:ios:[a-fA-F0-9]+", data.get("GOOGLE_APP_ID", "")) or
            not re.fullmatch(r"AIza[A-Za-z0-9_-]{35}", data.get("API_KEY", "")) or
            data.get("STORAGE_BUCKET") not in ("chamae-delivery-staging.appspot.com",
                                                "chamae-delivery-staging.firebasestorage.app")):
        raise ValueError("GENUINE_MATCHING_STAGING_IOS_EXPORT_REQUIRED")
    maps_key = require("CHAMAE_MAPS_IOS_API_KEY")
    if not re.fullmatch(r"AIza[A-Za-z0-9_-]{35}", maps_key):
        raise ValueError("LEGITIMATE_RESTRICTED_IOS_MAPS_KEY_REQUIRED")
    target = Path("ios/Runner/GoogleService-Info.plist")
    target.write_bytes(plistlib.dumps(data))
    info_path = Path("ios/Runner/Info.plist")
    info = plistlib.loads(info_path.read_bytes())
    info["GMSApiKey"] = maps_key
    info["CFBundleDisplayName"] = "Chamaê Cliente STAGING" if role == "client" else "Chamaê Motoboy STAGING"
    if role == "client":
        reverse = data.get("REVERSED_CLIENT_ID", "")
        if not reverse.startswith("com.googleusercontent.apps."):
            raise ValueError("STAGING_GOOGLE_IOS_OAUTH_CONFIGURATION_REQUIRED")
        info["CFBundleURLTypes"] = [{"CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [reverse]}]
    info_path.write_bytes(plistlib.dumps(info))
    project_path = Path("ios/Runner.xcodeproj/project.pbxproj")
    project = project_path.read_text(encoding="utf-8")
    original = "br.com.loumak.chamae" if role == "client" else "br.com.loumak.chamae.motoboy"
    if len(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = " + re.escape(original) + r";", project)) != 3:
        raise ValueError("REVIEW_XCODE_BUNDLE_CONFIGURATION")
    project = project.replace("PRODUCT_BUNDLE_IDENTIFIER = " + original + ";",
                              "PRODUCT_BUNDLE_IDENTIFIER = " + bundle + ";")
    project = project.replace("PRODUCT_BUNDLE_IDENTIFIER = " + original + ".RunnerTests;",
                              "PRODUCT_BUNDLE_IDENTIFIER = " + bundle + ".RunnerTests;")
    project_path.write_text(project, encoding="utf-8")
    output = Path(".beta-build")
    output.mkdir(exist_ok=True)
    defines = {"CHAMAE_ENV": "STAGING", "CHAMAE_FIREBASE_PROJECT_ID": data["PROJECT_ID"],
               "CHAMAE_FIREBASE_API_KEY": data["API_KEY"], "CHAMAE_FIREBASE_APP_ID": data["GOOGLE_APP_ID"],
               "CHAMAE_FIREBASE_MESSAGING_SENDER_ID": data["GCM_SENDER_ID"],
               "CHAMAE_FIREBASE_STORAGE_BUCKET": data["STORAGE_BUCKET"],
               "CHAMAE_FIREBASE_AUTH_DOMAIN": "chamae-delivery-staging.firebaseapp.com",
               "CHAMAE_FIREBASE_IOS_BUNDLE_ID": bundle,
               "CHAMAE_AUTH_GOOGLE_ENABLED": role == "client", "CHAMAE_AUTH_APPLE_ENABLED": False}
    (output / "ios-defines.json").write_text(json.dumps(defines), encoding="utf-8")
    print("STAGING iOS preflight passed; configuration values omitted.")


if __name__ == "__main__":
    try:
        prepare()
    except Exception as error:
        # Parser exceptions could contain configuration content: report only a safe code.
        message = str(error) if isinstance(error, ValueError) and re.fullmatch(r"[A-Z0-9_]+", str(error)) else "INVALID_BETA_INPUT_OR_PROJECT"
        print(message, file=sys.stderr)
        sys.exit(1)
