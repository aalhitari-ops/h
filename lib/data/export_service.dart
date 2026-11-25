import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../core/geo.dart';

/// خريطة HTML تفاعلية قابلة للحفظ محلياً. عرضها في المتصفح يحتاج إنترنت
/// لتحميل مكتبة Leaflet من CDN؛ حفظ الملف مختلف عن نشر رابط عام.
class HtmlMapExport {
  static String build({
    required String title,
    required LatLng center,
    required double radiusKm,
    required List<List<double>> boundary,
    required List<Map<String, dynamic>> markers,
  }) {
    final circle = GeoMath.circlePolygon(center, radiusKm)
        .map((p) => [p.longitude, p.latitude])
        .toList();
    final payload = {
      'title': title,
      'center': [center.longitude, center.latitude],
      'radius': radiusKm,
      'boundary': boundary,
      'circle': circle,
      'markers': markers,
    };
    return '''
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>body{margin:0;font-family:Tahoma,Arial,sans-serif}#map{height:100vh}</style>
</head>
<body>
<div id="map"></div>
<script>
const D = ${jsonEncode(payload)};
const map = L.map('map', {zoomControl:true}).setView(D.center, 10);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 18,
  attribution: '&copy; OpenStreetMap contributors'
}).addTo(map);
if (D.boundary && D.boundary.length) {
  D.boundary.forEach(function(r){
    L.polygon(r.map(function(p){return [p[1], p[0]];}), {color:'#0e7490', weight:2, fillOpacity:0.03}).addTo(map);
  });
}
L.polygon(D.circle.map(function(p){return [p[1],p[0]];}), {color:'#b45309', dashArray:'6 6', fillOpacity:0.08}).addTo(map);
L.circleMarker(D.center, {radius:7, color:'#0e7490'}).bindPopup('موقع المرشح').addTo(map);
D.markers.forEach(function(m){
  L.circleMarker([m.lat,m.lon], {radius:5, color:'#15803d'})
   .bindPopup((m.brand||'') + '<br>' + (m.name||'') + '<br>' + (m.source||'')).addTo(map);
});
</script>
</body>
</html>
''';
  }
}
