import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/models.dart';

/// تكامل Gemini. القواعد الصارمة:
///  - لا يُخزَّن أي مفتاح داخلAPK ولا داخل المستودع؛ المفتاح الذي يُدخله المستخدم
///    يُحفظ في keystore/Keychain فقط، ويمكن استبداله بخدمة خلفية لاحقاً.
///  - كل رقم مقترح يبقى «اقتراحاً للمراجعة» حتى يتحقق النظام من وجوده في صفحة المصدر،
///    ومن تطابق السنة والوحدة الجغرافية، ومن حدوده المنطقية.
class GeminiService {
  GeminiService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  static const _keyName = 'gemini_user_key';
  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

  Future<bool> hasKey() async => (await _storage.read(key: _keyName))?.isNotEmpty ?? false;

  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) throw ArgumentError('المفتاح فارغ');
    await _storage.write(key: _keyName, value: trimmed);
  }

  Future<void> clearKey() => _storage.delete(key: _keyName);

  Future<AiSuggestion> searchSources({
    required String placeName,
    required String model,
    String language = 'ar',
  }) async {
    final key = await _storage.read(key: _keyName);
    if (key == null || key.isEmpty) {
      return AiSuggestion(
        text: 'لم يُضبط مفتاح Gemini. أضف مفتاحك الخاص من الإعدادات، أو اربط خدمة خلفية.',
        verified: false,
        state: SearchState.failed,
      );
    }

    final prompt = '''
أنت مساعد بحث موثق لموقع فرع تجزئة في المملكة العربية السعودية.
المطلوب: أحدث أرقام سكان موثقة لمكان «$placeName» فقط، مع السنة والجهة الناشرة
والرابط الأصلي وتاريخ التحديث. اذكر ما لم تجده صراحةً.
قواعد صارمة: لا تخترع أرقاماً، لا تخلط مستويات جغرافية، لا تعرض تقديراً على أنه تعداد،
ولا تستنتج زيارات أو إيرادات. أعد الإجابة بنص عربي منظم مع روابط فعلية.
''';

    try {
      final uri = Uri.parse('$_endpoint/$model:generateContent').replace(queryParameters: {'key': key});
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.2},
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return AiSuggestion(
          text: 'تعذّر الاتصال بـ Gemini (رمز ${response.statusCode}). راجع المفتاح أو الاتصال.',
          verified: false,
          state: SearchState.failed,
        );
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return AiSuggestion(text: 'لم يُعدّ النموذج نتيجة.', verified: false, state: SearchState.empty);
      }
      final text = (((candidates.first as Map)['content'] as Map?)?['parts'] as List?)
              ?.map((p) => (p as Map)['text']?.toString() ?? '')
              .join() ??
          '';
      final links = _extractLinks(text);
      final verified = await _verifyLinks(text, links);
      return AiSuggestion(
        text: text,
        links: links,
        verified: verified,
        state: verified ? SearchState.partial : SearchState.failed,
        note: verified
            ? 'تم العثور على أرقام داخل صفحات المصادر؛ راجعها قبل اعتمادها.'
            : 'لم يتم التحقق من الأرقام تلقائياً؛ الاقتراح للمراجعة فقط ولا يدخل الحسابات.',
      );
    } catch (e) {
      return AiSuggestion(text: 'فشل البحث: $e', verified: false, state: SearchState.failed);
    }
  }

  List<String> _extractLinks(String text) {
    final re = RegExp(r'https?://[^\s<>"ّ]+');
    return re.allMatches(text).map((m) => m.group(0)!).take(5).toList();
  }

  /// يتحقق من أن صفحة المصدر نفسها تحتوي رقماً وسنة، ولا يقبل الاقتراح تلقائياً.
  Future<bool> _verifyLinks(String text, List<String> links) async {
    final numbers = RegExp(r'\d{1,3}(,\d{3})+|\d{5,}').allMatches(text).map((m) => m.group(0)!).toList();
    final years = RegExp(r'20(2[0-9]|3[0-9])').allMatches(text).map((m) => m.group(0)!).toList();
    if (numbers.isEmpty) return false;
    for (final link in links) {
      try {
        final r = await _client.get(Uri.parse(link)).timeout(const Duration(seconds: 12));
        final page = r.body.replaceAll(RegExp(r'<[^>]+>'), ' ');
        final hasNumber = numbers.any((n) => page.contains(n.replaceAll(',', '')) || page.contains(n));
        final hasYear = years.isEmpty || years.any((y) => page.contains(y));
        if (hasNumber && hasYear) return true;
      } catch (_) {
        // تجاهل الرابط غير المتاح واستمر في بقية الروابط.
      }
    }
    return false;
  }
}

class AiSuggestion {
  final String text;
  final List<String> links;
  final bool verified;
  final SearchState state;
  final String? note;

  const AiSuggestion({
    required this.text,
    this.links = const [],
    required this.verified,
    required this.state,
    this.note,
  });
}
