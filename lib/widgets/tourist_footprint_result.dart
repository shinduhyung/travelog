import 'dart:math';
import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/services/tourist_local_model.dart';

class TouristFootprintResult extends StatelessWidget {
  final TouristLocalResult result;
  final bool showDetails;
  const TouristFootprintResult({
    super.key,
    required this.result,
    this.showDetails = true,
  });
  static const _local = Color(0xFF009688), _tourist = Color(0xFFEA580C);

  @override
  Widget build(BuildContext context) {
    final title = result.tourist >= 67
        ? 'A taste for the icons'
        : result.tourist <= 33
        ? 'Off the main trail'
        : 'Best of both worlds';
    final subtitle = result.tourist >= 67
        ? 'Big sights. Unforgettable cities.'
        : result.tourist <= 33
        ? 'You find the quieter corners.'
        : 'Famous sights and quieter stops.';
    final countries = result.covered
        .map((c) => c.country)
        .where((c) => c.length == 2)
        .toSet()
        .toList();
    final localLeads = result.local >= result.tourist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE5F6F1), Color(0xFFFFF2E7)],
            ),
          ),
          child: Column(
            children: [
              Text(
                tr(showDetails ? 'YOUR CITY FOOTPRINT' : 'YOUR TRAVEL STYLE'),
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 190,
                height: 190,
                child: CustomPaint(
                  painter: _FootprintRing(result.tourist / 100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        localLeads
                            ? Icons.explore_outlined
                            : Icons.camera_alt_outlined,
                        color: localLeads ? _local : _tourist,
                        size: 29,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(localLeads ? result.local : result.tourist).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tr(localLeads ? 'Local side' : 'Tourist side'),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr(title),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              if (showDetails)
                Text(
                  tr(subtitle),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: _legend('Local', result.local, _local)),
                  const SizedBox(width: 12),
                  Expanded(child: _legend('Tourist', result.tourist, _tourist)),
                ],
              ),
            ],
          ),
        ),
        if (showDetails) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              if (countries.isNotEmpty) ...[
                for (final code in countries.take(4))
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: _flag(code, 25),
                  ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  '${result.covered.length} ${tr(result.covered.length == 1 ? 'city' : 'cities')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            tr('Your cities'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final city in result.covered) _city(city),
        ],
      ],
    );
  }

  Widget _legend(String label, double value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          tr(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    ),
  );

  Widget _city(TouristCityVisit city) {
    final value = result.percentiles[city.name] ?? .5;
    final color = Color.lerp(_local, _tourist, value)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (city.country.length == 2) ...[
              _flag(city.country, 34),
              const SizedBox(width: 13),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(
                      value >= .67
                          ? 'Iconic stops'
                          : value <= .33
                          ? 'Quieter corners'
                          : 'A bit of both',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      color: color,
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flag(String code, double width) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox(
      width: width,
      height: width * .68,
      child: CountryFlag.fromCountryCode(code),
    ),
  );
}

class _FootprintRing extends CustomPainter {
  final double tourist;
  const _FootprintRing(this.tourist);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(11);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    paint.color = const Color(0xFF009688);
    canvas.drawArc(ring, -pi / 2, 2 * pi, false, paint);
    paint.color = const Color(0xFFEA580C);
    canvas.drawArc(ring, -pi / 2, 2 * pi * tourist.clamp(0, 1), false, paint);
  }

  @override
  bool shouldRepaint(_FootprintRing oldDelegate) =>
      oldDelegate.tourist != tourist;
}
