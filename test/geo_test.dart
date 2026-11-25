import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:atlas_souq/core/geo.dart';

void main() {
  test('المسافة بخط مستقيم بين الرياض والدمام منطقية', () {
    final d = GeoMath.distanceKm(const LatLng(24.7136, 46.6753), const LatLng(26.4344, 50.1017));
    expect(d, greaterThan(300));
    expect(d, lessThan(400));
  });

  test('مضلّع الدائرة مغلق وله عدد نقاط صحيح', () {
    final ring = GeoMath.circlePolygon(const LatLng(24.7, 46.6), 5);
    expect(ring.length, 49);
    expect(ring.first.latitude, closeTo(ring.last.latitude, 1e-6));
  });

  test('قراءة الإحداثيات ترفض القيم خارج النطاق', () {
    expect(GeoMath.parseCoordinates('24.7, 46.6'), isNotNull);
    expect(GeoMath.parseCoordinates('95, 10'), isNull);
  });

  test('التجميع لا يحذف العناصر', () {
    final items = [1.0, 1.1, 9.0];
    final groups = GeoMath.clusterByCell(
      items: items,
      lat: (v) => v,
      lon: (v) => 46.0,
      cellDeg: 1.0,
    );
    expect(groups.values.expand((x) => x).length, 3);
  });
}
