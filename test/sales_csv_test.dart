import 'package:flipwert/sales_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports German semicolon CSV and money format', () {
    final result = parseSalesCsv(
      'Artikel;Kategorie;Einkaufspreis;Verkaufspreis;Kaufdatum;Verkaufsdatum;Plattform;Nebenkosten\n'
      '"iPhone 15 Pro, 256 GB";Smartphone;800,00;1.299,99;01.09.2026;20.09.2026;eBay;19,90',
    );
    expect(result.errors, isEmpty);
    expect(result.rows, hasLength(1));
    expect(result.rows.single.article, 'iPhone 15 Pro, 256 GB');
    expect(result.rows.single.purchasePrice, 800);
    expect(result.rows.single.salePrice, closeTo(1299.99, .001));
    expect(result.rows.single.costs, closeTo(19.90, .001));
    expect(
      result.rows.single.saleDate
          .difference(result.rows.single.purchaseDate)
          .inDays,
      19,
    );
  });

  test('supports comma CSV with quoted decimal values', () {
    final result = parseSalesCsv(
      'Artikel,Kategorie,Einkaufspreis,Verkaufspreis,Kaufdatum,Verkaufsdatum,Plattform,Nebenkosten\n'
      'Pixel 9,Smartphone,"500,00","650,00",2026-09-01,2026-09-10,eBay,"10,00"',
    );
    expect(result.errors, isEmpty);
    expect(result.rows.single.salePrice, 650);
  });

  test('supports BOM, Windows line endings and quoted line breaks', () {
    final result = parseSalesCsv(
      '\ufeffArtikel;Kategorie;Einkaufspreis;Verkaufspreis;Kaufdatum;Verkaufsdatum;Plattform;Nebenkosten\r\n'
      '"Nintendo\r\nSwitch OLED";Konsole;180,00;249,99;01.09.2026;12.09.2026;Kleinanzeigen;5,00\r\n',
    );
    expect(result.errors, isEmpty);
    expect(result.rows, hasLength(1));
    expect(result.rows.single.article, 'Nintendo\r\nSwitch OLED');
    expect(result.rows.single.salePrice, closeTo(249.99, .001));
  });

  test('rejects missing columns and impossible sale dates', () {
    expect(
      parseSalesCsv('Artikel;Kategorie\nTest;Sonstiges').errors.single,
      contains('Pflichtspalte'),
    );
    final result = parseSalesCsv(
      'Artikel;Kategorie;Einkaufspreis;Verkaufspreis;Kaufdatum;Verkaufsdatum;Plattform;Nebenkosten\n'
      'Test;Sonstiges;10;20;20.09.2026;01.09.2026;eBay;0',
    );
    expect(result.rows, isEmpty);
    expect(result.errors.single, contains('Zeile 2'));
  });
  test('creates stable identity for repeated sale imports', () {
    const csv =
        'Artikel;Kategorie;Einkaufspreis;Verkaufspreis;Kaufdatum;Verkaufsdatum;Plattform;Nebenkosten\n'
        'iPhone 15 Pro;Smartphone;800,00;1.050,00;01.09.2026;20.09.2026;eBay;19,90';
    final first = parseSalesCsv(csv).rows.single;
    final second = parseSalesCsv(csv).rows.single;
    expect(salesCsvRowIdentity(first), salesCsvRowIdentity(second));
    expect(salesCsvRowIdentity(first), startsWith('csv-'));
  });

  test('identity changes when a material sale field changes', () {
    final first = parseSalesCsv(
      'Artikel;Kategorie;Einkaufspreis;Verkaufspreis;Kaufdatum;Verkaufsdatum;Plattform;Nebenkosten\n'
      'Pixel 9;Smartphone;500;650;01.09.2026;10.09.2026;eBay;10',
    ).rows.single;
    final second = parseSalesCsv(
      'Artikel;Kategorie;Einkaufspreis;Verkaufspreis;Kaufdatum;Verkaufsdatum;Plattform;Nebenkosten\n'
      'Pixel 9;Smartphone;500;675;01.09.2026;10.09.2026;eBay;10',
    ).rows.single;
    expect(salesCsvRowIdentity(first), isNot(salesCsvRowIdentity(second)));
  });
}
