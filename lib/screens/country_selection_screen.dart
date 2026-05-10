// lib/screens/country_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visit_details_model.dart'; // GroupBy가 여기 있거나 map screen에 있을 수 있음
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart'; // GroupBy enum 위치 확인 필요
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:jidoapp/services/ad_service.dart';

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

  // ✨ 민트 테마 컬러 정의
  final Color _mintPrimary = const Color(0xFF26A69A); // 메인 민트 (Teal 400)
  final Color _mintLight = const Color(0xFFE0F2F1);   // 연한 배경용 민트 (Teal 50)
  final Color _mintDark = const Color(0xFF00796B);    // 텍스트/강조용 진한 민트 (Teal 700)

  @override
  void initState() {
    super.initState();
    if (widget.isOnboarding) AdService.instance.setOnboardingActive();
    _tempSelectedCountries = Provider.of<CountryProvider>(context, listen: false).visitedCountries.toSet();
    _buildDisplayList();
  }

  @override
  void dispose() {
    if (widget.isOnboarding) AdService.instance.clearOnboardingActive();
    super.dispose();
  }

  void _buildDisplayList() {
    final Map<String, List<Country>> groupedCountries = {};

    final relevantCountries = _searchQuery.isEmpty
        ? widget.allCountries
        : widget.allCountries.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    for (var country in relevantCountries) {
      final key = (widget.groupBy == GroupBy.continent ? country.continent : country.subregion) ?? 'Unclassified';
      groupedCountries.putIfAbsent(key, () => []).add(country);
    }

    groupedCountries.forEach((key, value) => value.sort((a, b) => a.name.compareTo(b.name)));
    final sortedGroupKeys = groupedCountries.keys.toList()..sort();

    _displayList = [];
    for (var key in sortedGroupKeys) {
      final countriesInGroup = groupedCountries[key]!;
      final visitedCount = countriesInGroup.where((c) => _tempSelectedCountries.contains(c.name)).length;
      final totalCount = countriesInGroup.length;
      final percent = totalCount > 0 ? (visitedCount / totalCount * 100).round() : 0;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Confirm Removal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
            content: Text(
                'Are you sure you want to remove all $recordCount visit records for ${country.name}?',
                style: GoogleFonts.poppins(color: Colors.black54)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Yes, Remove', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // 아주 연한 쿨그레이 배경 (민트와 잘 어울림)
      appBar: AppBar(
        title: Text(
          'Select Countries',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
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
                hintText: 'Search Country...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
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
                    padding: const EdgeInsets.only(top: 24.0, bottom: 12.0, left: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.title,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _mintDark)), // 진한 민트색 텍스트
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _mintLight, // 연한 민트 배경
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(item.stats,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _mintPrimary)),
                        ),
                      ],
                    ),
                  );
                }

                // 국가 카드
                if (item is Country) {
                  final country = item;
                  final isSelected = _tempSelectedCountries.contains(country.name);
                  final isWishlisted = context.watch<CountryProvider>().wishlistedCountries.contains(country.name);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: InkWell(
                      onTap: () => _handleCountryToggle(country, !isSelected),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          // 선택 시: 연한 민트 배경 + 민트 테두리
                          color: isSelected ? _mintLight.withOpacity(0.5) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? _mintPrimary : Colors.transparent,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            // 체크박스 (민트 원형)
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? _mintPrimary : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? _mintPrimary : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),

                            // 이름
                            Expanded(
                              child: Text(
                                country.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? _mintDark : Colors.black87,
                                ),
                              ),
                            ),

                            // 아이콘 버튼
                            IconButton(
                              icon: const Icon(Icons.book, size: 20),
                              color: Colors.grey.shade400,
                              tooltip: "Details",
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, size: 20),
                              color: isWishlisted ? Colors.red.shade400 : Colors.grey.shade400,
                              tooltip: "Wishlist",
                              onPressed: () {
                                Provider.of<CountryProvider>(context, listen: false).toggleCountryWishlistStatus(country.name);
                              },
                            ),
                          ],
                        ),
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
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final provider = Provider.of<CountryProvider>(context, listen: false);
                        final originalVisited = provider.visitedCountries;

                        final countriesToAdd = _tempSelectedCountries.difference(originalVisited);
                        final countriesToRemove = originalVisited.difference(_tempSelectedCountries);

                        for (final countryName in countriesToAdd) {
                          provider.setVisitedStatus(countryName, true);
                        }

                        for (final countryName in countriesToRemove) {
                          provider.setVisitedStatus(countryName, false);
                        }

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mintPrimary, // 민트 버튼
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Apply Changes',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
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