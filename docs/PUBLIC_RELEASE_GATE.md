# Öffentliches Android-Release-Gate

Dieses Gate verhindert, dass ein Android-Build versehentlich als öffentlicher
Release gebaut wird, solange zentrale Betreiber-, Datenschutz-, Angebots- und
Quellenfreigaben fehlen. Es ersetzt keine juristische Prüfung und aktiviert
keine LIVE-Datenquelle.

## Auslösen

Der Workflow **Build Android APK** läuft bei normalen Pushes weiterhin als
interner CI-/Test-Build. Für einen öffentlichen Kandidaten muss er manuell mit
`public_release=true` gestartet werden. Nur dann greift das strenge Gate.

Der nachgelagerte **interne** AAB-Workflow startet ausschließlich nach einem
erfolgreichen APK-Lauf, der durch einen `push` auf `main` ausgelöst wurde.
Manuell angestoßene öffentliche APK-Kandidaten und Pull-Request-Builds lösen
kein AAB aus. Ein blockierter öffentlicher APK-Kandidat kann ebenfalls kein AAB
erzeugen.

## Erforderliche Repository-Variablen

| Variable | Anforderung |
| --- | --- |
| `FLIPWERT_OPERATOR_NAME` | Tatsächlicher Betreibername, kein Platzhalter |
| `FLIPWERT_OPERATOR_ADDRESS` | Ladungsfähige reale Anschrift, kein Platzhalter |
| `FLIPWERT_OPERATOR_EMAIL` | Gültige Betreiber-Kontaktadresse |
| `FLIPWERT_PRIVACY_URL` | Öffentliche HTTPS-URL ohne Query/Fragment |
| `FLIPWERT_TERMS_URL` | Öffentliche HTTPS-URL zu Angebots-/Nutzungsbedingungen |
| `FLIPWERT_LEGAL_REVIEWED_AT` | Datum der Prüfung im Format `YYYY-MM-DD`, nicht in der Zukunft |
| `FLIPWERT_LEGAL_REVIEW_ACK` | Exakt `approved-public-release-v1` |
| `FLIPWERT_SOURCE_RIGHTS_ACK` | Exakt `approved-current-source-rights-v1` |

Bei einem ausdrücklich freigegebenen öffentlichen **APK**-Build werden die fünf
Betreiber- und Linkwerte als öffentliche Build-Konfiguration in die App
eingebettet. Unter **Einstellungen → Daten & Datenschutz** erscheinen dann
die tatsächliche Anbieterkennzeichnung und externe HTTPS-Links zu Datenschutz
und Nutzungsbedingungen. Interne CI-/Test-APKs zeigen diese Angaben nicht
als Platzhalter an. Diese Build-Konfiguration darf keine Geheimnisse enthalten.

Der automatische AAB-Workflow übernimmt diese Build-Konfiguration nicht und
signiert nicht mit einem Play-Upload-Schlüssel. Sein Artefakt heißt ausdrücklich
`Flipwert-V0.14.8-INTERNAL-TEST-AAB` und ist **ausschließlich für interne
CI-Prüfungen**, nicht für die Veröffentlichung im Play Store.

Ein öffentlicher Kandidat wird getrennt und ausschließlich manuell über
**Build Android Play AAB** auf `main` erstellt. Dieser Workflow prüft erneut das
vollständige Release-Gate, führt Analyse und alle Flutter-Tests aus, bindet die
geprüften Betreiber- und Rechtstextwerte ein und verifiziert die Signatur des
AAB. Das Ergebnis heißt `Flipwert-V0.14.8-PLAY-UPLOAD-AAB-<commit>` und ist
damit exakt an den geprüften Commit gebunden.

## Erforderliche Repository-Secrets für Play AAB

| Secret | Inhalt |
| --- | --- |
| `FLIPWERT_ANDROID_UPLOAD_KEYSTORE_B64` | Base64-kodierter, ausschließlich außerhalb des Repositories verwahrter Play-Upload-Keystore |
| `FLIPWERT_ANDROID_UPLOAD_KEY_ALIAS` | Alias des Upload-Schlüssels |
| `FLIPWERT_ANDROID_UPLOAD_STORE_PASSWORD` | Passwort des Keystores |
| `FLIPWERT_ANDROID_UPLOAD_KEY_PASSWORD` | Passwort des Upload-Schlüssels |

Der Workflow bricht bei fehlenden oder ungültigen Werten ab. Er entschlüsselt
den Keystore nur temporär auf dem GitHub-Runner, lädt ihn nie als Artefakt hoch
und schreibt keine Zugangsdaten in App oder Repository. Vor der ersten
Einreichung muss Google Play App Signing eingerichtet und bestätigt werden,
dass genau dieser Schlüssel als Upload-Schlüssel registriert ist.

## Technische Monetarisierungssperre

Repository-Variablen und juristische Bestätigungen allein können den
öffentlichen Build nicht freigeben. Das Gate prüft zusätzlich den tatsächlich
eingebundenen Monetarisierungscode und blockiert derzeit bewusst, solange

- Google-Testkennungen für AdMob in App oder Android-Manifestvorbereitung
  enthalten sind oder
- ein Play-Kauf PRO noch direkt auf dem Gerät freischaltet, ohne den Kaufbeleg
  zuvor über einen vertrauenswürdigen Server zu verifizieren.

Damit kann weder eine öffentliche APK noch ein Play-Upload-AAB versehentlich
mit Testwerbung oder einer manipulierbaren Berechtigung entstehen. Interne
CI-/Test-Builds bleiben möglich. Vor der Aufhebung dieser Sperre müssen
Produktions-Werbekennungen, Einwilligungs-/Datenschutzprüfung und eine
serverseitige Play-Entitlement-Verifikation gemeinsam umgesetzt und geprüft
sein. Die Sperre ist nicht über eine zusätzliche Repository-Variable
übersteuerbar.

Die Werte liegen als GitHub-Repository-Variablen außerhalb des App-Quellcodes.
Zugangsdaten und API-Schlüssel gehören weiterhin ausschließlich in Secrets
beziehungsweise in die serverseitige Laufzeitkonfiguration.

## Bewusste Grenzen

- Das Gate bestätigt nur, dass die geforderten Freigabeschritte bewusst
  vorgenommen und dokumentiert wurden.
- LIVE-Anbieterpreise bleiben zusätzlich durch die separaten, anbieterspezifischen
  Feed-, Anzeige-, Link-, Marken- und Affiliate-Rechte im Backend geschützt.
- Ein öffentlich erreichbarer Preis oder eine Webseite ist weiterhin keine
  Erlaubnis für automatisierten Abruf oder erneute Veröffentlichung.
- Änderungen am Geschäftsmodell, an SDKs, Datenquellen oder Verträgen erfordern
  eine erneute Prüfung und eine aktualisierte Bestätigung.
