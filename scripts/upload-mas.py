#!/usr/bin/env python3
# Upload build/mas/Wound-<version>-<build>.pkg (made by scripts/bundle-mas.sh) to App Store Connect through
# the public buildUploads API, with an App Store Connect API key instead of an Apple ID sign-in, then wait for
# Apple's upload validation and print its errors and warnings. Needs only python3 and openssl; no Xcode,
# altool or Transporter. A key with the Developer role is enough. See appstore/RUNBOOK.md §7.
#
#   scripts/upload-mas.py <pkg>
#
#   ASC_KEY_ID      API key id (default 48UD5KH5VT)
#   ASC_ISSUER_ID   issuer id (default eb5a2baf-636a-4977-a2f5-fe7141635b72)
#   ASC_KEY_PATH    the .p8 private key (default ~/.appstoreconnect/private_keys/AuthKey_<key id>.p8)
#   ASC_APP_ID      the app's Apple ID in App Store Connect (default 6836127216)
#
# The version and build number are read from the package itself. Exit 0 when Apple accepts the upload
# (state COMPLETE, warnings allowed), 1 when it fails. The key, the JWT and the presigned upload URLs are
# never printed.
import base64, hashlib, json, os, re, subprocess, sys, tempfile, time, urllib.error, urllib.request

KEY_ID = os.environ.get("ASC_KEY_ID", "48UD5KH5VT")
ISSUER = os.environ.get("ASC_ISSUER_ID", "eb5a2baf-636a-4977-a2f5-fe7141635b72")
KEY_PATH = os.path.expanduser(
    os.environ.get("ASC_KEY_PATH", f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"))
APP_ID = os.environ.get("ASC_APP_ID", "6836127216")
API = "https://api.appstoreconnect.apple.com"


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token():
    # ES256 JWT, signed by openssl so the script needs no third-party module.
    now = int(time.time())
    header = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    claims = b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 1100,
                             "aud": "appstoreconnect-v1"}).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=f"{header}.{claims}".encode(), capture_output=True, check=True).stdout
    # openssl writes ECDSA-Sig-Value (DER SEQUENCE of r and s); JWT wants r || s, 32 bytes each.
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    signature = b""
    for _ in range(2):
        length = der[i + 1]
        signature += der[i + 2:i + 2 + length].lstrip(b"\0").rjust(32, b"\0")
        i += 2 + length
    return f"{header}.{claims}.{b64(signature)}"


def call(method, path, body=None):
    request = urllib.request.Request(API + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None)
    request.add_header("Authorization", "Bearer " + token())
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path}: HTTP {error.code}\n{error.read().decode(errors='replace')}")


def package_version(pkg):
    with tempfile.TemporaryDirectory() as scratch:
        subprocess.run(["pkgutil", "--expand", pkg, f"{scratch}/x"], check=True)
        distribution = open(f"{scratch}/x/Distribution").read()
    match = re.search(r'CFBundleShortVersionString="([^"]+)" CFBundleVersion="([^"]+)"', distribution)
    if not match:
        sys.exit(f"{pkg}: no bundle version in its Distribution file")
    return match.groups()


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: upload-mas.py <pkg>")
    pkg = sys.argv[1]
    version, build = package_version(pkg)
    data = open(pkg, "rb").read()
    print(f"Uploading {os.path.basename(pkg)}: version {version}, build {build}, app {APP_ID}")

    upload = call("POST", "/v1/buildUploads", {"data": {
        "type": "buildUploads",
        "attributes": {"cfBundleShortVersionString": version, "cfBundleVersion": build,
                       "platform": "MAC_OS"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]
    upload_file = call("POST", "/v1/buildUploadFiles", {"data": {
        "type": "buildUploadFiles",
        "attributes": {"assetType": "ASSET", "fileName": os.path.basename(pkg),
                       "fileSize": len(data), "uti": "com.apple.pkg"},
        "relationships": {"buildUpload": {"data": {"type": "buildUploads", "id": upload["id"]}}}}})["data"]

    for operation in upload_file["attributes"]["uploadOperations"]:
        part = data[operation["offset"]:operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], data=part, method=operation["method"])
        for header in operation.get("requestHeaders") or []:
            request.add_header(header["name"], header["value"])
        urllib.request.urlopen(request).close()

    call("PATCH", f"/v1/buildUploadFiles/{upload_file['id']}", {"data": {
        "type": "buildUploadFiles", "id": upload_file["id"],
        "attributes": {"uploaded": True, "sourceFileChecksums": {
            "file": {"hash": hashlib.md5(data).hexdigest(), "algorithm": "MD5"}}}}})
    print(f"Uploaded; buildUpload {upload['id']}. Waiting for Apple's validation...")

    while True:
        state = call("GET", f"/v1/buildUploads/{upload['id']}")["data"]["attributes"]["state"]
        if state["state"] not in ("AWAITING_UPLOAD", "PROCESSING"):
            break
        time.sleep(20)
    for kind in ("errors", "warnings", "infos"):
        for detail in state.get(kind) or []:
            print(f"{kind[:-1]} ITMS-{detail['code']}: {detail['description']}")
    print(f"State: {state['state']}")
    return 0 if state["state"] == "COMPLETE" else 1


if __name__ == "__main__":
    sys.exit(main())
