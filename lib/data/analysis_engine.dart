import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import '../core/geo.dart';
import '../core/models.dart';
import 'asset_repository.dart';

/// محرك التحليل: كل رقم يُنتج مع مصدره وسنته وحالته. لا يوجد هنا أي تخمين
/// لسكان الدائرة، ولا أي تحويل للمسافة المستقيمة إلى زمن قيادة.
class AnalysisEngine {
  AnalysisEngine(this.repo);

  final AssetRepository repo;

  List<Metric> analyze(Candidate c, {List<Branch>? extraBranches}) {
    final center = LatLng(c.lat, c.lon);
    final all = [...repo.branches, ...(extraBranches ?? [])];
    final inside = <Branch>[];
    final distances = <String, double>{};
    for (final b in all) {
      if (!b.hasCoordinates) continue;
      final d = GeoMath.distanceKm(center, LatLng(b.lat!, b.lon!));
      distances[b.id] = d;
      if (d <= c.radiusKm) inside.add(b);
    }
    inside.sort((a, b) => (distances[a.id] ?? 0).compareTo(distances[b.id] ?? 0));

    final metrics = <Metric>[];

    metrics.add(Metric(
      key: 'branches',
      labelAr: 'فروع مرصودة داخل النطاق',
      valueAr: Fmt.int_(inside.length),
      unitAr: 'فرع',
      source: 'قائمة الفروع المدمجة + ملفات مستوردة',
      state: SearchState.success,
      note: 'مسافة بخط مستقيم',
    ));

    if (inside.isEmpty) {
      metrics.add(Metric(
        key: 'nearest',
        labelAr: 'أقرب المنافسين',
        valueAr: 'لا فروع ضمن النطاق',
        source: 'قائمة الفروع المدمجة',
        state: SearchState.empty,
        note: 'صفر نتيجة بعد بحث ناجح؛ لا يعني غياب المنشآت فعلياً',
      ));
    } else {
      final nearest = inside.take(3).map((b) {
        final d = distances[b.id] ?? 0;
        return '${b.displayName} (${b.brand}) — ${Fmt.km(d)}';
      }).join(' · ');
      metrics.add(Metric(
        key: 'nearest',
        labelAr: 'أقرب المنافسين',
        valueAr: nearest,
        source: 'قائمة الفروع المدمجة',
        state: SearchState.success,
        note: 'مسافة بخط مستقيم',
      ));
    }

    final byBrand = <String, int>{};
    for (final b in inside) {
      byBrand[b.brand] = (byBrand[b.brand] ?? 0) + 1;
    }
    final brandSummary = byBrand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    metrics.add(Metric(
      key: 'brands',
      labelAr: 'توزيع العلامات',
      valueAr: brandSummary.isEmpty
          ? 'لا بيانات'
          : brandSummary.take(5).map((e) => '${e.key}: ${e.value}').join(' · '),
      source: 'قائمة الفروع المدمجة',
      state: brandSummary.isEmpty ? SearchState.empty : SearchState.success,
    ));

    // المرافق الحية تحتاج اتصالاً؛ لا نُظهر صفراً مزيفاً عند انقطاعه.
    for (final entry in [
      ('schools', 'المدارس'),
      ('hospitals', 'المستشفيات'),
      ('retail', 'متاجر التجزئة'),
    ]) {
      metrics.add(Metric(
        key: entry.$1,
        labelAr: entry.$2,
        valueAr: '—',
        source: 'بحث حي مرخّص (غير متصل حالياً)',
        state: SearchState.notRun,
        note: 'لم يُجرَ البحث؛ يتطلب اتصالاً ومصدراً مرخّصاً',
      ));
    }

    final place = _nearestPlace(center);
    final pop = place == null ? null : repo.populationFor(place.geoId);
    if (pop == null) {
      metrics.add(Metric(
        key: 'population',
        labelAr: 'السكان',
        valueAr: 'لم نعثر على رقم موثق لهذه الوحدة',
        source: 'تعداد 2022 المحفوظ محلياً',
        state: SearchState.empty,
      ));
    } else {
      final level = switch (place!.level) {
        GeoLevel.region => 'المنطقة',
        GeoLevel.governorate => 'المحافظة',
        GeoLevel.city => 'المدينة / التجمع',
        GeoLevel.district => 'الحي (دليل مجتمعي)',
        _ => 'وحدة جغرافية',
      };
      metrics.add(Metric(
        key: 'population',
        labelAr: 'سكان $level: ${place.displayName}',
        valueAr: Fmt.int_(pop.total),
        unitAr: 'نسمة',
        year: pop.year,
        source: pop.source,
        state: SearchState.success,
        note: 'تعداد رسمي للوحدة الجغرافية — ليس تقدير سكان دائرة الموقع',
      ));
    }

    final missing = all.where((b) => !b.hasCoordinates).length;
    metrics.add(Metric(
      key: 'quality',
      labelAr: 'جودة البيانات',
      valueAr: missing == 0
          ? 'كل الفروع لها إحداثيات'
          : '$missing فرع بلا إحداثيات صالحة',
      source: 'فحص الحقول تلقائياً',
      state: missing == 0 ? SearchState.success : SearchState.partial,
      note: 'قلة النتائج في مصدر مجتمعي لا تعني غياباً فعلياً',
    ));

    return metrics;
  }

  GeoPlace? _nearestPlace(LatLng center) {
    GeoPlace? best;
    var bestDistance = double.infinity;
    for (final place in [...repo.districts, ...repo.cities, ...repo.governorates, ...repo.regions]) {
      if (place.lat == null || place.lon == null) continue;
      final d = GeoMath.distanceKm(center, LatLng(place.lat!, place.lon!));
      if (d < bestDistance) {
        bestDistance = d;
        best = place;
      }
    }
    // لا ننسب رقم منطقة لحي بعيد عن مركزها؛ نكتفي بأقرب وحدة ضمن 60 كم.
    return bestDistance <= 60 ? best : null;
  }

  /// درجة تنظيمية تفسيرية. لا تُصدر إذا لم تتوفر المعايير المشتركة.
  static Map<String, double> score({
    required int competitorCount,
    required int? population,
    required int schools,
    required Map<String, double> weights,
  }) {
    final parts = <String, double>{
      'المنافسة': (1 / (1 + competitorCount)) * (weights['المنافسة'] ?? 0),
      'السكان': population == null ? 0 : (population > 100000 ? 1 : 0.5) * (weights['السكان'] ?? 0),
      'المرافق': (schools / 10).clamp(0, 1).toDouble() * (weights['المرافق'] ?? 0),
    };
    return parts;
  }
}
