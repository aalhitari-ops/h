import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/excel_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  static const _builtin = [
    ('تعداد السعودية 2022', 'الهيئة العامة للإحصاء — أرقام رسمية محفوظة محلياً', DataClass.census),
    ('دليل المناطق والمحافظات', 'حدود مرجعية بحثية، ليست حدود تعداد معتمدة', DataClass.community),
    ('دليل المدن والتجمعات', 'دليل مجتمعي — لا أرقام سكان', DataClass.community),
    ('دليل الأحياء', 'دليل وحدود مجتمعية', DataClass.community),
    ('قائمة الفروع المدمجة', '11 علامة تجارية، 1,164 فرعاً', DataClass.community),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('البيانات والمصادر')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionTitle('المصادر المدمجة', subtitle: 'تعمل دون إنترنت — مع بيان طبيعة كل مصدر'),
          ..._builtin.map((e) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(e.$3 == DataClass.census ? Icons.account_balance : Icons.source_outlined),
                  title: Text(e.$1),
                  subtitle: Text(e.$2),
                ),
              )),
          SectionTitle('قوائم مستوردة', subtitle: 'لكل مصدر حالة واضحة وتاريخ استيراد'),
          if (state.sources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('لا توجد قوائم مستوردة بعد.', style: TextStyle(color: AppColors.muted)),
            ),
          ...state.sources.map((s) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(s.nameAr),
                  subtitle: Text('السنة: ${s.year ?? 'غير محدد'} · الجهة: ${s.publisher.isEmpty ? 'غير محدد' : s.publisher} · التغطية: ${s.coverage}'),
                  trailing: Text(Fmt.date(s.checkedAt)),
                ),
              )),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _downloadTemplate(context),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('قالب Excel عربي'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _import(context, state),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('استيراد قائمة منافسين'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'التغطية غير معروفة تُعرض صراحةً بدل نسبة مختلقة. استيراد ملف باسم مصدر قائم يحدّث ذلك المصدر وحده داخل معاملة ذرية.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/atlas_branches_template.xlsx');
    await file.writeAsBytes(ExcelService.buildTemplate());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ القالب: ${file.path}')));
    }
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (files.isEmpty || files.first.path == null) return;
    final report = await ExcelService.importBranches(File(files.first.path!));
    final sourceName = TextEditingController(text: report.fileName.replaceAll(RegExp(r'\.xlsx$'), ''));

    if (!context.mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مراجعة الاستيراد قبل اعتماده'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: sourceName, decoration: const InputDecoration(labelText: 'اسم المصدر')),
                const SizedBox(height: 12),
                Text('صفوف مقروءة: ${report.read} · مقبولة: ${report.accepted} · مرفوضة: ${report.rejected}'),
                if (report.issues.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('أسباب الرفض:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...report.issues.take(12).map((i) => Text('صف ${i.row}: ${i.reason}')),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد')),
        ],
      ),
    );
    if (approved != true) return;

    final name = sourceName.text.trim().isEmpty ? 'مصدر مستورد' : sourceName.text.trim();
    await state.db.replaceSourceBranches(name, report.rows);
    await state.addSources([
      SourceMeta(
        id: name,
        nameAr: name,
        year: DateTime.now().year,
        publisher: 'المستخدم',
        url: '',
        checkedAt: DateTime.now(),
        kind: DataClass.community,
        coverage: 'التغطية غير معروفة',
      ),
    ]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استيراد المصدر بنجاح.')));
    }
  }
}
