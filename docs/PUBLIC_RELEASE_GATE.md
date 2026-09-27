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
