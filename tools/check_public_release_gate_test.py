#!/usr/bin/env python3
"""Regression checks for the public Android release gate."""

from datetime import date, timedelta

from check_public_release_gate import (
    PUBLIC_RELEASE_ACK,
    SOURCE_RIGHTS_ACK,
    validate_public_release,
)


def valid_environment() -> dict[str, str]:
    return {
        "FLIPWERT_PUBLIC_RELEASE": "true",
        "FLIPWERT_OPERATOR_NAME": "Flipwert GmbH",
        "FLIPWERT_OPERATOR_ADDRESS": "Marktstraße 1, 10115 Berlin",
        "FLIPWERT_OPERATOR_EMAIL": "kontakt@flipwert.de",
        "FLIPWERT_PRIVACY_URL": "https://flipwert.de/datenschutz",
        "FLIPWERT_TERMS_URL": "https://flipwert.de/bedingungen",
        "FLIPWERT_LEGAL_REVIEWED_AT": date.today().isoformat(),
        "FLIPWERT_LEGAL_REVIEW_ACK": PUBLIC_RELEASE_ACK,
        "FLIPWERT_SOURCE_RIGHTS_ACK": SOURCE_RIGHTS_ACK,
    }


def main() -> None:
    assert validate_public_release({}) == []

    missing = validate_public_release({"FLIPWERT_PUBLIC_RELEASE": "true"})
    assert len(missing) >= 8

    placeholder = valid_environment()
    placeholder["FLIPWERT_OPERATOR_NAME"] = "Muster GmbH"
    placeholder["FLIPWERT_PRIVACY_URL"] = "https://localhost/datenschutz"
    placeholder_errors = validate_public_release(placeholder)
    assert any("operator name" in error for error in placeholder_errors)
    assert any("privacy URL" in error for error in placeholder_errors)

    future = valid_environment()
    future["FLIPWERT_LEGAL_REVIEWED_AT"] = (
        date.today() + timedelta(days=1)
    ).isoformat()
    assert "legal review date cannot be in the future" in validate_public_release(future)

    assert validate_public_release(valid_environment()) == []
    print("Public release gate tests passed.")


if __name__ == "__main__":
    main()
