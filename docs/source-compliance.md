# Datenquellen und Freigaben für Flipwert

Stand: 23. September 2026. Technische Produktgrenzen, keine Rechtsfreigabe.

| Quelle | Aktueller Abruf | Freigabe vor öffentlicher Preis-Anzeige |
| --- | --- | --- |
| Kleinanzeigen | Nur vom Nutzer geteilter Link oder Suchlink im externen Browser. Kein HTML-Abruf, Crawler, Preis-Import oder automatisierter Recheck. | Schriftliche Zustimmung für jeden späteren automatisierten Zugriff und für die beabsichtigte Datennutzung. Kleinanzeigen-AGB § 5 Abs. 1 untersagen Crawler/Scraper ohne ausdrückliche schriftliche Zustimmung. |
| eBay | Offizielle Browse API über den Server, Sandbox standardmäßig. | Production-Zugang, API-Lizenz und Bedingungen für Anzeige, Zuordnung, Aufbewahrung, Limits und Affiliate-Links vor Live-Schaltung prüfen. |
| Amazon/Keepa | Keepa API über den Server, nur bei vorhandenem Schlüssel. | Keepa-Vertrag, Amazon-Datenrechte, Aktualität, Attribution und Weitergabe der Daten für die konkrete App-Nutzung prüfen. |
| Ankaufportale | Kein realer Partnerpreis ohne konfigurierten Feed. Browser-Suchlinks sind keine Datenquelle. | Je Anbieter dokumentierter API-/Feed-Zugang oder Vereinbarung, die automatisierte Abrufe und Anzeige der Preise, Links und Marken erlaubt. Zustands- und Geräteattribute exakt zuordnen. |
| Importierte Adapter | Nutzer können eigene HTTPS-Manifeste als Referenz einbinden; Daten beeinflussen keine automatische Kaufentscheidung. | Vor offizieller Aufnahme Herkunft, Nutzungsrecht und Datenqualität einzeln prüfen; ein fremder Adapter verleiht keine Rechte an seinen Quelldaten. |

## Verbindlicher Integrationsablauf

1. Vor Implementierung Quelle, Verantwortlichen, Bedingungen, erlaubte Felder, Abruffrequenz, Caching, Weitergabe, Affiliate-Regeln und Ablaufdatum der Freigabe festhalten.
2. Nur offizielle/vertraglich gedeckte Schnittstellen automatisiert abrufen. Keine Suche nach internen Endpunkten, Login-Automatisierung, Anti-Bot-Umgehung oder Fremdseiten-HTML als vermeintlich freie Preis-API.
3. Preis, Währung, Variante, Zustand, Abrufzeit und Anbieter-Link gemeinsam validieren; fehlende Freigabe oder fehlender Preis ergibt leere Ergebnisse, keine Schätzung als Live-Angebot.
4. Bei Widerruf, Vertragsänderung oder Sperre betroffene Quelle serverseitig abschalten; keine gespeicherten Fremddaten nach Ende der Nutzungsrechte weiter ausspielen.

Das Buyback-Backend erzwingt diese Freigabe zusätzlich technisch: Neben der
HTTPS-Adapteradresse braucht jeder Anbieter einen eigenen aktuellen
Freigabedatensatz. Dieser bestätigt Feed-Abruf, Preisanzeige, Angebotslinks und
Anbieter-/Markendarstellung getrennt. Affiliate-/Werbelinks benötigen eine\nzusätzliche ausdrückliche Freigabe und werden sichtbar gekennzeichnet. Der Datensatz\nenthält interne Referenz, Prüfdatum,
Ablaufdatum sowie ausdrücklich genehmigte Feed- und Angebotslink-Hosts.
Freigaben gelten nur für den hinterlegten Feed-Host; abweichende Angebotslinks,
abgelaufene, unvollständige oder nicht im Datensatz enthaltene Anbieter-IDs aus
demselben Feed werden verworfen. Die Konfiguration bleibt
serverseitig und dokumentiert nur die bewusste Aktivierung; sie ersetzt keinen
Vertrag und keine juristische Prüfung.

## Veröffentlichungsgate Deutschland/EU

- Anbieterkennzeichnung und Kontakt nach [§ 5 DDG](https://www.gesetze-im-internet.de/ddg/__5.html) mit den tatsächlichen Betreiberangaben bereitstellen; keine Platzhalter veröffentlichen.
- Datenschutzhinweise für App, Backend, lokale Deal-Speicherung, externe Suchlinks und eingesetzte SDKs erstellen; Rechtsgrundlagen und Empfänger prüfen. Einwilligung/Endgerätezugriff nach [§ 25 TDDDG](https://www.gesetze-im-internet.de/ttdsg/__25.html) und Google-Vorgaben für AdMob gesondert prüfen.
- Vor Live-Billing und Werbung Preisdarstellung, Kaufbedingungen, Widerruf und Play-Store-Angaben für das konkrete Angebot prüfen.
- Rechte an Bildern, Namen, Marken, Texten und Datenbanken getrennt beurteilen. Insbesondere [§ 87b UrhG](https://www.gesetze-im-internet.de/urhg/__87b.html) bei wiederholter systematischer Datenübernahme beachten.
- Vor öffentlichem Release Anbietervereinbarungen und Verbraucher-/Datenschutztexte durch qualifizierte Rechtsberatung auf das Geschäftsmodell prüfen lassen. Kein technischer Test kann Abmahnfreiheit garantieren.

Kleinanzeigen-Nutzungsbedingungen: https://themen.kleinanzeigen.de/nutzungsbedingungen/ (§ 5 Abs. 1). eBay-API-Lizenz: https://developer.ebay.com/join/api-license-agreement.
