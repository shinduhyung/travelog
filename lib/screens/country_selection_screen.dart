// lib/screens/country_selection_screen.dart

import 'package:jidoapp/services/country_region_access.dart';
import 'package:jidoapp/widgets/country_region_access_gate.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/widgets/country_region_dropdown.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart'; // GroupBy enum 위치 확인 필요
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

// isoA2 코드 → 국기 이모지 변환
String _countryFlag(String isoA2) {
  if (isoA2.length != 2) return '';
  const base = 0x1F1E6 - 0x41;
  final chars = isoA2.toUpperCase().codeUnits;
  return String.fromCharCode(base + chars[0]) +
      String.fromCharCode(base + chars[1]);
}

// 헤더 아이템 클래스
class HeaderItem {
  final String title;
  final String stats;
  HeaderItem(this.title, this.stats);
}

class CountrySelectionScreen extends StatefulWidget {
  final List<Country> allCountries;
  final ScrollController scrollController;
  final GroupBy groupBy;
  final bool isOnboarding;

  const CountrySelectionScreen({
    super.key,
    required this.allCountries,
    required this.scrollController,
    required this.groupBy,
    this.isOnboarding = false,
  });

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  String _searchQuery = '';
  late Set<String> _tempSelectedCountries;
  late List<dynamic> _displayList;
  final Set<String> _expandedCountries = {};
  final Map<String, Map<String, ({AdminRegion region, bool visited})>>
  _regionChanges = {};

  void _toggleRegionDraft(Country country, AdminRegion region, bool visited) {
    setState(() {
      _regionChanges.putIfAbsent(country.isoA3, () => {})[region.stableKey] = (
        region: region,
        visited: visited,
      );
    });
  }

  // ✨ 민트 테마 컬러 정의
  final Color _mintPrimary = const Color(0xFF26A69A); // 메인 민트 (Teal 400)
  final Color _mintLight = const Color(0xFFE0F2F1); // 연한 배경용 민트 (Teal 50)
  final Color _mintDark = const Color(0xFF00796B); // 텍스트/강조용 진한 민트 (Teal 700)

  @override
  void initState() {
    super.initState();
    AdService.instance.setCountrySelectionActive();
    if (widget.isOnboarding) AdService.instance.setOnboardingActive();
    _tempSelectedCountries = Provider.of<CountryProvider>(
      context,
      listen: false,
    ).visitedCountries.toSet();
    _buildDisplayList();
  }

  @override
  void dispose() {
    if (widget.isOnboarding) AdService.instance.clearOnboardingActive();
    AdService.instance.clearCountrySelectionActive();
    super.dispose();
  }

  void _buildDisplayList() {
    final Map<String, List<Country>> groupedCountries = {};

    final relevantCountries = _searchQuery.isEmpty
        ? widget.allCountries
        : widget.allCountries
              .where(
                (c) =>
                    AppLocale.instance.matchesCountry(c.name, _searchQuery),
              )
              .toList();

    for (var country in relevantCountries) {
      final key =
          (widget.groupBy == GroupBy.continent
              ? country.continent
              : country.subregion) ??
          'Unclassified';
      groupedCountries.putIfAbsent(key, () => []).add(country);
    }

    groupedCountries.forEach(
      (key, value) => value.sort((a, b) => a.name.compareTo(b.name)),
    );
    final sortedGroupKeys = groupedCountries.keys.toList()..sort();

    _displayList = [];
    for (var key in sortedGroupKeys) {
      final countriesInGroup = groupedCountries[key]!;
      final visitedCount = countriesInGroup
          .where((c) => _tempSelectedCountries.contains(c.name))
          .length;
      final totalCount = countriesInGroup.length;
      final percent = totalCount > 0
          ? (visitedCount / totalCount * 100).round()
          : 0;
      final stats = '$visitedCount/$totalCount ($percent%)';

      _displayList.add(HeaderItem(key, stats));
      _displayList.addAll(countriesInGroup);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _buildDisplayList();
    });
  }

  Future<void> _handleCountryToggle(Country country, bool isSelected) async {
    final provider = Provider.of<CountryProvider>(context, listen: false);
    final visitDetails = provider.visitDetails[country.name];

    if (!isSelected) {
      if (visitDetails != null && visitDetails.visitDateRanges.isNotEmpty) {
        final int recordCount = visitDetails.visitDateRanges.length;

        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              tr('Confirm Removal'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            content: Text(
              tr('Are you sure you want to remove all $recordCount visit records for ${country.name}?'),
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  tr('Cancel'),
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  tr('Yes, Remove'),
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirm == true) {
          provider.clearVisitHistory(country.name);
          setState(() {
            _tempSelectedCountries.remove(country.name);
            _buildDisplayList();
          });
          return;
        } else {
          return;
        }
      } else if (visitDetails != null && visitDetails.visitDateRanges.isEmpty) {
        provider.clearVisitHistory(country.name);
        setState(() {
          _tempSelectedCountries.remove(country.name);
          _buildDisplayList();
        });
        return;
      }
    }

    setState(() {
      if (isSelected) {
        _tempSelectedCountries.add(country.name);
      } else {
        _tempSelectedCountries.remove(country.name);
      }
      _buildDisplayList();
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // 아주 연한 쿨그레이 배경 (민트와 잘 어울림)
      appBar: AppBar(
        title: Text(
          tr('Select Countries'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: _mintPrimary, // 민트색 앱바
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. 검색창 (부드러운 스타일)
          Container(
            color: _mintPrimary, // 앱바와 연결되는 민트 배경
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), // 하단 여백 넉넉히
            child: TextField(
              onChanged: _onSearchChanged,
              style: GoogleFonts.poppins(),
              cursorColor: _mintDark,
              decoration: InputDecoration(
                hintText: tr('Search Country...'),
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30), // 완전 둥근 캡슐형
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: _mintLight, width: 2),
                ),
              ),
            ),
          ),

          // 2. 리스트 영역
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _displayList.length,
              itemBuilder: (context, index) {
                final item = _displayList[index];

                // 헤더
                if (item is HeaderItem) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      top: 24.0,
                      bottom: 12.0,
                      left: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _mintDark,
                          ),
                        ), // 진한 민트색 텍스트
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _mintLight, // 연한 민트 배경
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tr(item.stats),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _mintPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Country selection remains separate from regional selection.
                if (item is Country) {
                  final country = item;
                  final isSelected = _tempSelectedCountries.contains(
                    country.name,
                  );
                  final expanded = _expandedCountries.contains(country.isoA3);
                  return Padding(
                    key: ValueKey(country.isoA3),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _mintLight.withValues(alpha: 0.5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? _mintPrimary : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () =>
                                _handleCountryToggle(country, !isSelected),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _mintPrimary
                                          : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? _mintPrimary
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  Text(
                                    tr(_countryFlag(country.isoA2)),
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tr(country.name),
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? _mintDark
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.book, size: 20),
                                    color: Colors.grey.shade400,
                                    tooltip: tr('Details'),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CountryDetailScreen(
                                          country: country,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: ValueKey('regions-${country.isoA3}'),
                                    icon: Icon(
                                      expanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                    ),
                                    color: expanded
                                        ? _mintPrimary
                                        : Colors.grey.shade400,
                                    tooltip: tr(expanded
                                        ? 'Hide regions'
                                        : 'Show regions'),
                                    onPressed: () {
                                      if (!CountryRegionAccess.isUnlocked(
                                        country.isoA2,
                                      )) {
                                        showCountryRegionsPremiumDialog(
                                          context,
                                        );
                                        return;
                                      }
                                      setState(() {
                                        if (expanded) {
                                          _expandedCountries.remove(
                                            country.isoA3,
                                          );
                                        } else {
                                          _expandedCountries.add(country.isoA3);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (expanded)
                            Consumer<SubregionProvider>(
                              builder: (context, visits, _) =>
                                  CountryRegionDropdown(
                                    key: ValueKey(
                                      'region-list-${country.isoA3}',
                                    ),
                                    countryIsoA2: country.isoA2,
                                    color: _mintPrimary,
                                    isVisited: (region) =>
                                        _regionChanges[country.isoA3]?[region
                                                .stableKey]
                                            ?.visited ??
                                        visits.isRegionVisited(
                                          country.isoA3,
                                          region,
                                        ),
                                    onChanged: visits.isLoading
                                        ? null
                                        : (region, visited) =>
                                              _toggleRegionDraft(
                                                country,
                                                region,
                                                visited,
                                              ),
                                  ),
                            ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // 3. 하단 버튼 영역
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: Text(
                        tr('Cancel'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final provider = Provider.of<CountryProvider>(
                          context,
                          listen: false,
                        );
                        final originalVisited = provider.visitedCountries;

                        final countriesToAdd = _tempSelectedCountries
                            .difference(originalVisited);
                        final countriesToRemove = originalVisited.difference(
                          _tempSelectedCountries,
                        );

                        for (final countryName in countriesToAdd) {
                          provider.setVisitedStatus(countryName, true);
                        }

                        for (final countryName in countriesToRemove) {
                          provider.setVisitedStatus(countryName, false);
                        }

                        context.read<SubregionProvider>().setRegionVisits(
                          _regionChanges.map(
                            (iso, changes) => MapEntry(iso, {
                              for (final change in changes.values)
                                change.region: change.visited,
                            }),
                          ),
                        );

                        // 리뷰 요청 조건:
                        // 1) 국가를 추가했을 때만
                        // 2) 추가 후 총 방문 국가 10개 이상
                        // 3) 기기당 딱 1회
                        if (countriesToAdd.isNotEmpty) {
                          final newTotal = _tempSelectedCountries.length;
                          if (newTotal >= 10) {
                            final prefs = await SharedPreferences.getInstance();
                            final alreadyRequested =
                                prefs.getBool('review_requested') ?? false;
                            if (!alreadyRequested) {
                              final inAppReview = InAppReview.instance;
                              if (await inAppReview.isAvailable()) {
                                await inAppReview.requestReview();
                                await prefs.setBool('review_requested', true);
                              }
                            }
                          }
                        }

                        // 프로모션 팝업 조건:
                        // 1) 국가를 추가했을 때만
                        // 2) 추가 후 총 방문 국가 5개 이상
                        // 3) 기기당 딱 1회
                        // 4) 프리미엄 유저 제외
                        if (countriesToAdd.isNotEmpty && context.mounted) {
                          final newTotal = _tempSelectedCountries.length;
                          if (newTotal >= 5) {
                            final prefs = await SharedPreferences.getInstance();
                            final alreadyShown =
                                prefs.getBool('promo_popup_shown') ?? false;
                            final isPremium =
                                SubscriptionService.instance.isPremium;
                            if (!alreadyShown && !isPremium) {
                              await prefs.setBool('promo_popup_shown', true);
                              if (context.mounted) {
                                await showDialog(
                                  context: context,
                                  builder: (_) => const _PromoDialog(),
                                );
                              }
                            }
                          }
                        }

                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mintPrimary, // 민트 버튼
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr('Apply Changes'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoDialog extends StatelessWidget {
  const _PromoDialog();

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 닫기 버튼
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Color(0xFF999999),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 프로모션 컨테이너 (subscription_sheet 동일 스타일)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB347).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(tr('🎁'), style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text:  TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF444444),
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: tr('Try 30 days for FREE!\n'),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          TextSpan(text: tr('Post your map on ')),
                          TextSpan(
                            text: tr('Instagram'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE1306C),
                            ),
                          ),
                          TextSpan(text: tr(' or ')),
                          TextSpan(
                            text: tr('Facebook'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1877F2),
                            ),
                          ),
                          TextSpan(text: tr(' and send a screenshot to ')),
                          TextSpan(
                            text: tr('leeahn137@gmail.com'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3DDAD7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 닫기 버튼
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child:  Text(
                  tr('Maybe later'),
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
