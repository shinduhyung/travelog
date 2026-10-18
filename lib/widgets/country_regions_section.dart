import 'package:jidoapp/services/country_region_access.dart';
import 'package:jidoapp/services/subscription_service.dart';
// lib/widgets/country_regions_section.dart
//
// CountryDetailScreen 정보 카드 안에 들어가는 "Regions" 섹션.
// 주/도/현 단위 지도를 보여주고, 탭해서 방문 여부를 토글한다.
// - 카드 안 지도: 스크롤과 충돌하지 않도록 드래그/줌은 막고 탭만 허용
// - 전체화면 버튼: 팬/줌 가능한 지도 (작은 지역 탭용)
// - 리스트 버튼: 검색 + 스위치 리스트 바텀시트
// 방문 상태는 SubregionProvider(로컬 + Firestore 'visited_subregions')에 저장.

import 'package:jidoapp/widgets/country_region_access_gate.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:jidoapp/utils/point_in_polygon.dart';

const Color _kMapBackground = Color(0xFFF1F5F9);
const Color _kUnvisitedFill = Color(0xFFDDE3EA);

void _toggleRegion(
  BuildContext context,
  SubregionProvider provider,
  String countryIsoA3,
  AdminRegion region,
) {
  if (region.isWholeArea) return;
  final nowVisited = !provider.isRegionVisited(countryIsoA3, region);
  provider.setRegionVisited(countryIsoA3, region, nowVisited);
  HapticFeedback.selectionClick();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          tr(nowVisited
              ? '${region.name} marked as visited'
              : '${region.name} unmarked'),
        ),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

AdminRegion? _findRegionAt(LatLng point, List<AdminRegion> regions) {
  for (final region in regions) {
    if (isPointInRegion(point, region.polygonsData)) return region;
  }
  return null;
}

class CountryRegionsSection extends StatefulWidget {
  final Country country;
  final Color themeColor;
  final Widget header;

  const CountryRegionsSection({
    super.key,
    required this.country,
    required this.themeColor,
    required this.header,
  });

  @override
  State<CountryRegionsSection> createState() => _CountryRegionsSectionState();
}

class _CountryRegionsSectionState extends State<CountryRegionsSection> {
  late Future<List<AdminRegion>> _regionsFuture;

  @override
  void initState() {
    super.initState();
    _regionsFuture = AdminRegionRepository.regionsFor(widget.country.isoA2);
  }

  void _openFullScreen(List<AdminRegion> regions) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CountryRegionsMapScreen(
          country: widget.country,
          themeColor: widget.themeColor,
          regions: regions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return FutureBuilder<List<AdminRegion>>(
      future: _regionsFuture,
      builder: (context, snapshot) {
        final regions = snapshot.data ?? const <AdminRegion>[];
        // 실제 로딩 실패/빈 데이터인 경우에만 숨긴다.
        if (regions.isEmpty) return const SizedBox.shrink();

        // Whole-area outlines have no region feature to sell.
        if (!regions.every((region) => region.isWholeArea)) {
          return CountryRegionAccessGate(
            countryIsoA2: widget.country.isoA2,
            builder: (context) => _buildRegionContent(context, regions),
          );
        }
        return _buildRegionContent(context, regions);
      },
    );
  }

  Widget _buildRegionContent(BuildContext context, List<AdminRegion> regions) {
    final themeColor = widget.themeColor;
    final isoA3 = widget.country.isoA3;
    final bounds = AdminRegionRepository.fitBoundsFor(
      widget.country.isoA2,
      regions,
    );

    if (regions.every((region) => region.isWholeArea)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.header,
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 230,
              child: _RegionMap(
                regions: regions,
                countryIsoA3: isoA3,
                themeColor: themeColor,
                bounds: bounds,
                interactive: false,
              ),
            ),
          ),
          const SizedBox(height: 8),
           Text(
            tr('Subdivision boundaries are unavailable for this area. '
            'The map shows the whole area; region tracking is unavailable.'),
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.header,
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 230,
            decoration: BoxDecoration(
              color: _kMapBackground,
              border: Border.all(color: themeColor.withOpacity(0.15)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _RegionMap(
                    regions: regions,
                    countryIsoA3: isoA3,
                    themeColor: themeColor,
                    bounds: bounds,
                    interactive: false,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      _MapOverlayButton(
                        icon: Icons.open_in_full_rounded,
                        tooltip: tr('Full screen'),
                        color: themeColor,
                        onTap: () => _openFullScreen(regions),
                      ),
                      const SizedBox(height: 8),
                      _MapOverlayButton(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: tr('Region list'),
                        color: themeColor,
                        onTap: () => showRegionListSheet(
                          context,
                          country: widget.country,
                          themeColor: themeColor,
                          regions: regions,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RegionProgress(
          regions: regions,
          countryIsoA3: isoA3,
          themeColor: themeColor,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              tr('Tap a region on the map to mark it visited'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }
}

class _RegionMap extends StatelessWidget {
  final List<AdminRegion> regions;
  final String countryIsoA3;
  final Color themeColor;
  final LatLngBounds? bounds;
  final bool interactive;

  const _RegionMap({
    required this.regions,
    required this.countryIsoA3,
    required this.themeColor,
    required this.bounds,
    required this.interactive,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final provider = context.watch<SubregionProvider>();
    final visitedFill = themeColor.withOpacity(0.85);

    final polygons = <Polygon>[];
    for (final region in regions) {
      final fill = provider.isRegionVisited(countryIsoA3, region)
          ? visitedFill
          : _kUnvisitedFill;
      for (final piece in region.polygonsData) {
        if (piece.isEmpty || piece.first.length < 3) continue;
        polygons.add(
          Polygon(
            points: piece.first,
            holePointsList: piece.length > 1 ? piece.sublist(1) : null,
            color: fill,
            borderColor: Colors.white,
            borderStrokeWidth: interactive ? 1.0 : 0.6,
            isFilled: true,
          ),
        );
      }
    }

    return FlutterMap(
      options: MapOptions(
        backgroundColor: _kMapBackground,
        initialCameraFit: bounds != null
            ? CameraFit.bounds(
                bounds: bounds!,
                padding: EdgeInsets.all(interactive ? 32 : 16),
              )
            : null,
        minZoom: 1,
        maxZoom: 11,
        interactionOptions: InteractionOptions(
          // 카드 안에서는 드래그를 막아야 바깥 스크롤이 정상 동작한다.
          // 탭 콜백은 플래그와 무관하게 동작함.
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onTap: (_, point) {
          final tapped = _findRegionAt(point, regions);
          if (tapped == null) return;
          _toggleRegion(context, provider, countryIsoA3, tapped);
        },
      ),
      children: [PolygonLayer(polygons: polygons)],
    );
  }
}

class _MapOverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _MapOverlayButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tr(tooltip),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _RegionProgress extends StatelessWidget {
  final List<AdminRegion> regions;
  final String countryIsoA3;
  final Color themeColor;

  const _RegionProgress({
    required this.regions,
    required this.countryIsoA3,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final provider = context.watch<SubregionProvider>();
    final visited = provider.visitedRegionCount(countryIsoA3, regions);
    final total = regions.length;
    final ratio = total == 0 ? 0.0 : visited / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tr('$visited'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: themeColor,
                height: 1.0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 1),
              child: Text(
                tr('/ $total regions visited'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const Spacer(),
            Text(
              tr('${(ratio * 100).round()}%'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: themeColor.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
          ),
        ),
      ],
    );
  }
}

// ── 전체화면 지도 ───────────────────────────────────────────────────────────

class CountryRegionsMapScreen extends StatelessWidget {
  final Country country;
  final Color themeColor;
  final List<AdminRegion> regions;

  const CountryRegionsMapScreen({
    super.key,
    required this.country,
    required this.themeColor,
    required this.regions,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return AnimatedBuilder(
      animation: SubscriptionService.instance,
      builder: (context, _) {
        if (CountryRegionAccess.isUnlocked(country.isoA2))
          return _buildMapScreen(context);
        return Scaffold(
          appBar: AppBar(title: Text(tr('${country.name} · Regions'))),
          body: CountryRegionAccessGate(
            countryIsoA2: country.isoA2,
            builder: _buildMapScreen,
          ),
        );
      },
    );
  }

  Widget _buildMapScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          tr('${country.name} · Regions'),
          style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
        ),
        iconTheme: IconThemeData(color: themeColor),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeColor,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black87,
        tooltip: tr('Region list'),
        onPressed: () => showRegionListSheet(
          context,
          country: country,
          themeColor: themeColor,
          regions: regions,
        ),
        child: const Icon(Icons.format_list_bulleted_rounded),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _RegionMap(
              regions: regions,
              countryIsoA3: country.isoA3,
              themeColor: themeColor,
              bounds: AdminRegionRepository.fitBoundsFor(
                country.isoA2,
                regions,
              ),
              interactive: true,
            ),
          ),
          Positioned(
            left: 12,
            right: 84, // FAB 자리
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _RegionProgress(
                regions: regions,
                countryIsoA3: country.isoA3,
                themeColor: themeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 리스트 바텀시트 ─────────────────────────────────────────────────────────

void showRegionListSheet(
  BuildContext context, {
  required Country country,
  required Color themeColor,
  required List<AdminRegion> regions,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RegionListSheet(
      country: country,
      themeColor: themeColor,
      regions: regions,
    ),
  );
}

class _RegionListSheet extends StatefulWidget {
  final Country country;
  final Color themeColor;
  final List<AdminRegion> regions;

  const _RegionListSheet({
    required this.country,
    required this.themeColor,
    required this.regions,
  });

  @override
  State<_RegionListSheet> createState() => _RegionListSheetState();
}

class _RegionListSheetState extends State<_RegionListSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return CountryRegionAccessGate(
      countryIsoA2: widget.country.isoA2,
      builder: _buildList,
    );
  }

  Widget _buildList(BuildContext context) {
    final themeColor = widget.themeColor;
    final isoA3 = widget.country.isoA3;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final provider = context.watch<SubregionProvider>();
        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? widget.regions
            : widget.regions
                  .where((r) => r.name.toLowerCase().contains(q))
                  .toList();
        final visitedCount = provider.visitedRegionCount(isoA3, widget.regions);

        return Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Regions of ${widget.country.name}'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr('$visitedCount / ${widget.regions.length}'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: themeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: tr('Search regions'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        tr('No matching regions.'),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final region = filtered[index];
                        final visited = provider.isRegionVisited(isoA3, region);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      region.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (region.typeLabel.isNotEmpty)
                                      Text(
                                        tr(region.typeLabel),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: visited,
                                activeColor: themeColor,
                                onChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  provider.setRegionVisited(
                                    isoA3,
                                    region,
                                    value,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
