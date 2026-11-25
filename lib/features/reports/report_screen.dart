import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/excel_service.dart';
import '../../data/export_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final candidates = state.allCandidates;

    return Scaffold(
      appBar: AppBar(title: const Text('التقرير والتصدير')),
      body: candidates.isEmpty
          ? const CenterMessage(icon: Icons.description_outlined, title: 'لا توجد دراسة لتصديرها')
          : _ReportBody(state: state, candidates: candidates),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.state, required this.candidates});

  final AppState state;
  final List<Candidate> candidates;

  @override
  Widget build(BuildContext context) {
    final selected = state.activeCandidate ?? candidates.first;
    final metrics = state.analyzer!.analyze(selected);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SectionTitle('اختر موقعاً', subtitle: 'يمكن توسيع التقرير لاحقاً ليشمل مقارنة عدة مواقع'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            initialValue: selected.id,
            decoration: const InputDecoration(labelText: 'الموقع', border: OutlineInputBorder()),
            items: candidates.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (id) {
              final c = candidates.firstWhere((x) => x.id == id);
              state.selectCandidate(c);
            },
          ),
        ),
        const SectionTitle('ملخص قابل للمراجعة', subtitle: 'الأرقام من محرك التحليل، والروابط من المصادر'),
        ...metrics.map((m) => MetricCard(m)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _exportExcel(context, selected, metrics),
                icon: const Icon(Icons.grid_on_outlined),
                label: const Text('Excel منظّم'),
              ),
              FilledButton.icon(
                onPressed: () => _exportHtml(context, selected),
                icon: const Icon(Icons.map_outlined),
                label: const Text('خريطة HTML'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'قبل التصدير: لا يُحوَّل «لم يُبحث» إلى صفر، ولا يُعرض سكان المنطقة تحت عنوان «سكان الدائرة»، ولا تُحذف تنبيهات نقص التغطية.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Future<void> _exportExcel(BuildContext context, Candidate c, List<Metric> metrics) async {
    final summary = metrics
        .map((m) => {
              'المؤشر': m.labelAr,
              'القيمة': m.valueAr,
              'الوحدة': m.unitAr ?? '',
              'السنة': m.year?.toString() ?? '',
              'المصدر': m.source,
              'الحالة': m.state.label,
            })
        .toList();
    final branches = state.repo.branches
        .where((b) => b.hasCoordinates)
        .take(300)
        .map((b) => {
              'العلامة التجارية': b.brand,
              'اسم الفرع': b.displayName,
              'المنطقة': b.region,
              'المدينة': b.city,
              'الحي': b.district,
              'المصدر': b.source,
            })
        .toList();
    final sources = state.sources
        .map((s) => {
              'المصدر': s.nameAr,
              'السنة': s.year?.toString() ?? '',
              'الجهة': s.publisher,
              'الرابط': s.url,
              'تاريخ الفحص': s.checkedAt?.toIso8601String() ?? '',
              'التغطية': s.coverage,
            })
        .toList();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/atlas_report_${c.id}.xlsx');
    await file.writeAsBytes(ExcelService.buildReport(
      summary: summary,
      comparison: summary,
      branches: branches,
      sources: sources,
    ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ التقرير: ${file.path}')));
    }
  }

  Future<void> _exportHtml(BuildContext context, Candidate c) async {
    final markers = state.repo.branches
        .where((b) => b.hasCoordinates)
        .take(200)
        .map((b) => {'lat': b.lat, 'lon': b.lon, 'brand': b.brand, 'name': b.displayName, 'source': b.source})
        .toList();
    final html = HtmlMapExport.build(
      title: 'أطلس السوق — ${c.name}',
      center: LatLng(c.lat, c.lon),
      radiusKm: c.radiusKm,
      boundary: state.repo.boundary,
      markers: markers,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/atlas_map_${c.id}.html');
    await file.writeAsString(html);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الخريطة: ${file.path}')));
    }
  }
}
