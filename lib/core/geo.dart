import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// حسابات مكانية صرفة، بعيدة عن الواجهة. المسافات بخط مستقيم (Great-circle)
/// وليست زمن قيادة أو مشي — هذه قاعدة غير قابلة للتفاوض في التطبيق.
abstract final class GeoMath {
  static const double earthRadiusKm = 6371.0088;
  static const List<double> radiusPresets = [1, 3, 5, 10, 20];

  static double distanceKm(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  /// مضلّع تقريبي لدائرة نصف قطرها [radiusKm] لرسمها على الخريطة.
  static List<LatLng> circlePolygon(LatLng center, double radiusKm, {int segments = 48}) {
    final pts = <LatLng>[];
    final latR = radiusKm / earthRadiusKm;
    for (var i = 0; i <= segments; i++) {
      final bearing = 2 * math.pi * i / segments;
      final lat = math.asin(
        math.sin(_rad(center.latitude)) * math.cos(latR) +
            math.cos(_rad(center.latitude)) * math.sin(latR) * math.cos(bearing),
      );
      final lon = _rad(center.longitude) +
          math.atan2(
            math.sin(bearing) * math.sin(latR) * math.cos(_rad(center.latitude)),
            math.cos(latR) - math.sin(_rad(center.latitude)) * math.sin(lat),
          );
      pts.add(LatLng(_deg(lat), _deg(lon)));
    }
    return pts;
  }

  static double _deg(double rad) => rad * 180 / math.pi;

  /// تجميع بسيط وفّال للعلامات عند التصغير، دون فقد أي فرع.
  /// المفتاح هو خلية شبكية بحجم [cellDeg]؛ تظهر العلامات مفردة عند التكبير.
  static Map<String, List<T>> clusterByCell<T>({
    required List<T> items,
    required double Function(T) lat,
    required double Function(T) lon,
    required double cellDeg,
  }) {
    final groups = <String, List<T>>{};
    for (final item in items) {
      final la = lat(item);
      final lo = lon(item);
      if (la == 0 && lo == 0) continue;
      final key = '${(la / cellDeg).floor()}|${(lo / cellDeg).floor()}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  static LatLng? parseCoordinates(String text) {
    final parts = text.replaceAll('،', ',').split(RegExp(r'[\s,;]+'));
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return LatLng(lat, lon);
  }

  static String formatCoordinates(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
}
