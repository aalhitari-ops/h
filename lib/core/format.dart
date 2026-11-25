import 'package:intl/intl.dart';

abstract final class Fmt {
  static final NumberFormat _number = NumberFormat('#,###', 'ar');
  static final NumberFormat _decimal = NumberFormat('#,##0.0', 'ar');
  static final DateFormat _date = DateFormat('yyyy/MM/dd', 'ar');

  static String int_(num? v) => v == null ? 'غير متوفر' : _number.format(v);
  static String dec(num? v) => v == null ? 'غير متوفر' : _decimal.format(v);
  static String km(double? v) => v == null ? 'غير متوفر' : '${_decimal.format(v)} كم';
  static String date(DateTime? v) => v == null ? 'غير متوفر' : _date.format(v);

  /// الأرقام داخل السياق العربي تُعزل الاتجاه لمنع قلب ترتيب الإحداثيات.
  static String ltr(String value) => '\u200E$value\u200E';
}
