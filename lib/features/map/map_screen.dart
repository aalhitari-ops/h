import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _controller = MapController();
  final TextEditingController _search = TextEditingController();
  String? _brandFilter;
  bool _cluster = true;
  List<GeoPlace> _suggestions = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Branch> get _branches {
    final state = context.read<AppState>();
    var list = state.repo.branches;
    if (_brandFilter != null) {
      list = list.where((b) => b.brand == _brandFilter).toList();
    }
    return list.where((b) => b.hasCoordinates).toList();
  }

  void _runSearch(String value) {
    setState(() => _suggestions = context.read<AppState>().repo.searchPlaces(value));
  }

  void _goTo(LatLng point, {double zoom = 12}) {
    _controller.move(point, zoom);
    context.read<AppState>().rememberLocation(point);
    setState(() => _suggestions = []);
  }

  Future<void> _useGps() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض إذن الموقع. يمكنك تحديد النقطة يدوياً من الخريطة.')),
        );
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _goTo(LatLng(pos.latitude, pos.longitude), zoom: 15);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر الحصول على الموقع: $e')));
    }
  }

  void _confirmPoint(LatLng point) {
    final name = TextEditingController();
    final note = TextEditingController();
    double radius = context.read<AppState>().radiusKm;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تثبيت موقع المرشح'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الإحداثيات: ${Fmt.ltr(GeoMath.formatCoordinates(point))}'),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المرشح (اختياري)')),
                const SizedBox(height: 8),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة عن العقار أو الشارع')),
                const SizedBox(height: 12),
                Text('نطاق الدراسة: ${radius.toStringAsFixed(0)} كم — مسافة بخط مستقيم'),
                Slider(
                  value: radius,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  onChanged: (v) => setDialogState(() => radius = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final state = context.read<AppState>();
                await state.createCandidate(point: point, name: name.text, note: note.text, radius: radius);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المرشح. انتقل إلى شاشة الدراسة.')));
                }
              },
              child: const Text('حفظ والدراسة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final branches = _branches;
    final ownBrands = <String>{'الكل', ...state.repo.branches.map((b) => b.brand)};
    final markers = _buildMarkers(state, branches, theme);

    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة فروع التجزئة'),
        actions: [
          IconButton(tooltip: 'موقعي', onPressed: _useGps, icon: const Icon(Icons.my_location)),
          IconButton(
            tooltip: 'الطبقات',
            onPressed: () => _showLayers(context),
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'ابحث عن منطقة أو مدينة أو حي',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _suggestions.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _suggestions = [])),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            SizedBox(
              height: 170,
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, i) {
                  final p = _suggestions[i];
                  return ListTile(
                    title: Text(p.displayName),
                    subtitle: Text(switch (p.level) {
                      GeoLevel.region => 'منطقة',
                      GeoLevel.governorate => 'محافظة',
                      GeoLevel.city => 'مدينة / تجمع',
                      GeoLevel.district => 'حي',
                      _ => '',
                    }),
                    onTap: () {
                      if (p.lat != null && p.lon != null) {
                        _goTo(LatLng(p.lat!, p.lon!));
                      }
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ownBrands.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final b = ownBrands.elementAt(i);
                  return FilterChip(
                    label: Text(b),
                    selected: (_brandFilter ?? 'الكل') == b,
                    onSelected: (_) => setState(() => _brandFilter = b == 'الكل' ? null : b),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: state.lastLocation,
                initialZoom: 5.2,
                minZoom: 4,
                maxZoom: 18,
                onLongPress: (tapPosition, point) => _confirmPoint(point),
              ),
              children: [
                if (state.tileTemplate != null)
                  TileLayer(
                    urlTemplate: state.tileTemplate!,
                    userAgentPackageName: 'com.aalhitari.atlas_souq',
                  ),
                PolygonLayer(
                  polygons: <Polygon<Object>>[
                    if (state.repo.boundary.isNotEmpty)
                      Polygon<Object>(
                        points: state.repo.boundary.map((p) => LatLng(p[1], p[0])).toList(),
                        color: Colors.transparent,
                        borderColor: theme.colorScheme.primary.withOpacity(0.7),
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),
                if (state.layers['radius'] ?? true)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: state.lastLocation,
                        radius: state.radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderColor: theme.colorScheme.primary,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${branches.length} فرع معروض · ${state.repo.branches.length} فرع في قاعدة البيانات',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (state.tileTemplate != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 9)),
                    ),
                  TextButton.icon(
                    onPressed: () => setState(() => _cluster = !_cluster),
                    icon: Icon(_cluster ? Icons.filter_none : Icons.place_outlined, size: 18),
                    label: Text(_cluster ? 'مجمّع' : 'مفرد'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(AppState state, List<Branch> branches, ThemeData theme) {
    final markers = <Marker>[];
    if (state.layers['candidates'] ?? true) {
      for (final c in state.allCandidates) {
        markers.add(Marker(
          point: LatLng(c.lat, c.lon),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => state.selectCandidate(c),
            child: Icon(Icons.push_pin, color: theme.colorScheme.error, size: 32),
          ),
        ));
      }
    }
    if (!(state.layers['competitors'] ?? true)) return markers;

    if (_cluster) {
      final groups = GeoMath.clusterByCell(
        items: branches,
        lat: (b) => b.lat ?? 0,
        lon: (b) => b.lon ?? 0,
        cellDeg: 0.45,
      );
      for (final entry in groups.entries) {
        final list = entry.value;
        final lat = list.map((b) => b.lat!).reduce((a, b) => a + b) / list.length;
        final lon = list.map((b) => b.lon!).reduce((a, b) => a + b) / list.length;
        markers.add(Marker(
          point: LatLng(lat, lon),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showGroup(context, list),
            child: Container(
              decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${list.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ));
      }
    } else {
      for (final b in branches) {
        markers.add(Marker(
          point: LatLng(b.lat!, b.lon!),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () => _showBranch(context, b),
            child: const Icon(Icons.storefront, color: Color(0xFF15803D), size: 26),
          ),
        ));
      }
    }
    return markers;
  }

  void _showBranch(BuildContext context, Branch b) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.displayName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            InfoRow('العلامة', b.brand),
            InfoRow('المنطقة', b.region),
            InfoRow('المدينة', b.city),
            InfoRow('الحي', b.district.isEmpty ? 'غير محدد' : b.district),
            InfoRow('المصدر', b.source.isEmpty ? 'غير محدد' : b.source),
            InfoRow('تحديث البيانات', b.verification.isEmpty ? 'غير محدد' : b.verification),
            InfoRow('الإحداثيات', Fmt.ltr(GeoMath.formatCoordinates(LatLng(b.lat!, b.lon!)))),
          ],
        ),
      ),
    );
  }

  void _showGroup(BuildContext context, List<Branch> list) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 420,
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(list[i].displayName),
            subtitle: Text(list[i].brand),
            onTap: () {
              Navigator.pop(context);
              _showBranch(context, list[i]);
            },
          ),
        ),
      ),
    );
  }

  void _showLayers(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الطبقات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final entry in {
                'competitors': 'الفروع والمنافسون',
                'facilities': 'المرافق (بحث حي)',
                'population': 'السكان',
                'radius': 'نطاق الدراسة',
                'candidates': 'المواقع المرشحة',
              }.entries)
                SwitchListTile(
                  title: Text(entry.value),
                  value: state.layers[entry.key] ?? false,
                  onChanged: (_) {
                    state.toggleLayer(entry.key);
                    Navigator.pop(context);
                    _showLayers(context);
                  },
                ),
              const Text(
                'الطبقات المحلية تعمل دون إنترنت. طبقة الطرق والبحث الحي تحتاج اتصالاً ومصدراً مرخّصاً.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
