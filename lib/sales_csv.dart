class SalesCsvRow {
  final String article;
  final String category;
  final double purchasePrice;
  final double salePrice;
  final DateTime purchaseDate;
  final DateTime saleDate;
  final String platform;
  final double costs;

  const SalesCsvRow({
    required this.article,
    required this.category,
    required this.purchasePrice,
    required this.salePrice,
    required this.purchaseDate,
    required this.saleDate,
    required this.platform,
    required this.costs,
  });
}

class SalesCsvImport {
  final List<SalesCsvRow> rows;
  final List<String> errors;

  const SalesCsvImport(this.rows, this.errors);
}

double _money(String raw) {
  var value = raw
      .trim()
      .replaceAll('€', '')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (value.isEmpty) return double.nan;

  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    value = comma > dot
        ? value.replaceAll('.', '').replaceAll(',', '.')
        : value.replaceAll(',', '');
  } else if (comma >= 0) {
    final decimals = value.length - comma - 1;
    value = decimals == 3 && comma > 0
        ? value.replaceAll(',', '')
        : value.replaceAll(',', '.');
  } else if (dot >= 0 && value.length - dot - 1 == 3 && dot > 0) {
    value = value.replaceAll('.', '');
  }

  final parsed = double.tryParse(value);
  return parsed == null || !parsed.isFinite || parsed < 0
      ? double.nan
      : parsed;
}

DateTime? _date(String raw) {
  final value = raw.trim();
  final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
  final localMatch = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
      .firstMatch(value);
  final match = isoMatch ?? localMatch;
  if (match == null) return null;

  final year = int.parse(match.group(isoMatch == null ? 3 : 1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(isoMatch == null ? 1 : 3)!);
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? parsed
      : null;
}

int _delimiterCount(String input, String delimiter) {
  var quoted = false;
  var count = 0;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && char == delimiter) {
      count++;
    } else if (!quoted && (char == '\n' || char == '\r')) {
      break;
    }
  }
  return count;
}

List<List<String>> _csvRecords(String input, String delimiter) {
  final records = <List<String>>[];
  var record = <String>[];
  final field = StringBuffer();
  var quoted = false;

  void finishField() {
    record.add(field.toString().trim());
    field.clear();
  }

  void finishRecord() {
    finishField();
    if (record.any((cell) => cell.isNotEmpty)) records.add(record);
    record = <String>[];
  }

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && char == delimiter) {
      finishField();
    } else if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      finishRecord();
    } else {
      field.write(char);
    }
  }
  if (field.isNotEmpty || record.isNotEmpty) finishRecord();
  return records;
}

String _header(String value) => value
    .toLowerCase()
    .trim()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

SalesCsvImport parseSalesCsv(String input) {
  final normalized = input.startsWith('\ufeff') ? input.substring(1) : input;
  if (normalized.trim().isEmpty) {
    return const SalesCsvImport([], ['CSV ist leer.']);
  }

  final delimiter = _delimiterCount(normalized, ';') >=
          _delimiterCount(normalized, ',')
      ? ';'
      : ',';
  final records = _csvRecords(normalized, delimiter);
  if (records.isEmpty) return const SalesCsvImport([], ['CSV ist leer.']);

  final headers = records.first.map(_header).toList();
  const required = [
    'artikel',
    'kategorie',
    'einkaufspreis',
    'verkaufspreis',
    'kaufdatum',
    'verkaufsdatum',
    'plattform',
    'nebenkosten',
  ];
  final index = <String, int>{};
  for (final name in required) {
    final position = headers.indexOf(name);
    if (position < 0) {
      return SalesCsvImport(const [], ['Pflichtspalte fehlt: $name']);
    }
    index[name] = position;
  }

  final rows = <SalesCsvRow>[];
  final errors = <String>[];
  for (var rowIndex = 1; rowIndex < records.length; rowIndex++) {
    final cells = records[rowIndex];
    String cell(String key) =>
        index[key]! < cells.length ? cells[index[key]!] : '';

    final article = cell('artikel').trim();
    final category = cell('kategorie').trim();
    final platform = cell('plattform').trim();
    final buy = _money(cell('einkaufspreis'));
    final sale = _money(cell('verkaufspreis'));
    final costsRaw = cell('nebenkosten');
    final costs = _money(costsRaw.isEmpty ? '0' : costsRaw);
    final bought = _date(cell('kaufdatum'));
    final sold = _date(cell('verkaufsdatum'));

    if (article.isEmpty ||
        category.isEmpty ||
        platform.isEmpty ||
        !buy.isFinite ||
        !sale.isFinite ||
        sale <= 0 ||
        !costs.isFinite ||
        bought == null ||
        sold == null ||
        sold.isBefore(bought)) {
      errors.add(
        'Zeile ${rowIndex + 1}: ungültige oder unvollständige Verkaufsdaten.',
      );
      continue;
    }

    rows.add(SalesCsvRow(
      article: article,
      category: category,
      purchasePrice: buy,
      salePrice: sale,
      purchaseDate: bought,
      saleDate: sold,
      platform: platform,
      costs: costs,
    ));
  }
  return SalesCsvImport(List.unmodifiable(rows), List.unmodifiable(errors));
}


String salesCsvRowIdentity(SalesCsvRow row) {
  String text(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  String money(double value) => value.toStringAsFixed(2);
  String date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  final canonical = [
    text(row.article),
    text(row.category),
    money(row.purchasePrice),
    money(row.salePrice),
    date(row.purchaseDate),
    date(row.saleDate),
    text(row.platform),
    money(row.costs),
  ].join('|');

  // Stable FNV-1a fingerprint. It is deliberately local/non-secret: its only
  // purpose is to make repeated imports of the same sale idempotent.
  var hash = 0xcbf29ce484222325;
  for (final byte in canonical.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return 'csv-${hash.toRadixString(16).padLeft(16, '0')}';
}
