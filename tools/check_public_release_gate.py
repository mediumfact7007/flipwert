#!/usr/bin/env python3
"""Fail closed when an Android workflow is explicitly marked for public release."""

from __future__ import annotations

import ipaddress
import os
import re
from datetime import date
from pathlib import Path
from urllib.parse import urlsplit

PUBLIC_RELEASE_ACK = "approved-public-release-v1"
SOURCE_RIGHTS_ACK = "approved-current-source-rights-v1"
PLACEHOLDERS = ("example", "placeholder", "changeme", "tbd", "muster")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
GOOGLE_SAMPLE_AD_ID = "ca-app-pub-3940256099942544"


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


def _monetization_errors(repo_root: Path) -> list[str]:
    errors: list[str] = []
    models_path = repo_root / "lib" / "models" / "v13_models.dart"
    entitlement_client_path = repo_root / "lib" / "pro_entitlement.dart"
    entitlement_server_path = repo_root / "server" / "play_entitlement.js"
    server_index_path = repo_root / "server" / "index.js"
    settings_path = repo_root / "lib" / "pages" / "v13_settings_page.dart"
    shell_path = repo_root / "lib" / "pages" / "v13_shell.dart"
    android_path = repo_root / "tools" / "prepare_android_ci.py"
    try:
        models = models_path.read_text(encoding="utf-8")
        entitlement_client = entitlement_client_path.read_text(encoding="utf-8")
        entitlement_server = entitlement_server_path.read_text(encoding="utf-8")
        server_index = server_index_path.read_text(encoding="utf-8")
        settings = settings_path.read_text(encoding="utf-8")
        shell = shell_path.read_text(encoding="utf-8")
        android = android_path.read_text(encoding="utf-8")
    except OSError:
        return ["monetization release sources could not be verified"]

    if GOOGLE_SAMPLE_AD_ID in models or GOOGLE_SAMPLE_AD_ID in android:
        errors.append("Google sample AdMob IDs are still configured")

    purchase_start = models.find("Future<void> _purchaseUpdate(")
    purchase_end = models.find("Future<bool> rewardedUnlock()", purchase_start)
    if purchase_start < 0 or purchase_end < 0:
        errors.append("Play purchase entitlement flow could not be verified")
    elif "onProUnlocked();" in models[purchase_start:purchase_end]:
        errors.append(
            "Play purchases still grant PRO on-device without trusted server verification"
        )
    elif "_entitlementVerifier.verify(" not in models[purchase_start:purchase_end]:
        errors.append("Play purchase entitlement does not call the trusted verifier")

    if (
        "/v1/entitlements/google-play" not in entitlement_client
        or "androidpublisher.googleapis.com" not in entitlement_server
        or "verifyPlayEntitlement" not in server_index
    ):
        errors.append("trusted Google Play server verification is incomplete")
    if "PRO TEST" in settings or "setInt('plan_v13'" in shell:
        errors.append("local PRO preview or persistence is still enabled")
    return errors


def validate_public_release(
    env: dict[str, str], repo_root: Path | None = None
) -> list[str]:
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
    if repo_root is not None:
        errors.extend(_monetization_errors(repo_root))
    return errors


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    errors = validate_public_release(dict(os.environ), repo_root=repo_root)
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
