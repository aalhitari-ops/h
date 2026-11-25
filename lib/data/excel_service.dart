import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../core/models.dart';

class ImportIssue {
  final int row;
  final String reason;
  const ImportIssue(this.row, this.reason);

  Map<String, dynamic> toMap() => {'row': row, 'reason': reason};
  factory ImportIssue.fromMap(Map<String, dynamic> m) =>
      ImportIssue(m['row'] as int, m['reason'] as String);
}

class ImportReport {
  final String fileName;
  final int read;
  final int accepted;
  final int rejected;
  final List<ImportIssue> issues;
  final List<Branch> rows;
  final Map<String, int> duplicates;

  const ImportReport({
    required this.fileName,
    required this.read,
    required this.accepted,
    required this.rejected,
    required this.issues,
    required this.rows,
    required this.duplicates,
  });
}

/// قراءة ملفات Excelyll بعيداً عن واجهة الرسم عبر compute/isolate.
class ExcelService {
  static Future<ImportReport> importBranches(File file) async {
    final bytes = await file.readAsBytes();
    final raw = await compute(_decodeBranches, bytes);
    final rows = (raw['rows'] as List)
        .map((e) => Branch.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return ImportReport(
      fileName: file.path.split(RegExp(r'[\\/]')).last,
      read: raw['read'] as int,
      accepted: raw['accepted'] as int,
      rejected: raw['rejected'] as int,
      issues: (raw['issues'] as List)
          .map((e) => ImportIssue.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      rows: rows,
      duplicates: Map<String, int>.from(raw['duplicates'] as Map),
    );
  }

  /// يقرأ الأعمدة العربية المطلوبة ويطبّق قواعد الرفض والتكرار.
  static Map<String, dynamic> _decodeBranches(Uint8List bytes) {
    final issues = <Map<String, dynamic>>[];
    final rows = <Map<String, dynamic>>[];
    final seen = <String, int>{};
    var read = 0;
    var accepted = 0;

    final book = Excel.decodeBytes(bytes);
    for (final table in book.tables.keys) {
      final sheet = book.tables[table]!;
      if (sheet.rows.isEmpty) continue;
      final header = sheet.rows.first
          .map((c) => (c?.value?.toString() ?? '').trim())
          .toList();

      int col(String name) {
        for (var i = 0; i < header.length; i++) {
          if (header[i].contains(name)) return i;
        }
        return -1;
      }

      final idx = {
        'brand': col('العلامة التجارية'),
        'name': col('اسم الفرع'),
        'region': col('المنطقة'),
        'city': col('المدينة'),
        'district': col('الحي'),
        'address': col('العنوان'),
        'lat': col('خط العرض'),
        'lon': col('خط الطول'),
        'source': col('اسم المصدر'),
        'date': col('تاريخ'),
      };

      for (var r = 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        read++;
        String value(String key) {
          final i = idx[key] ?? -1;
          if (i < 0 || i >= row.length) return '';
          return (row[i]?.value?.toString() ?? '').trim();
        }

        final lat = double.tryParse(value('lat').replaceAll(',', '.'));
        final lon = double.tryParse(value('lon').replaceAll(',', '.'));
        final source = value('source');
        if (source.isEmpty) {
          issues.add({'row': r + 1, 'reason': 'اسم المصدر ناقص'});
          continue;
        }
        if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          issues.add({'row': r + 1, 'reason': 'إحداثيات غير صحيحة أو ناقصة'});
          continue;
        }
        final key = '${value('brand')}|${value('name')}|${lat.toStringAsFixed(4)}|${lon.toStringAsFixed(4)}';
        if (seen.containsKey(key)) {
          issues.add({'row': r + 1, 'reason': 'تكرار داخل الملف مع الصف ${seen[key]}'});
          continue;
        }
        seen[key] = r + 1;
        accepted++;
        rows.add({
          'id': 'IMP_${r + 1}_${key.hashCode}',
          'brand': value('brand'),
          'name': value('name'),
          'code': '',
          'region': value('region'),
          'city': value('city'),
          'district': value('district'),
          'address': value('address'),
          'lat': lat,
          'lon': lon,
          'source': source,
          'verification': value('date'),
          'countStatus': 'مستورد',
          'regionGeoId': '',
          'govGeoId': '',
          'cityGeoId': '',
          'districtGeoId': '',
        });
      }
    }
    return {
      'read': read,
      'accepted': accepted,
      'rejected': issues.length,
      'issues': issues,
      'rows': rows,
      'duplicates': {'داخل الملف': issues.where((i) => i['reason'].toString().contains('تكرار')).length},
    };
  }

  /// ينشئقالب Excel عربي فارغاً بالأعمدة المطلوبة.
  static Uint8List buildTemplate() {
    final book = Excel.createExcel();
    final sheet = book['قالب الفروع'];
    sheet.isRTL = true;
    sheet.appendRow([
      'العلامة التجارية', 'اسم الفرع', 'المنطقة', 'المدينة', 'الحي',
      'العنوان', 'خط العرض', 'خط الطول', 'اسم المصدر', 'تاريخ تحديثه',
    ].map(TextCellValue.new).toList());
    sheet.appendRow([
      'مثال: بنده', 'فرع الرياض', 'الرياض', 'الرياض', 'حي العليا',
      'طريق الملك فهد', '24.6907', '46.6821', 'مصدر تجريبي', '2026-01-01',
    ].map(TextCellValue.new).toList());
    return Uint8List.fromList(book.save() ?? <int>[]);
  }

  /// تقرير Excel بأوراق منظمة وأعمدة عربية مفهومة.
  static Uint8List buildReport({
    required List<Map<String, String>> summary,
    required List<Map<String, String>> comparison,
    required List<Map<String, String>> branches,
    required List<Map<String, String>> sources,
  }) {
    final book = Excel.createExcel();
    void fill(String name, List<Map<String, String>> data) {
      final sheet = book[name];
      sheet.isRTL = true;
      if (data.isEmpty) {
        sheet.appendRow([TextCellValue('لا توجد بيانات')]);
        return;
      }
      sheet.appendRow(data.first.keys.map(TextCellValue.new).toList());
      for (final row in data) {
        sheet.appendRow(row.values.map((v) => TextCellValue(v)).toList());
      }
    }

    fill('الملخص', summary);
    fill('مقارنة المرشحين', comparison);
    fill('الفروع', branches);
    fill('المصادر والمنهجية', sources);
    return Uint8List.fromList(book.save() ?? <int>[]);
  }
}
