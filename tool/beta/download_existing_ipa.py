"""Private reuse of one approved Codemagic IPA. Never publishes or creates public URLs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
from urllib.error import HTTPError
from urllib.parse import unquote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import zipfile

BUILD_ID = "6af4b8c89679c85ac0aec251"
IPA_HASH = "1a6f35785143dfd4b63e50153ddfa0b005dd47e1c6f409b39b1734762764d10a"
IPA_BYTES = 50165930
BUNDLE_ID = "br.com.loumak.chamae.staging"
APPLE_ID = "6833594439"


class BlockRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward a token to a different host or accept open download links.
        raise ValueError("PRIVATE_API_REDIRECT_REFUSED")


def private_url(url):
    p = urlsplit(url)
    if (p.scheme != "https" or p.netloc != "api.codemagic.io" or
            p.username or p.password or p.query or p.fragment or
            not p.path.startswith("/artifacts/") or
            p.path.endswith("/public-url") or
            any(s in ("..", ".") for s in unquote(p.path).split("/"))):
        raise ValueError("PRIVATE_ARTIFACT_URL_REQUIRED")
    return url


def get(url, token):
    request = Request(url, headers={"x-auth-token": token, "Accept": "application/json, application/octet-stream"})
    return build_opener(BlockRedirects()).open(request, timeout=120)


def inspect_ipa(path, verify_signature=False):
    if path.stat().st_size != IPA_BYTES:
        raise ValueError("APPROVED_IPA_SIZE_MISMATCH")
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if digest != IPA_HASH:
        raise ValueError("APPROVED_IPA_HASH_MISMATCH")
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        info_names = [n for n in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n)]
        if len(info_names) != 1:
            raise ValueError("SINGLE_IOS_APP_REQUIRED")
        info = plistlib.loads(archive.read(info_names[0]))
        prefix = info_names[0][:-len("Info.plist")]
        firebase = plistlib.loads(archive.read(prefix + "GoogleService-Info.plist"))
        if (info.get("CFBundleIdentifier") != BUNDLE_ID or
                str(info.get("CFBundleShortVersionString")) != "1.0.0" or
                str(info.get("CFBundleVersion")) != "2" or
                firebase.get("PROJECT_ID") != "chamae-delivery-staging" or
                firebase.get("BUNDLE_ID") != BUNDLE_ID):
            raise ValueError("STAGING_IPA_IDENTITY_MISMATCH")
        provision = archive.read(prefix + "embedded.mobileprovision")
        start = provision.index(b"<?xml")
        end = provision.index(b"</plist>", start) + len(b"</plist>")
        profile = plistlib.loads(provision[start:end])
        entitlements = profile.get("Entitlements", {})
        if (entitlements.get("get-task-allow") is not False or
                profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices") or
                not entitlements.get("application-identifier", "").endswith("." + BUNDLE_ID) or
                prefix + "_CodeSignature/CodeResources" not in names):
            raise ValueError("APP_STORE_DISTRIBUTION_IPA_REQUIRED")
    if verify_signature:
        with tempfile.TemporaryDirectory(prefix="chamae-ipa-signature-") as folder:
            extracted = subprocess.run(["/usr/bin/unzip", "-q", str(path.resolve()), "-d", folder],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            if extracted.returncode:
                raise ValueError("IPA_EXTRACTION_FAILED")
            checked = subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(Path(folder) / prefix)],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            if checked.returncode:
                raise ValueError("APPLE_CODE_SIGNATURE_INVALID")
    return {"bundleId": BUNDLE_ID, "version": "1.0.0", "buildNumber": "2", "sha256": digest,
            "firebaseProject": "chamae-delivery-staging", "macCodeSignatureVerified": verify_signature}


def prepare():
    required = {"SOURCE_CODEMAGIC_BUILD_ID": BUILD_ID, "EXPECTED_IPA_SHA256": IPA_HASH,
                "EXPECTED_BUNDLE_ID": BUNDLE_ID, "EXPECTED_APP_STORE_APPLE_ID": APPLE_ID}
    if any(os.environ.get(k) != v for k, v in required.items()):
        raise ValueError("APPROVED_UPLOAD_TARGET_REQUIRED")
    token = os.environ.get("CODEMAGIC_API_TOKEN", "").strip()
    if not token or "\n" in token or "\r" in token:
        raise ValueError("PROTECTED_CODEMAGIC_API_TOKEN_REQUIRED")
    dest = Path(".private-upload/chamae_delivery.ipa")
    if dest.exists():
        raise ValueError("PRESERVE_EXISTING_UPLOAD_FILE")
    # All remote actions here are authenticated GETs. No POST/public-url endpoint exists in this script.
    with get("https://api.codemagic.io/builds/" + BUILD_ID, token) as response:
        raw = response.read(4 * 1024 * 1024 + 1)
    if len(raw) > 4 * 1024 * 1024:
        raise ValueError("BUILD_METADATA_TOO_LARGE")
    build = json.loads(raw).get("build", {})
    artifacts = build.get("artefacts", [])
    candidates = []
    for item in artifacts:
        url = item.get("url", "")
        if unquote(urlsplit(url).path).rsplit("/", 1)[-1] == "chamae_delivery.ipa":
            candidates.append(private_url(url))
    if len(candidates) != 1:
        raise ValueError("ONE_PRIVATE_SOURCE_IPA_REQUIRED")
    dest.parent.mkdir(mode=0o700, exist_ok=True)
    try:
        with get(candidates[0], token) as response, dest.open("xb") as stream:
            os.chmod(dest, 0o600)
            size = 0
            while chunk := response.read(1024 * 1024):
                size += len(chunk)
                if size > IPA_BYTES:
                    raise ValueError("APPROVED_IPA_SIZE_EXCEEDED")
                stream.write(chunk)
        result = inspect_ipa(dest, verify_signature=True)
    except Exception:
        dest.unlink(missing_ok=True)
        raise
    # Only non-secret identity/hash metadata. No token, artifact URL or IPA content.
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser()
        parser.add_argument("--inspect-local", type=Path)
        args = parser.parse_args()
        if args.inspect_local:
            print(json.dumps(inspect_ipa(args.inspect_local)))
        else:
            prepare()
    except Exception as error:
        code = str(error) if isinstance(error, ValueError) and re.fullmatch(r"[A-Z0-9_]+", str(error)) else "PRIVATE_IPA_PREPARATION_FAILED"
        print(code, file=sys.stderr)
        sys.exit(1)
