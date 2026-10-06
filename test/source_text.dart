import 'dart:io';

String readLibDartSource() {
  final files = Directory('lib')
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  return files.map((file) => file.readAsStringSync()).join('\n');
}
