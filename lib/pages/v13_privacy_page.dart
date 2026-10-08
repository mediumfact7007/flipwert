part of '../v13_app.dart';

class V13PrivacyPage extends StatefulWidget {
  final bool english;
  final Future<bool> Function() onDeleteAllLocalData;

  const V13PrivacyPage({
    super.key,
    required this.english,
    required this.onDeleteAllLocalData,
  });

  @override
  State<V13PrivacyPage> createState() => _V13PrivacyPageState();
}

class _V13PrivacyPageState extends State<V13PrivacyPage> {
  bool deleting = false;

  String t(String de, String en) => widget.english ? en : de;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('Lokale Daten löschen?', 'Delete local data?')),
        content: Text(
          t(
            'Gespeicherte Flips, Suchverlauf, Alarm-Einstellungen, eigene Quellen und App-Einstellungen werden dauerhaft von diesem Gerät entfernt. Google-Play-Käufe bleiben beim Google-Konto erhalten.',
            'Saved flips, search history, alert settings, custom sources and app settings will be permanently removed from this device. Google Play purchases remain associated with the Google account.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('Abbrechen', 'Cancel')),
          ),
          FilledButton(
            key: const ValueKey('v13-confirm-delete-local-data'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(t('Endgültig löschen', 'Delete permanently')),
          ),
        ],
      ),
    );
    if (confirmed != true || deleting || !mounted) return;

    setState(() => deleting = true);
    final deleted = await widget.onDeleteAllLocalData();
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() => deleting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(
          'Die lokalen Daten konnten nicht vollständig gelöscht werden.',
          'The local data could not be deleted completely.',
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: const ValueKey('v13-privacy-page'),
        appBar: AppBar(
          title: Text(
            t('Daten & Datenschutz', 'Data & privacy'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 28),
          children: [
            _V13PrivacyCard(
              icon: Icons.phone_android_outlined,
              title: t('Auf diesem Gerät', 'On this device'),
              body: t(
                'Flipwert speichert deine Flips, Suchhistorie, Kalkulations-Einstellungen, selbst eingebundene Quellen und Deal-Alarm-Einstellungen lokal auf diesem Gerät.',
                'Flipwert stores your flips, search history, calculation settings, custom sources and deal alert settings locally on this device.',
              ),
            ),
            const SizedBox(height: 10),
            _V13PrivacyCard(
              icon: Icons.cloud_outlined,
              title: t('Online-Anfragen', 'Online requests'),
              body: t(
                'Für aktivierte Online-Quellen werden Suchbegriffe an den eingestellten Flipwert-Server übertragen. Geteilte Anzeigenlinks werden nicht automatisch abgerufen; externe Seiten öffnen sich nur nach deiner Aktion.',
                'For enabled online sources, search terms are sent to the configured Flipwert server. Shared listing links are not fetched automatically; external pages open only after your action.',
              ),
            ),
            const SizedBox(height: 10),
            _V13PrivacyCard(
              icon: Icons.person_off_outlined,
              title: t('Kein Flipwert-Konto', 'No Flipwert account'),
              body: t(
                'Diese Version besitzt kein Flipwert-Nutzerkonto und keine persönliche Cloud-Synchronisierung. Google Play verwaltet Käufe getrennt; Werbe-Datenschutzoptionen werden über den separaten Schalter in den Einstellungen verwaltet.',
                'This version has no Flipwert user account and no personal cloud sync. Google Play manages purchases separately; ad privacy options are managed using the separate control in Settings.',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t('Lokale Flipwert-Daten', 'Local Flipwert data'),
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              t(
                'Die Löschung kann nicht rückgängig gemacht werden. Danach startet Flipwert wieder mit dem Einstieg für neue Nutzer.',
                'Deletion cannot be undone. Flipwert will then restart with the new-user introduction.',
              ),
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF777B88)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('v13-delete-local-data'),
              onPressed: deleting ? null : _confirmDelete,
              icon: deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(t('Alle lokalen Daten löschen', 'Delete all local data')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 18),
            _V13PrivacyCard(
              icon: Icons.gavel_outlined,
              title: t('Vor öffentlicher Veröffentlichung', 'Before public release'),
              body: t(
                'Die Testversion ist nicht öffentlich freigegeben. Reale Betreiberangaben, veröffentlichte Datenschutzhinweise, Angebotsbedingungen und eine juristische Prüfung bleiben verpflichtende Release-Gates.',
                'The test version is not approved for public release. Real operator details, published privacy information, offer terms and legal review remain mandatory release gates.',
              ),
            ),
          ],
        ),
      );
}

class _V13PrivacyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _V13PrivacyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFE4E6EE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _v13Primary),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Color(0xFF666B78),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
