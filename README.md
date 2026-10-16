# Flipwert V0.14.8

**[Aktuelle Android-Test-APK direkt herunterladen](https://github.com/mediumfact7007/flipwert/releases/download/test-latest/flipwert-test.apk)** (fester Link; neue Builds ersetzen die Datei nach erfolgreicher CI auf `main`).

Die Test-APK wird nur mit dauerhaftem Signierschlüssel veröffentlicht. Erforderliche GitHub Actions Secrets: `FLIPWERT_TEST_KEYSTORE_B64`, `FLIPWERT_TEST_STORE_PASSWORD`, `FLIPWERT_TEST_KEY_ALIAS`, `FLIPWERT_TEST_KEY_PASSWORD`. Ohne diese Secrets schlägt der `main`-APK-Build absichtlich fehl; vorhandene Installationen benötigen denselben Schlüssel für Updates.

Installierbare Android-Testversion von Flipwert.

## Enthalten
- Deutsch und Englisch
- Deal-Analyse
- Gewinn- und ROI-Rechner
- Flip Score
- Demo Deal Finder und testbare Marketplace-Integration
- Marktqualitätsfilter gegen unpassende, defekte oder reine Reparatur-Angebote
- Recheck-Bewertung für Preis-, Gewinn- und ROI-Änderungen
- Kleinanzeigen-Share-Flow mit manueller Preiseingabe und Original-Link
- Manuell übernommene Ankaufpreise aus dem eigenen Anbieterbesuch werden lokal verglichen und klar von geprüften LIVE-Feeds getrennt
- Meine Flips / lokales Test-Inventar
- Profil und Spracheinstellungen

## Sicherheits- und Integrationsgrenzen
- Marketplace-Sandbox und LIVE-Konfiguration bleiben getrennt.
- Marketplace-Credentials gehören nicht in den Android-Client.
- Kein automatisierter Abruf von Kleinanzeigen-Inseraten; der frühere Import-Endpunkt antwortet mit HTTP 410.
- Quellenrechte und Veröffentlichungsgates: [docs/source-compliance.md](docs/source-compliance.md).
- Billing wird lazy initialisiert, damit der App-Start nicht davon abhängt.
- AdMob bleibt vom kritischen Startpfad isoliert.
- Änderungen an Marktfiltern und Recheck-Logik werden mit Regressionstests abgesichert.

## Android Builds
Die Release-APK und das Android App Bundle werden automatisch mit GitHub Actions gebaut und geprüft.

Workflows:
- `.github/workflows/build-android-apk.yml`
- `.github/workflows/build-android-aab.yml`

Die APK-Pipeline führt zusätzlich statische Analyse, Tests und kritische Regressionstests aus. Eine APK sollte nur aus einem vollständig grünen Lauf als Teststand verwendet werden.

## Marketplace-Status
Die App ist weiterhin eine Testversion. Sandbox-/Testintegration ist kein LIVE-Marktplatzbetrieb. LIVE-Zugänge, echte Secrets und Production-Freigaben werden nicht im Repository hinterlegt oder automatisch aktiviert.
