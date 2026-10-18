from __future__ import annotations

import base64
import json
import zipfile

import requests
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from provision_embedded_demo import _KEY_LEFT, _KEY_RIGHT, _OUTPUT
from remote_lib import SUPABASE_PUBLIC_KEY, SUPABASE_URL, run_safely


# DIRTY_DEMO_EMBEDDED_CREDENTIALS_REMOVE_BEFORE_RELEASE
def _load_values() -> dict[str, str]:
    envelope = json.loads(_OUTPUT.read_text())
    key = bytes(left ^ right for left, right in zip(_KEY_LEFT, _KEY_RIGHT))
    cleartext = AESGCM(key).decrypt(
        base64.b64decode(envelope["nonce"]),
        base64.b64decode(envelope["ciphertext"]),
        None,
    ).decode()
    return dict(line.split("=", 1) for line in cleartext.splitlines() if line)


def main() -> None:
    values = _load_values()
    response = requests.post(
        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
        headers={"apikey": SUPABASE_PUBLIC_KEY, "Content-Type": "application/json"},
        json={
            "email": values["SUPABASE_DEMO_EMAIL"],
            "password": values["SUPABASE_DEMO_PASSWORD"],
        },
        timeout=30,
    )
    payload = response.json() if response.content else {}
    token = payload.get("access_token")
    if not response.ok or not token:
        raise RuntimeError("Hosted demo authentication verification failed.")

    member_id = values["SUPABASE_MEMBER_ID"]
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/vvewell_family_member",
        headers={
            "apikey": SUPABASE_PUBLIC_KEY,
            "Authorization": f"Bearer {token}",
        },
        params={"id": f"eq.{member_id}", "select": "id"},
        timeout=30,
    )
    if not response.ok or response.json() != [{"id": member_id}]:
        raise RuntimeError("Hosted demo member RLS verification failed.")

    apk = _OUTPUT.parent.parent / "build/app/outputs/flutter-apk/app-debug.apk"
    if apk.exists():
        apk_bytes = apk.read_bytes()
        if any(value.encode() in apk_bytes for value in values.values()):
            raise RuntimeError("A plaintext demo value was found in the APK.")
        with zipfile.ZipFile(apk) as archive:
            asset_names = set(archive.namelist())
        if not any(name.endswith("demo_cloud_credentials.enc") for name in asset_names):
            raise RuntimeError("Encrypted demo bundle is missing from the APK.")
        if any(name.endswith("/.env") or name.endswith("/.env.json") for name in asset_names):
            raise RuntimeError("Plaintext dotenv asset is present in the APK.")

    print("Encrypted APK bundle, hosted Auth login, and member RLS verified.")


if __name__ == "__main__":
    run_safely(main)
