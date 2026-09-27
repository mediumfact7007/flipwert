#!/usr/bin/env python3
"""Fail closed when an Android workflow is explicitly marked for public release."""

from __future__ import annotations

import ipaddress
import os
import re
from datetime import date
from urllib.parse import urlsplit

PUBLIC_RELEASE_ACK = "approved-public-release-v1"
SOURCE_RIGHTS_ACK = "approved-current-source-rights-v1"
PLACEHOLDERS = ("example", "placeholder", "changeme", "tbd", "muster")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def _is_placeholder(value: str) -> bool:
    lowered = value.strip().lower()
    return not lowered or any(token in lowered for token in PLACEHOLDERS)


def _is_public_https(value: str) -> bool:
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError:
        return False
    host = (parsed.hostname or "").lower().rstrip(".")
    if (
        parsed.scheme != "https"
        or not host
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or port not in (None, 443)
        or host == "localhost"
        or host.endswith(".local")
        or _is_placeholder(host)
    ):
        return False
    try:
        return ipaddress.ip_address(host).is_global
    except ValueError:
        return "." in host


def validate_public_release(env: dict[str, str]) -> list[str]:
    if env.get("FLIPWERT_PUBLIC_RELEASE", "").strip().lower() != "true":
        return []

    errors: list[str] = []
    for key, label in (
        ("FLIPWERT_OPERATOR_NAME", "operator name"),
        ("FLIPWERT_OPERATOR_ADDRESS", "operator address"),
    ):
        if _is_placeholder(env.get(key, "")):
            errors.append(f"{label} is missing or still a placeholder")

    email = env.get("FLIPWERT_OPERATOR_EMAIL", "").strip()
    if _is_placeholder(email) or not EMAIL_RE.fullmatch(email):
        errors.append("operator email is missing, invalid, or still a placeholder")

    for key, label in (
        ("FLIPWERT_PRIVACY_URL", "privacy URL"),
        ("FLIPWERT_TERMS_URL", "terms URL"),
    ):
        if not _is_public_https(env.get(key, "").strip()):
            errors.append(f"{label} must be a public HTTPS URL without query or fragment")

    reviewed_at = env.get("FLIPWERT_LEGAL_REVIEWED_AT", "").strip()
    try:
        review_date = date.fromisoformat(reviewed_at)
        if review_date > date.today():
            errors.append("legal review date cannot be in the future")
    except ValueError:
        errors.append("legal review date must use YYYY-MM-DD")

    if env.get("FLIPWERT_LEGAL_REVIEW_ACK", "") != PUBLIC_RELEASE_ACK:
        errors.append("public-release legal review acknowledgement is missing")
    if env.get("FLIPWERT_SOURCE_RIGHTS_ACK", "") != SOURCE_RIGHTS_ACK:
        errors.append("current source-rights acknowledgement is missing")
    return errors


def main() -> int:
    errors = validate_public_release(dict(os.environ))
    if errors:
        print("Public release gate blocked the build:")
        for error in errors:
            print(f"- {error}")
        return 1
    if os.environ.get("FLIPWERT_PUBLIC_RELEASE", "").strip().lower() == "true":
        print("Public release gate passed.")
    else:
        print("Development/CI build: public release gate not requested.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
