import tempfile
from pathlib import Path

from prepare_android_play_signing import (
    DEBUG_SIGNING,
    MARKER,
    configure_play_signing,
)


def test_configures_and_is_idempotent() -> None:
    with tempfile.TemporaryDirectory() as directory:
        gradle = Path(directory) / "build.gradle.kts"
        gradle.write_text(
            'android {\n'
            '    buildTypes {\n'
            '        release {\n'
            f'            {DEBUG_SIGNING}\n'
            '        }\n'
            '    }\n'
            '}\n'
        )

        configure_play_signing(gradle)
        configured = gradle.read_text()
        assert MARKER in configured
        assert 'create("playRelease")' in configured
        assert 'getByName("release")' in configured
        assert "FLIPWERT_ANDROID_UPLOAD_STORE_FILE" in configured
        assert "FLIPWERT_ANDROID_UPLOAD_KEY_ALIAS" in configured
        assert "FLIPWERT_ANDROID_UPLOAD_STORE_PASSWORD" in configured
        assert "FLIPWERT_ANDROID_UPLOAD_KEY_PASSWORD" in configured

        configure_play_signing(gradle)
        assert gradle.read_text() == configured


def test_rejects_an_unknown_template() -> None:
    with tempfile.TemporaryDirectory() as directory:
        gradle = Path(directory) / "build.gradle.kts"
        gradle.write_text("android {}\n")
        try:
            configure_play_signing(gradle)
        except ValueError:
            return
        raise AssertionError("Unknown Gradle signing template must fail closed")


test_configures_and_is_idempotent()
test_rejects_an_unknown_template()
print("Android Play signing preparation tests passed")
