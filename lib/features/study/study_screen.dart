import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/models.dart';
import '../../data/gemini_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _step = 0;
  final _coords = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();
  AiSuggestion? _ai;
  bool _aiBusy = false;

  @override
  void dispose() {
    _coords.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final candidate = state.activeCandidate;
    final metrics = candidate == null ? <Metric>[] : state.analyzer!.analyze(candidate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('دراسة موقع جديد'),
        actions: [
          IconButton(
            tooltip: 'التقرير',
            onPressed: candidate == null ? null : () => context.push('/reports'),
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (i) => setState(() => _step = i),
        onStepContinue: () => setState(() => _step = (_step + 1).clamp(0, 2)),
        onStepCancel: () => setState(() => _step = (_step - 1).clamp(0, 2)),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              if (details.onStepContinue != null)
                FilledButton(onPressed: details.onStepContinue, child: const Text('التالي')),
              const SizedBox(width: 12),
              if (details.onStepCancel != null)
                TextButton(onPressed: details.onStepCancel, child: const Text('السابق')),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('تحديد الموقع'),
            isActive: _step >= 0,
            state: candidate != null ? StepState.complete : StepState.indexed,
            content: _locationStep(context, state, candidate),
          ),
          Step(
            title: const Text('نطاق الدراسة'),
            isActive: _step >= 1,
            content: _radiusStep(context, state),
          ),
          Step(
            title: const Text('النتائج'),
            isActive: _step >= 2,
            content: candidate == null
                ? const CenterMessage(
                    icon: Icons.place_outlined,
                    title: 'لم يحدد موقع بعد',
                    message: 'اختر مرشحاً محفوظاً أو أدخل إحداثيات دقيقة أو استخدم الموقع.',
                  )
                : _results(context, state, candidate, metrics),
          ),
        ],
      ),
    );
  }

  Widget _locationStep(BuildContext context, AppState state, Candidate? candidate) {
    final candidates = state.allCandidates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (candidates.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: candidate?.id,
            decoration: const InputDecoration(labelText: 'مرشح محفوظ', border: OutlineInputBorder()),
            items: candidates.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (id) {
              final c = candidates.firstWhere((x) => x.id == id);
              state.selectCandidate(c);
              setState(() {});
            },
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _coords,
          decoration: const InputDecoration(
            labelText: 'إحداثيات دقيقة (خط العرض، خط الطول)',
            hintText: '24.7136, 46.6753',
          ),
        ),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المرشح (اختياري)')),
        const SizedBox(height: 8),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة عن العقار أو الشارع')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final point = GeoMath.parseCoordinates(_coords.text);
                if (point == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إحداثيات غير صحيحة')));
                  return;
                }
                await state.createCandidate(point: point, name: _name.text, note: _note.text);
                setState(() {});
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('تثبيت النقطة'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final status = await Permission.location.request();
                if (!status.isGranted) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إذن الموقع مرفوض — استخدم الإحداثيات اليدوية.')));
                  return;
                }
                final pos = await Geolocator.getCurrentPosition();
                final point = LatLng(pos.latitude, pos.longitude);
                await state.createCandidate(point: point, name: _name.text, note: _note.text);
                setState(() {});
              },
              icon: const Icon(Icons.my_location),
              label: const Text('موقعي'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/map'),
              icon: const Icon(Icons.map_outlined),
              label: const Text('من الخريطة'),
            ),
          ],
        ),
        if (candidate != null) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('النقطة المختارة: ${candidate.name}', style: Theme.of(context).textTheme.titleSmall),
                  Text(Fmt.ltr(GeoMath.formatCoordinates(LatLng(candidate.lat, candidate.lon)))),
                  if (candidate.note.isNotEmpty) Text(candidate.note),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _radiusStep(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: GeoMath.radiusPresets.map((r) => FilterChip(
            label: Text('${r.toStringAsFixed(0)} كم'),
            selected: state.radiusKm == r,
            onSelected: (_) => state.setRadius(r),
          )).toList(),
        ),
        const SizedBox(height: 12),
        Slider(
          value: state.radiusKm,
          min: 1,
          max: 20,
          divisions: 19,
          label: '${state.radiusKm.toStringAsFixed(0)} كم',
          onChanged: (v) => state.setRadius(v),
        ),
        const Text(
          'كل النتائج مبنية على مسافة بخط مستقيم. زمن القيادة أو المشي يتطلب خدمة طرق مرخّصة في مرحلة لاحقة.',
          style: TextStyle(fontSize: 12),
        ),
        if (state.activeCandidate != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton(
              onPressed: () => state.updateCandidate(state.activeCandidate!.copyWith(radiusKm: state.radiusKm)),
              child: const Text('تحديث نطاق المرشح'),
            ),
          ),
      ],
    );
  }

  Widget _results(BuildContext context, AppState state, Candidate c, List<Metric> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('مؤشرات مختصرة', subtitle: 'كل رقم مع مصدره وسنته وحالة بحثه'),
        ...metrics.map((m) => MetricCard(m)).toList(),
        const SizedBox(height: 16),
        SectionTitle('بحث المصادر بالذكاء الاصطناعي', subtitle: 'اقتراحات للمراجعة فقط'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يبحث في مصادر حديثة عن ${c.name}، ويتحقق من وجود الأرقام داخل صفحات المصادر قبل عرضها.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _aiBusy ? null : () => _runAi(state, c),
                  icon: _aiBusy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('ابحث عن مصادر أحدث'),
                ),
                if (_ai != null) ...[
                  const SizedBox(height: 14),
                  StateChip(_ai!.state),
                  const SizedBox(height: 8),
                  Text(_ai!.text),
                  if (_ai!.note != null) ...[
                    const SizedBox(height: 8),
                    Text(_ai!.note!, style: const TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runAi(AppState state, Candidate c) async {
    setState(() => _aiBusy = true);
    final placeName = c.name.trim().isEmpty ? 'المملكة العربية السعودية' : c.name;
    final suggestion = await state.gemini.searchSources(
      placeName: placeName,
      model: state.geminiModel,
    );
    if (mounted) setState(() => _ai = suggestion);
    if (mounted) setState(() => _aiBusy = false);
  }
}
