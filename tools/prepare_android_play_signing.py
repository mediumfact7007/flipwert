from pathlib import Path
import sys

MARKER = "// Flipwert: Play upload-key signing"
DEBUG_SIGNING = 'signingConfig = signingConfigs.getByName("debug")'
SIGNING_BLOCK = r'''

// Flipwert: Play upload-key signing
val flipwertUploadStoreFile = System.getenv("FLIPWERT_ANDROID_UPLOAD_STORE_FILE")
    ?: throw GradleException("Missing FLIPWERT_ANDROID_UPLOAD_STORE_FILE")
val flipwertUploadKeyAlias = System.getenv("FLIPWERT_ANDROID_UPLOAD_KEY_ALIAS")
    ?: throw GradleException("Missing FLIPWERT_ANDROID_UPLOAD_KEY_ALIAS")
val flipwertUploadStorePassword = System.getenv("FLIPWERT_ANDROID_UPLOAD_STORE_PASSWORD")
    ?: throw GradleException("Missing FLIPWERT_ANDROID_UPLOAD_STORE_PASSWORD")
val flipwertUploadKeyPassword = System.getenv("FLIPWERT_ANDROID_UPLOAD_KEY_PASSWORD")
    ?: throw GradleException("Missing FLIPWERT_ANDROID_UPLOAD_KEY_PASSWORD")

android {
    signingConfigs {
        create("playRelease") {
            storeFile = file(flipwertUploadStoreFile)
            storePassword = flipwertUploadStorePassword
            keyAlias = flipwertUploadKeyAlias
            keyPassword = flipwertUploadKeyPassword
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("playRelease")
        }
    }
}
'''


def configure_play_signing(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"Android app Gradle file not found: {path}")

    text = path.read_text()
    if MARKER in text:
        return
    if DEBUG_SIGNING not in text:
        raise ValueError(
            "Generated Android release signing template changed; refusing to patch"
        )

    path.write_text(text.rstrip() + SIGNING_BLOCK + "\n")


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "android/app/build.gradle.kts"
    )
    try:
        configure_play_signing(path)
    except (FileNotFoundError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    print("Android Play upload signing configured")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
