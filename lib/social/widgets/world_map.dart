import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../theme.dart';

class MapDot {
  const MapDot(this.lat, this.lng, this.color, {this.radius = 3});

  final double lat;
  final double lng;
  final Color color;
  final double radius;
}

class MapArc {
  const MapArc(this.lat1, this.lng1, this.lat2, this.lng2, this.color, {this.width = 0.8});

  final double lat1, lng1, lat2, lng2;
  final Color color;
  final double width;
}

/// 정거원통도법 세계 지도. 남극은 잘라낸다.
/// 국경 데이터는 assets/data/geo.json (0.25도 단순화).
class WorldMap extends StatelessWidget {
  const WorldMap({
    super.key,
    this.colorFor,
    this.dots = const [],
    this.arcs = const [],
    this.onTapCountry,
    this.interactive = true,
    this.height,
  });

  final Color? Function(CountryMeta country)? colorFor;
  final List<MapDot> dots;
  final List<MapArc> arcs;
  final void Function(CountryMeta country)? onTapCountry;
  final bool interactive;
  final double? height;

  static const _north = 84.0;
  static const _south = -58.0;
  static const aspect = 360 / (_north - _south) * 0.86; // 위도 방향을 살짝 늘려 보기 좋게

  static Offset project(double lat, double lng) =>
      Offset((lng + 180) / 360, (_north - lat.clamp(_south, _north)) / (_north - _south));

  static Map<String, Path>? _paths;
  static Map<String, Offset>? _tinyCountries; // 폴리곤이 없는 작은 나라 -> 수도 위치

  static Map<String, Path> _buildPaths() {
    final geo = GeoData.I;
    final paths = <String, Path>{};
    for (final c in geo.countries.values) {
      if (c.polygons.isEmpty) continue;
      final path = Path();
      for (final ring in c.polygons) {
        for (var i = 0; i + 1 < ring.length; i += 2) {
          final p = project(ring[i + 1], ring[i]);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
      }
      paths[c.iso3] = path;
    }
    return paths;
  }

  static Map<String, Offset> _buildTiny() {
    final geo = GeoData.I;
    final capitals = <String, CityMeta>{};
    for (final city in geo.cities.values) {
      if (city.iso2 == null) continue;
      final cur = capitals[city.iso2!];
      if (cur == null || (city.isCapital && !cur.isCapital) ||
          (city.isCapital == cur.isCapital && city.population > cur.population)) {
        capitals[city.iso2!] = city;
      }
    }
    return {
      for (final c in geo.countries.values)
        if (c.polygons.isEmpty && c.iso2 != null && capitals[c.iso2] != null)
          c.iso3: project(capitals[c.iso2]!.lat, capitals[c.iso2]!.lng),
    };
  }

  static Map<String, Path> get paths => _paths ??= _buildPaths();
  static Map<String, Offset> get tinyCountries => _tinyCountries ??= _buildTiny();

  CountryMeta? _hit(Offset normalized, Size size) {
    final geo = GeoData.I;
    for (final e in paths.entries) {
      if (e.value.getBounds().contains(normalized) && e.value.contains(normalized)) {
        return geo.countries[e.key];
      }
    }
    // 작은 나라: 화면 기준 12px 안
    CountryMeta? best;
    var bestD = 12.0;
    for (final e in tinyCountries.entries) {
      final d = Offset((e.value.dx - normalized.dx) * size.width, (e.value.dy - normalized.dy) * size.height).distance;
      if (d < bestD) {
        bestD = d;
        best = geo.countries[e.key];
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final land = AppColors.land(context);
    final ocean = AppColors.ocean(context);
    final border = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1220) : Colors.white;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final h = height ?? width / aspect;
      final size = Size(width, h);
      Widget map = CustomPaint(
        size: size,
        painter: _MapPainter(
          colorFor: colorFor,
          land: land,
          ocean: ocean,
          border: border,
          dots: dots,
          arcs: arcs,
        ),
      );
      if (onTapCountry != null) {
        map = GestureDetector(
          onTapUp: (d) {
            final n = Offset(d.localPosition.dx / size.width, d.localPosition.dy / size.height);
            final c = _hit(n, size);
            if (c != null) onTapCountry!(c);
          },
          child: map,
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          height: h,
          child: interactive
              ? InteractiveViewer(maxScale: 8, minScale: 1, child: map)
              : map,
        ),
      );
    });
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.colorFor,
    required this.land,
    required this.ocean,
    required this.border,
    required this.dots,
    required this.arcs,
  });

  final Color? Function(CountryMeta country)? colorFor;
  final Color land;
  final Color ocean;
  final Color border;
  final List<MapDot> dots;
  final List<MapArc> arcs;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ocean);
    final geo = GeoData.I;

    canvas.save();
    canvas.scale(size.width, size.height);
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = border
      ..strokeWidth = 0.6 / size.width;
    for (final e in WorldMap.paths.entries) {
      final c = geo.countries[e.key]!;
      fill.color = colorFor?.call(c) ?? land;
      canvas.drawPath(e.value, fill);
      canvas.drawPath(e.value, stroke);
    }
    canvas.restore();

    // 폴리곤 없는 작은 나라는 색이 있을 때만 점으로
    if (colorFor != null) {
      for (final e in WorldMap.tinyCountries.entries) {
        final color = colorFor!(geo.countries[e.key]!);
        if (color == null) continue;
        final p = Offset(e.value.dx * size.width, e.value.dy * size.height);
        canvas.drawCircle(p, 3.2, Paint()..color = border);
        canvas.drawCircle(p, 2.4, Paint()..color = color);
      }
    }

    for (final a in arcs) {
      final p1 = WorldMap.project(a.lat1, a.lng1);
      final p2 = WorldMap.project(a.lat2, a.lng2);
      final s = Offset(p1.dx * size.width, p1.dy * size.height);
      final t = Offset(p2.dx * size.width, p2.dy * size.height);
      final mid = (s + t) / 2;
      final dist = (t - s).distance;
      final normal = dist == 0 ? Offset.zero : Offset(-(t - s).dy, (t - s).dx) / dist;
      final ctrl = mid - normal * math.min(dist * 0.25, 60);
      final path = Path()
        ..moveTo(s.dx, s.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, t.dx, t.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = a.width
          ..strokeCap = StrokeCap.round
          ..color = a.color.withValues(alpha: a.color.a * 0.8),
      );
    }

    for (final d in dots) {
      final p = WorldMap.project(d.lat, d.lng);
      final o = Offset(p.dx * size.width, p.dy * size.height);
      canvas.drawCircle(o, d.radius + 1, Paint()..color = border.withValues(alpha: 0.9));
      canvas.drawCircle(o, d.radius, Paint()..color = d.color);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.colorFor != colorFor || old.dots != dots || old.arcs != arcs || old.land != land;
}

/// 지도 아래 범례
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (color, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
              ),
            ],
          ),
      ],
    );
  }
}

/// 지도 경로를 미리 만들어 둔다 (첫 지도 열 때 버벅임 방지)
void warmUpWorldMap() {
  WorldMap.paths;
  WorldMap.tinyCountries;
}
