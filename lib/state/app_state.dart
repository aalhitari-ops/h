import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/models.dart';
import '../data/analysis_engine.dart';
import '../data/asset_repository.dart';
import '../data/gemini_service.dart';
import '../data/local_database.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.repo,
    required this.db,
    required this.gemini,
  });

  final AssetRepository repo;
  final LocalDatabase db;
  final GeminiService gemini;

  bool ready = false;
  String? initError;
  ThemeMode themeMode = ThemeMode.system;
  String geminiModel = 'gemini-2.5-flash';
  String? tileTemplate;

  LatLng lastLocation = const LatLng(24.7136, 46.6753); // الرياض
  double radiusKm = 5;
  List<Project> projects = [];
  Candidate? activeCandidate;
  List<SourceMeta> sources = [];

  final Map<String, bool> layers = {
    'competitors': true,
    'facilities': false,
    'population': false,
    'radius': true,
    'candidates': true,
  };

  AnalysisEngine? get analyzer => ready ? AnalysisEngine(repo) : null;

  Future<void> init() async {
    try {
      await repo.load();
      projects = await db.loadProjects();
      sources = await db.loadSources();
      final savedTheme = await db.getSetting('theme');
      if (savedTheme != null) themeMode = _themeFrom(savedTheme);
      final savedModel = await db.getSetting('gemini_model');
      if (savedModel != null && savedModel.isNotEmpty) geminiModel = savedModel;
      final tile = await db.getSetting('tile_template');
      if (tile != null && tile.isNotEmpty) tileTemplate = tile;
      final lat = double.tryParse(await db.getSetting('last_lat') ?? '') ?? 24.7136;
      final lon = double.tryParse(await db.getSetting('last_lon') ?? '') ?? 46.6753;
      lastLocation = LatLng(lat, lon);
      final radius = double.tryParse(await db.getSetting('radius') ?? '');
      if (radius != null) radiusKm = radius;
      ready = true;
    } catch (e) {
      initError = e.toString();
    }
    notifyListeners();
  }

  ThemeMode _themeFrom(String v) {
    if (v == 'light') return ThemeMode.light;
    if (v == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    await db.setSetting('theme', mode.name);
    notifyListeners();
  }

  Future<void> setModel(String model) async {
    geminiModel = model.trim().isEmpty ? 'gemini-2.5-flash' : model.trim();
    await db.setSetting('gemini_model', geminiModel);
    notifyListeners();
  }

  Future<void> setTileTemplate(String? template) async {
    tileTemplate = (template == null || template.trim().isEmpty) ? null : template.trim();
    await db.setSetting('tile_template', tileTemplate ?? '');
    notifyListeners();
  }

  Future<void> rememberLocation(LatLng p) async {
    lastLocation = p;
    await db.setSetting('last_lat', p.latitude.toString());
    await db.setSetting('last_lon', p.longitude.toString());
    notifyListeners();
  }

  Future<void> setRadius(double value) async {
    radiusKm = value.clamp(0.2, 50.0);
    await db.setSetting('radius', radiusKm.toString());
    notifyListeners();
  }

  void toggleLayer(String key) {
    layers[key] = !(layers[key] ?? false);
    notifyListeners();
  }

  Future<Candidate> createCandidate({
    required LatLng point,
    required String name,
    required String note,
    double? radius,
  }) async {
    var projectId = projects.isEmpty ? null : projects.first.id;
    if (projectId == null) projectId = await db.createProject('مشروع الدراسة الأول');
    final c = Candidate(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      projectId: projectId,
      name: name.trim().isEmpty ? 'الموقع ${projects.fold(0, (n, p) => n + p.candidates.length) + 1}' : name.trim(),
      note: note.trim(),
      lat: point.latitude,
      lon: point.longitude,
      radiusKm: radius ?? radiusKm,
      createdAt: DateTime.now(),
    );
    await db.saveCandidate(c);
    projects = await db.loadProjects();
    activeCandidate = c;
    await rememberLocation(point);
    notifyListeners();
    return c;
  }

  Future<void> updateCandidate(Candidate c) async {
    await db.renameCandidate(c.id, c.name, c.note, c.radiusKm);
    projects = await db.loadProjects();
    activeCandidate = projects.expand((p) => p.candidates).firstWhere((x) => x.id == c.id);
    notifyListeners();
  }

  Future<void> deleteCandidate(String id) async {
    await db.deleteCandidate(id);
    projects = await db.loadProjects();
    if (activeCandidate?.id == id) activeCandidate = null;
    notifyListeners();
  }

  void selectCandidate(Candidate c) {
    activeCandidate = c;
    radiusKm = c.radiusKm;
    notifyListeners();
  }

  Future<void> addSources(List<SourceMeta> items) async {
    for (final s in items) {
      await db.saveSourceMeta(s);
    }
    sources = await db.loadSources();
    notifyListeners();
  }

  List<Candidate> get allCandidates => projects.expand((p) => p.candidates).toList();
}
