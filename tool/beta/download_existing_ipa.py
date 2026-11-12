"""Private reuse of one approved Codemagic IPA. Never publishes or creates public URLs."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError
from urllib.parse import parse_qsl, unquote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import zipfile

BUILD_ID = "6af5c4f59679c85ac0af190e"
IPA_HASH = "d9810249ad3ff94ce33fd58625e2b754cdc287bed45406b13c225b163b6d26b2"
IPA_BYTES = 54207086
BUNDLE_ID = "br.com.loumak.chamae.staging"
APPLE_ID = "6833594439"


# Pins derived from the browser origin metadata of the approved original IPA.
# Store only hashes, never the object URL, signer identity, or signed query.
STORAGE_PATH_SHA256 = "b6f9afbda54091a32747362c0bec19f77ba8dc92583ad2c38a95bd52edad6355"
STORAGE_SIGNER_SHA256 = "63b10d88d6f6d25927ada816c9f21f4d01ed2abe31e81ce0c1a1f36f66f9d440"
MAX_SIGNED_URL_REMAINING_SECONDS = 300


def trusted_storage_redirect(url):
    if any(ord(c) < 33 or ord(c) == 127 for c in url):
        raise ValueError("UNTRUSTED_ARTIFACT_REDIRECT")
    p = urlsplit(url)
    if (p.scheme != "https" or p.netloc != "storage.googleapis.com" or
            p.username or p.password or p.fragment or
            not p.path.startswith("/codemagic-build-artifacts/") or
            hashlib.sha256(p.path.encode()).hexdigest() != STORAGE_PATH_SHA256):
        raise ValueError("UNTRUSTED_ARTIFACT_REDIRECT")
    pairs = parse_qsl(p.query, keep_blank_values=True, strict_parsing=True, max_num_fields=3)
    query = dict(pairs)
    if len(pairs) != 3 or set(query) != {"Expires", "GoogleAccessId", "Signature"}:
        raise ValueError("SIGNED_ARTIFACT_URL_REQUIRED")
    if (hashlib.sha256(query["GoogleAccessId"].encode()).hexdigest() != STORAGE_SIGNER_SHA256 or
            not re.fullmatch(r"[0-9]{1,12}", query["Expires"])):
        raise ValueError("SIGNED_ARTIFACT_URL_REQUIRED")
    remaining = int(query["Expires"]) - time.time()
    if not 0 < remaining <= MAX_SIGNED_URL_REMAINING_SECONDS:
        raise ValueError("SIGNED_ARTIFACT_URL_EXPIRY_INVALID")
    signature = base64.b64decode(query["Signature"], validate=True)
    if not 128 <= len(signature) <= 512:
        raise ValueError("SIGNED_ARTIFACT_URL_REQUIRED")
    # Google authenticates this short-lived signature; no Codemagic header is used.
    return url


class BlockRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        origin = urlsplit(req.full_url)
        stage = "metadata" if origin.path.startswith("/builds/") else "artifact"
        if origin.hostname == "storage.googleapis.com":
            stage = "artifact_storage"
        try:
            hostname = urlsplit(newurl).hostname or "invalid"
        except ValueError:
            hostname = "invalid"
        token = req.get_header("X-auth-token", "")
        if not re.fullmatch(r"[a-zA-Z0-9.-]{1,253}", hostname) or (token and token in hostname):
            hostname = "redacted"
        # Diagnostic never includes a path, query, Location header, or credential.
        print(json.dumps({"stage": stage, "httpStatus": code, "destinationHost": hostname}), file=sys.stderr)
        if stage == "metadata":
            raise ValueError("METADATA_REDIRECT_REFUSED")
        if code not in (301, 302, 303, 307, 308):
            raise ValueError("UNTRUSTED_ARTIFACT_REDIRECT")
        private_url(req.full_url)  # Only an authenticated Codemagic artifact request may redirect.
        target = trusted_storage_redirect(newurl)
        # Fresh request: no x-auth-token, Authorization, Cookie, Referer, or copied headers.
        # A second redirect from storage is refused by private_url above.
        return Request(target, headers={"Accept": "application/octet-stream"}, method="GET")


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
