from __future__ import annotations

import hashlib
import os
import re
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests
from dotenv import load_dotenv


DB_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = DB_DIR / ".env"

if not load_dotenv(ENV_FILE, override=False):
    raise RuntimeError("cloud_db/.env could not be loaded through python-dotenv")


def _required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Required environment variable {name} is missing")
    return value


SUPABASE_URL = _required("SUPABASE_URL").rstrip("/")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or _required("SUPABASE_SECRET_KEY")
SUPABASE_PUBLIC_KEY = os.getenv("SUPABASE_ANON_KEY") or _required("SUPABASE_PUBLIC_KEY")
SUPABASE_ACCESS_TOKEN = os.getenv("SUPABASE_ACCESS_TOKEN", "")
PROJECT_REF = (urlparse(SUPABASE_URL).hostname or "").split(".")[0]

if not re.fullmatch(r"[a-z]{20}", PROJECT_REF):
    raise RuntimeError("SUPABASE_URL does not contain a valid project reference")

_SENSITIVE_VALUES = tuple(filter(None, (
    SUPABASE_URL,
    SUPABASE_SECRET_KEY,
    SUPABASE_PUBLIC_KEY,
    SUPABASE_ACCESS_TOKEN,
    PROJECT_REF,
)))


def redact(value: object) -> str:
    result = str(value)
    for sensitive in _SENSITIVE_VALUES:
        result = result.replace(sensitive, "[redacted]")
    return result


def checksum(content: str) -> str:
    return hashlib.sha256(content.encode()).hexdigest()


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def migration_files() -> list[tuple[str, str, str]]:
    files = []
    for path in sorted((DB_DIR / "migrations").glob("[0-9][0-9][0-9][0-9]_*.sql")):
        files.append((path.name, path.stem, path.read_text(encoding="utf-8")))
    return files


def _safe_remote_detail(payload: Any) -> str:
    if isinstance(payload, dict):
        detail = payload.get("error") or payload.get("message") or payload.get("hint")
    else:
        detail = None
    return redact(detail or "remote request failed")[:1200]


def management_sql(query: str, label: str, *, read_only: bool = False) -> Any:
    if not SUPABASE_ACCESS_TOKEN:
        raise RuntimeError(
            "SUPABASE_ACCESS_TOKEN is required for Supabase Management API SQL access; "
            "anon and service-role project API keys cannot execute DDL"
        )
    response = requests.post(
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query",
        headers={
            "Authorization": f"Bearer {SUPABASE_ACCESS_TOKEN}",
            "Content-Type": "application/json",
        },
        json={"query": query, "read_only": read_only},
        timeout=120,
    )
    try:
        payload = response.json()
    except requests.JSONDecodeError:
        payload = {}

    if not response.ok or (isinstance(payload, dict) and payload.get("error")):
        hint = (
            " SUPABASE_ACCESS_TOKEN does not have Supabase Management API database access."
            if response.status_code in (401, 403)
            else ""
        )
        raise RuntimeError(
            f"{label} failed with HTTP {response.status_code}.{hint} "
            f"{_safe_remote_detail(payload)}"
        )
    return payload.get("result", payload) if isinstance(payload, dict) else payload


def extract_rows(result: Any) -> list[dict[str, Any]]:
    if not isinstance(result, list):
        return []
    if len(result) == 1 and isinstance(result[0], list):
        result = result[0]
    return [row for row in result if isinstance(row, dict)]


def registered_api_key_roles(key: str) -> set[str]:
    if not SUPABASE_ACCESS_TOKEN:
        return set()
    response = requests.get(
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/api-keys",
        headers={"Authorization": f"Bearer {SUPABASE_ACCESS_TOKEN}"},
        timeout=30,
    )
    try:
        payload = response.json()
    except requests.JSONDecodeError:
        payload = []
    if not response.ok or not isinstance(payload, list):
        raise RuntimeError(
            f"Checking Supabase API-key roles failed with HTTP {response.status_code}. "
            f"{_safe_remote_detail(payload)}"
        )

    key_hash = hashlib.sha256(key.encode()).hexdigest()
    roles = set()
    for item in payload:
        if not isinstance(item, dict):
            continue
        candidate = str(item.get("api_key") or item.get("key") or "")
        candidate_hash = str(item.get("hash") or "")
        if candidate == key or candidate_hash == key_hash:
            roles.add(f"{item.get('name', 'unnamed')}:{item.get('type', 'unknown')}")
    return roles


def rest_request(key: str, resource: str, query: str = "") -> tuple[int, str]:
    headers = {"apikey": key, "Accept": "application/json"}
    if key.startswith("eyJ") and key.count(".") == 2:
        headers["Authorization"] = f"Bearer {key}"
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/{resource}{query}",
        headers=headers,
        timeout=30,
    )
    return response.status_code, redact(response.text)[:2000]


def run_safely(main: Any) -> None:
    try:
        main()
    except Exception as error:
        raise SystemExit(redact(error)) from None
