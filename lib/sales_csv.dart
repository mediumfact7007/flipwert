class SalesCsvRow {
  final String article; final String category; final double purchasePrice; final double salePrice;
  final DateTime purchaseDate; final DateTime saleDate; final String platform; final double costs;
  const SalesCsvRow({required this.article, required this.category, required this.purchasePrice, required this.salePrice, required this.purchaseDate, required this.saleDate, required this.platform, required this.costs});
}
class SalesCsvImport { final List<SalesCsvRow> rows; final List<String> errors; const SalesCsvImport(this.rows, this.errors); }
double _money(String raw) {
  var value=raw.trim().replaceAll('€','').replaceAll(RegExp(r'\\s+'),'').replaceAll(RegExp(r'[^0-9,.-]'),'');
  if(value.isEmpty)return double.nan; final comma=value.lastIndexOf(','); final dot=value.lastIndexOf('.');
  if(comma>=0&&dot>=0){value=comma>dot?value.replaceAll('.','').replaceAll(',','.'):value.replaceAll(',','');}
  else if(comma>=0){final decimals=value.length-comma-1;value=decimals==3&&comma>0?value.replaceAll(',',''):value.replaceAll(',','.');}
  else if(dot>=0&&value.length-dot-1==3&&dot>0){value=value.replaceAll('.','');}
  final parsed=double.tryParse(value); return parsed==null||!parsed.isFinite||parsed<0?double.nan:parsed;
}
DateTime? _date(String raw) {
  final value=raw.trim(); final iso=DateTime.tryParse(value); if(iso!=null)return DateTime(iso.year,iso.month,iso.day);
  final m=RegExp(r'^(\\d{1,2})[.]?(\\d{1,2})[.]?(\\d{4})$').firstMatch(value.replaceAll('/','.').replaceAll('-','.')); if(m==null)return null;
  final day=int.parse(m.group(1)!);final month=int.parse(m.group(2)!);final year=int.parse(m.group(3)!);final parsed=DateTime(year,month,day);
  return parsed.year==year&&parsed.month==month&&parsed.day==day?parsed:null;
}
List<String> _csvLine(String line,String delimiter){
  final out=<String>[];final field=StringBuffer();var quoted=false;
  for(var i=0;i<line.length;i++){final c=line[i];if(c=='"'){if(quoted&&i+1<line.length&&line[i+1]=='"'){field.write('"');i++;}else{quoted=!quoted;}}
  else if(c==delimiter&&!quoted){out.add(field.toString().trim());field.clear();}else{field.write(c);}}
  out.add(field.toString().trim());return out;
}
String _header(String value)=>value.toLowerCase().trim().replaceAll('ä','ae').replaceAll('ö','oe').replaceAll('ü','ue').replaceAll(RegExp(r'[^a-z0-9]'),'');
SalesCsvImport parseSalesCsv(String input){
  final normalized=input.replaceAll('\\r\\n','\\n').replaceAll('\\r','\\n').replaceFirst('\\ufeff','');final lines=normalized.split('\\n').where((e)=>e.trim().isNotEmpty).toList();
  if(lines.isEmpty)return const SalesCsvImport([],['CSV ist leer.']);final delimiter=lines.first.split(';').length>=lines.first.split(',').length?';':',';
  final headers=_csvLine(lines.first,delimiter).map(_header).toList();const required=['artikel','kategorie','einkaufspreis','verkaufspreis','kaufdatum','verkaufsdatum','plattform','nebenkosten'];final index=<String,int>{};
  for(final name in required){final i=headers.indexOf(name);if(i<0)return SalesCsvImport(const [],['Pflichtspalte fehlt: '+name]);index[name]=i;}
  final rows=<SalesCsvRow>[];final errors=<String>[];
  for(var lineNo=1;lineNo<lines.length;lineNo++){final cells=_csvLine(lines[lineNo],delimiter);String cell(String key)=>index[key]!<cells.length?cells[index[key]!]:'';
    final article=cell('artikel').trim();final category=cell('kategorie').trim();final buy=_money(cell('einkaufspreis'));final sale=_money(cell('verkaufspreis'));final costs=_money(cell('nebenkosten').isEmpty?'0':cell('nebenkosten'));final bought=_date(cell('kaufdatum'));final sold=_date(cell('verkaufsdatum'));final platform=cell('plattform').trim();
    if(article.isEmpty||category.isEmpty||platform.isEmpty||!buy.isFinite||!sale.isFinite||sale<=0||!costs.isFinite||bought==null||sold==null||sold.isBefore(bought)){errors.add('Zeile '+(lineNo+1).toString()+': ungültige oder unvollständige Verkaufsdaten.');continue;}
    rows.add(SalesCsvRow(article:article,category:category,purchasePrice:buy,salePrice:sale,purchaseDate:bought,saleDate:sold,platform:platform,costs:costs));
  } return SalesCsvImport(List.unmodifiable(rows),List.unmodifiable(errors));
}
