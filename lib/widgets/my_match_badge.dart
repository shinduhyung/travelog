// lib/widgets/my_match_badge.dart
//
// "My match" pill for detail modals. Uses the same score as the Discover
// AI Recommendation list (DiscoverRecommender); renders nothing when the place
// has no reviewed scores or the user has too few ratings.

import 'package:flutter/material.dart';
import 'package:jidoapp/widgets/native_back_scope.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/services/discover_recommendation_runtime.dart';
import 'package:jidoapp/services/discover_user_profile.dart';

const placeDetailBadgeMinHeight = 28.0;

class MyMatchBadge extends StatefulWidget {
  final String kind; // country | city | landmark
  final String name;
  final String? countryIsoA2; // city / country
  final String? countryIsoA3; // landmark (first country)
  final double? latitude, longitude;

  /// Pill colors: [onDark] for headers with a dark background.
  final bool onDark;
  final EdgeInsetsGeometry padding;

  const MyMatchBadge._({
    super.key,
    required this.kind,
    required this.name,
    this.countryIsoA2,
    this.countryIsoA3,
    this.latitude,
    this.longitude,
    this.onDark = false,
    this.padding = EdgeInsets.zero,
  });

  factory MyMatchBadge.country({
    Key? key,
    required String name,
    required String isoA2,
    bool onDark = false,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => MyMatchBadge._(
    key: key,
    kind: 'country',
    name: name,
    countryIsoA2: isoA2,
    onDark: onDark,
    padding: padding,
  );

  factory MyMatchBadge.city({
    Key? key,
    required City city,
    bool onDark = false,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => MyMatchBadge._(
    key: key,
    kind: 'city',
    name: city.name,
    countryIsoA2: city.countryIsoA2,
    latitude: city.latitude,
    longitude: city.longitude,
    onDark: onDark,
    padding: padding,
  );

  factory MyMatchBadge.landmark({
    Key? key,
    required Landmark landmark,
    bool onDark = false,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => MyMatchBadge._(
    key: key,
    kind: 'landmark',
    name: landmark.name,
    countryIsoA3: landmark.countriesIsoA3.isEmpty
        ? null
        : landmark.countriesIsoA3.first,
    latitude: landmark.latitude,
    longitude: landmark.longitude,
    onDark: onDark,
    padding: padding,
  );

  @override
  State<MyMatchBadge> createState() => _MyMatchBadgeState();
}

class _MyMatchBadgeState extends State<MyMatchBadge> {
  double? _score;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watching the providers re-runs this when ratings or visits change.
    context.watch<PersonalityProvider>();
    final countries = context.watch<CountryProvider>();
    final cities = context.watch<CityProvider>();
    final landmarks = context.watch<LandmarksProvider>();
    _refresh(countries, cities, landmarks);
  }

  Future<void> _refresh(
    CountryProvider countries,
    CityProvider cities,
    LandmarksProvider landmarks,
  ) async {
    final generation = ++_generation;
    if (countries.isLoading || cities.isLoading || landmarks.isLoading) return;
    final answers = context.read<PersonalityProvider>().responses;
    double? score;
    try {
      final model = await DiscoverRecommendationRuntime.load();
      final w = widget;
      final a2 =
          w.countryIsoA2 ??
          countries.allCountries
              .firstWhereOrNull((c) => c.isoA3 == w.countryIsoA3)
              ?.isoA2;
      final place = model.resolve(
        w.kind,
        w.name,
        country: a2,
        latitude: w.latitude,
        longitude: w.longitude,
      );
      if (place != null) {
        score = DiscoverUserProfile.capture(
          model,
          countries,
          cities,
          landmarks,
        ).scoreFor(model, place, answers);
      }
    } catch (_) {
      score = null;
    }
    if (!mounted || generation != _generation || score == _score) return;
    setState(() => _score = score);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final score = _score;
    if (score == null) return const SizedBox.shrink();
    return MatchScoreChip(
      percent: (score * 100).round(),
      placeName: widget.name,
      fontSize: widget.kind == 'city' ? 11 : 12,
      horizontalPadding: widget.kind == 'country' ? 9 : 10,
      cornerRadius: widget.kind == 'country' ? 12 : 20,
      onDark: widget.onDark,
      padding: widget.padding,
    );
  }
}

/// Shared compact presentation and explanation for every place detail modal.
class MatchScoreChip extends StatelessWidget {
  final int percent;
  final double fontSize;
  final double horizontalPadding, cornerRadius;
  final bool onDark;
  final String? placeName;
  final EdgeInsetsGeometry padding;
  const MatchScoreChip({
    super.key,
    required this.percent,
    this.fontSize = 12,
    this.horizontalPadding = 10,
    this.cornerRadius = 20,
    this.placeName,
    this.onDark = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    const blue = Color(0xFF2563EB);
    final fg = onDark ? Colors.white : blue;
    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        label: ko
            ? '$percent% 여행 궁합, 설명 보기'
            : tr('$percent% travel match, show explanation'),
        child: Material(
          color: onDark
              ? Colors.white.withValues(alpha: .18)
              : blue.withValues(alpha: .08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
            side: BorderSide(color: fg.withValues(alpha: .3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              barrierColor: Colors.black.withValues(alpha: .36),
              builder: (_) => NativeBackScope(
                child: MatchExplanationSheet(
                  percent: percent,
                  placeName: placeName,
                ),
              ),
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: placeDetailBadgeMinHeight),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 13, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    '$percent',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uses the Discover palette while keeping the parent detail modal compact.
class MatchExplanationSheet extends StatelessWidget {
  final int percent;
  final String? placeName;
  const MatchExplanationSheet({
    super.key,
    required this.percent,
    this.placeName,
  });

  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    const ink = Color(0xFF173B46);
    const teal = Color(0xFF008F83);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4DEE2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ko ? '여행 궁합' : tr('TRAVEL MATCH'),
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.3,
                          color: teal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: ko ? '닫기' : tr('Close'),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEAF0F2),
                        minimumSize: const Size(32, 32),
                        maximumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            placeName == null
                                ? (ko ? '당신과의 궁합' : tr('Your travel match'))
                                : tr(placeName!),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 25,
                              height: 1.15,
                              letterSpacing: -.5,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          if (placeName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              ko ? '당신과의 여행 궁합' : tr('Your travel match'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6C8189),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: percent.clamp(0, 100) / 100,
                        ),
                        duration: Duration(
                          milliseconds: reduceMotion ? 0 : 700,
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                color: teal,
                                backgroundColor: const Color(0xFFE1ECEC),
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 31,
                                letterSpacing: -1,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(height: 1, color: const Color(0xFFE2EAED)),
                const SizedBox(height: 16),
                Text(
                  ko
                      ? '방문 기록과 평점을 바탕으로 AI가 추정한 이 장소와의 궁합이에요.'
                      : tr('An AI-estimated match, based on the places you’ve visited and rated.'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF60747D),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ko ? '계속 둘러보기' : tr('Keep exploring'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 17),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
