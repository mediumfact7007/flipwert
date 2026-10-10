# Öffentliches Android-Release-Gate

Dieses Gate verhindert, dass ein Android-Build versehentlich als öffentlicher
Release gebaut wird, solange zentrale Betreiber-, Datenschutz-, Angebots- und
Quellenfreigaben fehlen. Es ersetzt keine juristische Prüfung und aktiviert
keine LIVE-Datenquelle.

## Auslösen

Der Workflow **Build Android APK** läuft bei normalen Pushes weiterhin als
interner CI-/Test-Build. Für einen öffentlichen Kandidaten muss er manuell mit
`public_release=true` gestartet werden. Nur dann greift das strenge Gate.

Der nachgelagerte AAB-Workflow startet erst nach einem erfolgreichen APK-Lauf.
Ein blockierter öffentlicher APK-Kandidat kann deshalb kein AAB erzeugen.

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

**Achtung:** Der automatische AAB-Workflow übernimmt diese Build-Konfiguration
noch nicht und signiert nicht mit einem geprüften Play-Store-Release-Schlüssel.
Sein Artefakt heißt ausdrücklich `Flipwert-V0.14.8-INTERNAL-TEST-AAB`
und ist **ausschließlich für interne CI-Prüfungen**, nicht für die
Veröffentlichung im Play Store. Für einen öffentlichen AAB müssen dieselben
Freigaben, die Übernahme der geprüften Metadaten und eine geeignete
Release-Signierung separat eingerichtet und geprüft werden.

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
