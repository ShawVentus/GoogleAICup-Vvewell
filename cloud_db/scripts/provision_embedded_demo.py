from __future__ import annotations

import base64
import json
import secrets
import uuid
from pathlib import Path

import requests
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from remote_lib import (
    SUPABASE_PUBLIC_KEY,
    SUPABASE_SECRET_KEY,
    SUPABASE_URL,
    extract_rows,
    management_sql,
    run_safely,
    sql_literal,
)


# DIRTY_DEMO_EMBEDDED_CREDENTIALS_REMOVE_BEFORE_RELEASE
# Keep these shares aligned with embedded_demo_cloud_credentials.dart.
_KEY_LEFT = bytes([
    241, 249, 141, 26, 98, 39, 242, 161, 214, 86, 7, 127, 73, 112, 84,
    227, 208, 11, 13, 110, 175, 49, 114, 87, 129, 133, 86, 234, 206, 227,
    208, 127,
])
_KEY_RIGHT = bytes([
    4, 236, 255, 83, 195, 28, 4, 231, 139, 52, 225, 14, 38, 124, 81,
    154, 66, 62, 191, 220, 148, 186, 29, 175, 173, 63, 73, 156, 76, 147,
    1, 215,
])
_APP_DIR = Path(__file__).resolve().parents[2] / "alloop-SDK"
_OUTPUT = _APP_DIR / "assets" / "demo_cloud_credentials.enc"


def _admin_headers() -> dict[str, str]:
    return {
        "apikey": SUPABASE_SECRET_KEY,
        "Authorization": f"Bearer {SUPABASE_SECRET_KEY}",
        "Content-Type": "application/json",
    }


def _create_auth_user(email: str, password: str) -> str:
    response = requests.post(
        f"{SUPABASE_URL}/auth/v1/admin/users",
        headers=_admin_headers(),
        json={"email": email, "password": password, "email_confirm": True},
        timeout=30,
    )
    payload = response.json() if response.content else {}
    if not response.ok or not payload.get("id"):
        raise RuntimeError(
            f"Creating hosted demo Auth user failed ({response.status_code})."
        )
    return str(payload["id"])


def _delete_auth_user(auth_user_id: str) -> None:
    requests.delete(
        f"{SUPABASE_URL}/auth/v1/admin/users/{auth_user_id}",
        headers=_admin_headers(),
        timeout=30,
    )


def _provision_application_records(auth_user_id: str, suffix: str) -> str:
    result = management_sql(
        f"""
        WITH app_user AS (
          INSERT INTO core.users (auth_uid, username, display_name)
          VALUES (
            {sql_literal(auth_user_id)}::uuid,
            {sql_literal('apk-demo-' + suffix)},
            'APK Demo User'
          )
          RETURNING id
        ), family AS (
          INSERT INTO core.families (owner_user_id, name)
          SELECT id, 'APK Demo Family' FROM app_user
          RETURNING id, owner_user_id
        ), member AS (
          INSERT INTO core.family_member (
            family_id, member_user_id, role, display_name, relation, age_group
          )
          SELECT id, owner_user_id, 'admin', 'APK Demo', 'self', 'adult'
          FROM family
          RETURNING id
        ), device AS (
          INSERT INTO core.devices (member_id, device_id, name, type, connected)
          SELECT id, 'phone_camera', 'Phone Camera', 'rppg_phone', true
          FROM member
          RETURNING member_id
        )
        SELECT member_id FROM device;
        """,
        "Provisioning hosted APK demo records",
    )
    rows = extract_rows(result)
    if len(rows) != 1 or not rows[0].get("member_id"):
        raise RuntimeError("Hosted APK demo provisioning returned no member ID.")
    return str(rows[0]["member_id"])


def _write_encrypted_dotenv(email: str, password: str, member_id: str) -> None:
    dotenv = "\n".join([
        f"SUPABASE_URL={SUPABASE_URL}",
        f"SUPABASE_PUBLISHABLE_KEY={SUPABASE_PUBLIC_KEY}",
        f"SUPABASE_MEMBER_ID={member_id}",
        f"SUPABASE_DEMO_EMAIL={email}",
        f"SUPABASE_DEMO_PASSWORD={password}",
        "",
    ]).encode()
    key = bytes(left ^ right for left, right in zip(_KEY_LEFT, _KEY_RIGHT))
    nonce = secrets.token_bytes(12)
    ciphertext = AESGCM(key).encrypt(nonce, dotenv, None)
    envelope = {
        "version": 1,
        "nonce": base64.b64encode(nonce).decode(),
        "ciphertext": base64.b64encode(ciphertext).decode(),
    }
    _OUTPUT.write_text(json.dumps(envelope, separators=(",", ":")) + "\n")


def main() -> None:
    suffix = uuid.uuid4().hex[:12]
    email = f"vvewell-apk-demo-{suffix}@example.test"
    password = secrets.token_urlsafe(36)
    auth_user_id = _create_auth_user(email, password)
    try:
        member_id = _provision_application_records(auth_user_id, suffix)
        _write_encrypted_dotenv(email, password, member_id)
    except Exception:
        _delete_auth_user(auth_user_id)
        raise

    print("Hosted demo Auth user, member, and phone_camera device provisioned.")
    print(f"Encrypted APK asset written; member ID: {member_id}")


if __name__ == "__main__":
    run_safely(main)
