#!/usr/bin/env python3
"""Minimal App Store Connect API helper for Z Video Generator.

Signs an ES256 JWT with the on-disk .p8 (its contents are never printed) and
performs one HTTP call against the App Store Connect API. No SDK, no PyPI deps
beyond `cryptography`. (Ported from the Muxy helper of the same name.)

Env:
  Z_API_KEY_ID   App Store Connect API Key ID  (falls back to MUXY_API_KEY_ID)
  Z_API_ISSUER   App Store Connect Issuer ID   (falls back to MUXY_API_ISSUER)
The private key is read from:
  ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
If Z_API_KEY_ID is unset, the single AuthKey_*.p8 in that dir is auto-detected.

Usage:
  Z_API_ISSUER=… python3 Scripts/asc.py METHOD PATH [JSON_BODY]

Examples:
  python3 Scripts/asc.py GET "/v1/apps"
  python3 Scripts/asc.py GET "/v1/apps/6782761951/appStoreVersions"
  python3 Scripts/asc.py POST "/v1/appStoreVersions" '{"data":{...}}'
"""
import sys, os, json, time, base64, glob, urllib.request, urllib.error

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric import utils as asym_utils

KEY_ID = os.environ.get("Z_API_KEY_ID") or os.environ.get("MUXY_API_KEY_ID")
ISSUER = os.environ.get("Z_API_ISSUER") or os.environ.get("MUXY_API_ISSUER")
KEYDIR = os.path.expanduser("~/.appstoreconnect/private_keys")

if not KEY_ID:
    found = glob.glob(os.path.join(KEYDIR, "AuthKey_*.p8"))
    if len(found) == 1:
        KEY_ID = os.path.basename(found[0])[len("AuthKey_"):-len(".p8")]
    else:
        sys.exit("set Z_API_KEY_ID (or place exactly one AuthKey_*.p8 in "
                 + KEYDIR + ")")
if not ISSUER:
    sys.exit("set Z_API_ISSUER (App Store Connect → Users and Access → Keys)")

KEYPATH = os.path.join(KEYDIR, "AuthKey_{}.p8".format(KEY_ID))
with open(KEYPATH, "rb") as fh:
    _KEY = serialization.load_pem_private_key(fh.read(), password=None)


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _jwt() -> str:
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    signing_input = (
        _b64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + _b64url(json.dumps(payload, separators=(",", ":")).encode())
    )
    der = _KEY.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
    # ES256 wants raw fixed-width r||s (64 bytes), not DER.
    r, s = asym_utils.decode_dss_signature(der)
    signature = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return signing_input + "." + _b64url(signature)


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit("usage: asc.py METHOD PATH [JSON_BODY]")
    method = sys.argv[1].upper()
    path = sys.argv[2]
    body = sys.argv[3].encode() if len(sys.argv) > 3 else None
    url = "https://api.appstoreconnect.apple.com" + path

    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", "Bearer " + _jwt())
    if body:
        req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req) as resp:
            sys.stdout.write("HTTP {}\n".format(resp.status))
            print(resp.read().decode() or "(no body)")
    except urllib.error.HTTPError as exc:
        sys.stdout.write("HTTP {}\n".format(exc.code))
        print(exc.read().decode())


if __name__ == "__main__":
    main()
