import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final candidates = state.allCandidates;
    if (candidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('مقارنة المرشحين')),
        body: const CenterMessage(
          icon: Icons.compare_arrows_outlined,
          title: 'لا توجد مواقع مرشحة',
          message: 'أنشئ موقعاً من الخريطة أو شاشة الدراسة أولاً.',
        ),
      );
    }

    final engine = state.analyzer!;
    final analyses = {for (final c in candidates) c.id: engine.analyze(c)};
    final enough = candidates.length >= 2 &&
        candidates.every((c) => analyses[c.id]!.any((m) => m.key == 'population' && m.state == SearchState.success));

    return Scaffold(
      appBar: AppBar(title: const Text('مقارنة المرشحين')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionTitle(
            'مقارنة بمعايير موحدة',
            subtitle: 'النطاق والمصدر نفسه لكل موقع — لا تُقارن أرقام مستويات جغرافية مختلفة',
          ),
          if (!enough)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'لا يمكن إصدار ترتيب نهائي موثوق: البيانات المشتركة غير كافية. يمكن عرض المؤشرات جنباً إلى جنب للمراجعة فقط.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ),
          ...candidates.map((c) => _candidateCard(context, state, c, analyses[c.id]!)),
          SectionTitle('تداخل النطاقات', subtitle: 'مسافة بخط مستقيم بين مراكز المواقع'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _overlapRows(candidates),
                ),
              ),
            ),
          ),
          SectionTitle('درجة تنظيمية تفسيرية', subtitle: 'تظهر أوزان المعايير وأثر كل معيار'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'الدرجة أداة تنظيم للقرار وليست توقع مبيعات. لا تُمنح أفضلية خفية للمواقع ذات البيانات الناقصة.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidateCard(BuildContext context, AppState state, Candidate c, List<Metric> metrics) {
    final theme = Theme.of(context);
    final keys = ['branches', 'nearest', 'population', 'quality'];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(c.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                Text('${c.radiusKm.toStringAsFixed(0)} كم', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 10),
            for (final key in keys)
              ...metrics.where((m) => m.key == key).map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 120, child: Text(m.labelAr, style: theme.textTheme.bodySmall)),
                        Expanded(child: Text(m.valueAr, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  List<Widget> _overlapRows(List<Candidate> candidates) {
    final rows = <Widget>[];
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final a = candidates[i];
        final b = candidates[j];
        final d = GeoMath.distanceKm(
          _point(a.lat, a.lon),
          _point(b.lat, b.lon),
        );
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('${a.name} ↔ ${b.name}: ${Fmt.km(d)} — ${d <= a.radiusKm + b.radiusKm ? 'النطاقان متداخلان' : 'لا تداخل'}'),
        ));
      }
    }
    if (rows.isEmpty) rows.add(const Text('موقع واحد فقط — لا مقارنة.'));
    return rows;
  }

  LatLng _point(double lat, double lon) => LatLng(lat, lon);
}
