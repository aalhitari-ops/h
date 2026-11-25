import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final keyController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionHeader('المظهر'),
          ListTile(
            title: const Text('الوضع'),
            subtitle: Text(switch (state.themeMode) {
              ThemeMode.light => 'نهاري',
              ThemeMode.dark => 'داكن',
              ThemeMode.system => 'حسب النظام',
            }),
            trailing: DropdownButton<ThemeMode>(
              value: state.themeMode,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('النظام')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('نهاري')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('داكن')),
              ],
              onChanged: (v) {
                if (v != null) state.setTheme(v);
              },
            ),
          ),
          const ListTile(
            title: Text('تقليل الحركة'),
            subtitle: Text('يُقرأ من إعداد إمكانية الوصول في النظام؛ تُلغى الحركات عند تفعيله.'),
            leading: Icon(Icons.accessibility_new_outlined),
          ),
          const SectionHeader('الخرائط'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'قالب بلاطات مرخّص (اختياري)',
                hintText: 'https://your-provider/{z}/{x}/{y}.png',
                helperText: 'اتركه فارغاً للعمل دون إنترنت. لا تُحمّل بلاطات OpenStreetMap العامة جماعياً.',
                helperMaxLines: 3,
              ),
              onSubmitted: (v) => state.setTileTemplate(v),
            ),
          ),
          const SectionHeader('الذكاء الاصطناعي'),
          ListTile(
            title: const Text('نموذج Gemini'),
            subtitle: Text(state.geminiModel),
            trailing: SizedBox(
              width: 170,
              child: TextField(
                decoration: const InputDecoration(hintText: 'اسم النموذج'),
                onSubmitted: (v) => state.setModel(v),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: keyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'مفتاح Gemini الخاص بالمستخدم',
                helperText: 'يُحفظ في keystore الجهاز فقط. لا تستخدم مفتاحاً مشتركاً، ولا يُضمّن أي مفتاح داخل APK.',
                helperMaxLines: 3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: () async {
                    if (keyController.text.trim().isEmpty) return;
                    await state.gemini.saveKey(keyController.text);
                    keyController.clear();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المفتاح بأمان.')));
                  },
                  child: const Text('حفظ المفتاح'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    await state.gemini.clearKey();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المفتاح.')));
                  },
                  child: const Text('حذف'),
                ),
              ],
            ),
          ),
          const SectionHeader('النسخ الاحتياطي والتصدير'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('نسخة احتياطية من قاعدة البيانات'),
            subtitle: const Text('تُحفظ في مجلد مستندات التطبيق ويمكن نقلها عبر منتقي ملفات Systems'),
            onTap: () async {
              final dir = await getApplicationDocumentsDirectory();
              final target = File('${dir.path}/atlas_souq_backup_${DateTime.now().millisecondsSinceEpoch}.db');
              final file = await state.db.backupTo(target);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ: ${file.path}')));
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'النسخة المحلية لا تحتاج حساباً. طبقة الطرق والبحث الحي وتقديرات السكان المكانية تحتاج مصادر مرخّصة في مرحلة لاحقة.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
