import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/models.dart';

/// يقرأ البيانات المحلية المبسطة من الأصول. لا يحتاج أي اتصال بالإنترنت.
class AssetRepository {
  List<GeoPlace> regions = [];
  List<GeoPlace> governorates = [];
  List<GeoPlace> cities = [];
  List<GeoPlace> districts = [];
  List<PopulationStat> population = [];
  List<Branch> branches = [];
  List<List<double>> boundary = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    regions = await _places('assets/data/regions.json', GeoLevel.region);
    governorates = await _places('assets/data/governorates.json', GeoLevel.governorate);
    cities = await _places('assets/data/cities.json', GeoLevel.city);
    districts = await _places('assets/data/districts.json', GeoLevel.district);

    final popJson = await _list('assets/data/population.json');
    population = popJson.map((e) => PopulationStat.fromJson(e)).toList();

    final branchJson = await _list('assets/data/branches.json');
    branches = branchJson.map((e) => Branch.fromJson(e)).toList();

    final boundaryJson = json.decode(await rootBundle.loadString('assets/data/saudi_boundary.json'));
    final rings = boundaryJson['rings'] as List?;
    boundary = rings == null || rings.isEmpty
        ? []
        : (rings.first as List)
            .map<List<double>>((p) => (p as List).map<double>((v) => (v as num).toDouble()).toList())
            .toList();
    _loaded = true;
  }

  Future<List<GeoPlace>> _places(String path, GeoLevel level) async {
    final list = await _list(path);
    return list.map((e) => GeoPlace.fromJson(e, level)).toList();
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final decoded = json.decode(await rootBundle.loadString(path));
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  PopulationStat? populationFor(String geoId) {
    for (final p in population) {
      if (p.geoId == geoId) return p;
    }
    return null;
  }

  GeoPlace? placeByGeoId(String geoId) {
    for (final p in [...regions, ...governorates, ...cities, ...districts]) {
      if (p.geoId == geoId) return p;
    }
    return null;
  }

  List<GeoPlace> searchPlaces(String query) {
    final q = query.trim();
    if (q.isEmpty) return [];
    final all = [...regions, ...governorates, ...cities, ...districts];
    final found = all.where((p) => p.nameAr.contains(q) || p.nameEn.toLowerCase().contains(q.toLowerCase())).toList();
    found.sort((a, b) => a.nameAr.length.compareTo(b.nameAr.length));
    return found.take(40).toList();
  }
}
