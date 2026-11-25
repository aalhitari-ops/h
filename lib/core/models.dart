// نماذج البيانات الأساسية لتطبيق أطلس السوق.
// القواعد الحاكمة: كل رقم يحمل مستواه الجغرافي وسنته ومصدره، ولا يُخلط بين
// تعداد المنطقة وسكان دائرة الموقع، ولا بين «لم يُبحث» و«صفر نتيجة».

enum GeoLevel { kingdom, region, governorate, city, district, point }
enum DataClass { census, estimate, community, unknown }
enum SearchState { notRun, success, empty, failed, partial }

extension SearchStateAr on SearchState {
  String get label => switch (this) {
        SearchState.notRun => 'لم يُجرَ البحث',
        SearchState.success => 'بحث ناجح',
        SearchState.empty => 'صفر نتيجة بعد بحث ناجح',
        SearchState.failed => 'فشل البحث',
        SearchState.partial => 'نتائج جزئية / بلغ حد المصدر',
      };
}

extension DataClassAr on DataClass {
  String get label => switch (this) {
        DataClass.census => 'تعداد رسمي',
        DataClass.estimate => 'تقدير',
        DataClass.community => 'دليل مجتمعي',
        DataClass.unknown => 'غير مصنّف',
      };
}

DataClass parseDataClass(String value) {
  final v = value.toLowerCase();
  if (v.contains('تعداد') || v.contains('census')) return DataClass.census;
  if (v.contains('تقدير') || v.contains('estimate')) return DataClass.estimate;
  if (v.contains('مجتمعي') || v.contains('community')) return DataClass.community;
  return DataClass.unknown;
}

class GeoPlace {
  final String geoId;
  final String nameAr;
  final String nameEn;
  final double? lat;
  final double? lon;
  final double? areaKm2;
  final int? regionId;
  final String? parentGeoId;
  final GeoLevel level;

  const GeoPlace({
    required this.geoId,
    required this.nameAr,
    required this.nameEn,
    this.lat,
    this.lon,
    this.areaKm2,
    this.regionId,
    this.parentGeoId,
    required this.level,
  });

  String get displayName => nameAr.isEmpty ? nameEn : nameAr;

  factory GeoPlace.fromJson(Map<String, dynamic> j, GeoLevel level) {
    return GeoPlace(
      geoId: (j['geoId'] ?? '').toString(),
      nameAr: (j['nameAr'] ?? '').toString(),
      nameEn: (j['nameEn'] ?? '').toString(),
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      areaKm2: (j['areaKm2'] as num?)?.toDouble(),
      regionId: (j['regionId'] as num?)?.toInt(),
      parentGeoId: j['parentGeoId']?.toString(),
      level: level,
    );
  }
}

class PopulationStat {
  final String geoId;
  final String nameAr;
  final int? year;
  final DataClass dataClass;
  final String source;
  final int? total;
  final int? male;
  final int? female;
  final int? saudi;
  final int? nonSaudi;
  final double? medianAge;
  final double? density;
  final String unit;

  const PopulationStat({
    required this.geoId,
    required this.nameAr,
    this.year,
    required this.dataClass,
    required this.source,
    this.total,
    this.male,
    this.female,
    this.saudi,
    this.nonSaudi,
    this.medianAge,
    this.density,
    required this.unit,
  });

  factory PopulationStat.fromJson(Map<String, dynamic> j) {
    return PopulationStat(
      geoId: (j['geoId'] ?? '').toString(),
      nameAr: (j['nameAr'] ?? '').toString(),
      year: (j['year'] as num?)?.toInt(),
      dataClass: parseDataClass((j['class'] ?? '').toString()),
      source: (j['source'] ?? '').toString(),
      total: (j['total'] as num?)?.toInt(),
      male: (j['male'] as num?)?.toInt(),
      female: (j['female'] as num?)?.toInt(),
      saudi: (j['saudi'] as num?)?.toInt(),
      nonSaudi: (j['nonSaudi'] as num?)?.toInt(),
      medianAge: (j['medianAge'] as num?)?.toDouble(),
      density: (j['density'] as num?)?.toDouble(),
      unit: (j['unit'] ?? '').toString(),
    );
  }
}

class Branch {
  final String id;
  final String brand;
  final String name;
  final String code;
  final String region;
  final String city;
  final String district;
  final String address;
  final double? lat;
  final double? lon;
  final String source;
  final String verification;
  final String countStatus;
  final String regionGeoId;
  final String govGeoId;
  final String cityGeoId;
  final String districtGeoId;

  const Branch({
    required this.id,
    required this.brand,
    required this.name,
    required this.code,
    required this.region,
    required this.city,
    required this.district,
    required this.address,
    required this.lat,
    required this.lon,
    required this.source,
    required this.verification,
    required this.countStatus,
    required this.regionGeoId,
    required this.govGeoId,
    required this.cityGeoId,
    required this.districtGeoId,
  });

  bool get hasCoordinates => lat != null && lon != null;

  String get displayName {
    final n = name.isNotEmpty ? name : code;
    return n.isEmpty ? 'فرع دون اسم' : n;
  }

  factory Branch.fromJson(Map<String, dynamic> j) {
    return Branch(
      id: (j['id'] ?? '').toString(),
      brand: (j['brand'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      code: (j['code'] ?? '').toString(),
      region: (j['region'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      district: (j['district'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      source: (j['source'] ?? '').toString(),
      verification: (j['verification'] ?? '').toString(),
      countStatus: (j['countStatus'] ?? '').toString(),
      regionGeoId: (j['regionGeoId'] ?? '').toString(),
      govGeoId: (j['govGeoId'] ?? '').toString(),
      cityGeoId: (j['cityGeoId'] ?? '').toString(),
      districtGeoId: (j['districtGeoId'] ?? '').toString(),
    );
  }
}

class Candidate {
  final String id;
  final String projectId;
  final String name;
  final String note;
  final double lat;
  final double lon;
  final double radiusKm;
  final DateTime createdAt;

  const Candidate({
    required this.id,
    required this.projectId,
    required this.name,
    required this.note,
    required this.lat,
    required this.lon,
    required this.radiusKm,
    required this.createdAt,
  });

  Candidate copyWith({
    String? name,
    String? note,
    double? radiusKm,
  }) {
    return Candidate(
      id: id,
      projectId: projectId,
      name: name ?? this.name,
      note: note ?? this.note,
      lat: lat,
      lon: lon,
      radiusKm: radiusKm ?? this.radiusKm,
      createdAt: createdAt,
    );
  }
}

class Project {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Candidate> candidates;

  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.candidates,
  });
}

class Metric {
  final String key;
  final String labelAr;
  final String valueAr;
  final String? unitAr;
  final int? year;
  final String source;
  final SearchState state;
  final String? note;

  const Metric({
    required this.key,
    required this.labelAr,
    required this.valueAr,
    this.unitAr,
    this.year,
    required this.source,
    required this.state,
    this.note,
  });
}

class SourceMeta {
  final String id;
  final String nameAr;
  final int? year;
  final String publisher;
  final String url;
  final DateTime? checkedAt;
  final DataClass kind;
  final String coverage;

  const SourceMeta({
    required this.id,
    required this.nameAr,
    this.year,
    required this.publisher,
    required this.url,
    this.checkedAt,
    required this.kind,
    required this.coverage,
  });
}
