import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/providers/country_provider.dart';

class ContinentChecklist extends StatelessWidget {
  final Achievement achievement;
  final CountryProvider countryProvider;

  const ContinentChecklist({
    Key? key,
    required this.achievement,
    required this.countryProvider,
  }) : super(key: key);

  // OverviewStatsScreen과 동일한 이미지 자산 매핑
  String _getContinentAsset(String continent) {
    switch (continent) {
      case 'Asia':
        return 'assets/icons/asia.png';
      case 'Europe':
        return 'assets/icons/europe.png';
      case 'Africa':
        return 'assets/icons/africa.png';
      case 'North America':
        return 'assets/icons/n_america.png';
      case 'South America':
        return 'assets/icons/s_america.png';
      case 'Oceania':
        return 'assets/icons/oceania.png';
      default:
        return 'assets/icons/asia.png'; // 기본값
    }
  }

  // OverviewStatsScreen과 동일한 색상 매핑
  Color _getContinentColor(String continent) {
    switch (continent) {
      case 'North America':
        return Colors.blue.shade400;
      case 'South America':
        return Colors.green.shade400;
      case 'Africa':
        return Colors.brown.shade400;
      case 'Europe':
        return Colors.yellow.shade700;
      case 'Asia':
        return Colors.pink.shade300;
      case 'Oceania':
        return Colors.purple.shade400;
      default:
        return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // 6대주 목록
    final List<String> allContinents = [
      'Asia',
      'Europe',
      'Africa',
      'North America',
      'South America',
      'Oceania'
    ];

    // [수정됨] String 리스트인 visitedCountries를 Country 객체로 매핑하여 대륙 정보 추출
    final visitedContinents = countryProvider.visitedCountries
        .map((countryName) {
      try {
        return countryProvider.allCountries
            .firstWhere((c) => c.name == countryName)
            .continent;
      } catch (e) {
        return null;
      }
    })
        .where((c) => c != null)
        .toSet();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: allContinents.length,
      itemBuilder: (context, index) {
        final continent = allContinents[index];
        final isVisited = visitedContinents.contains(continent);
        final color = _getContinentColor(continent);
        final assetPath = _getContinentAsset(continent);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isVisited ? color.withOpacity(0.5) : Colors.grey.shade200,
                width: isVisited ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isVisited
                      ? color.withOpacity(0.15)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    assetPath,
                    width: 24,
                    height: 24,
                    color: isVisited ? color : Colors.grey.shade400,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.public,
                        color: isVisited ? color : Colors.grey.shade400,
                        size: 24,
                      );
                    },
                  ),
                ),
              ),
              title: Text(
                tr(continent),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isVisited ? Colors.black87 : Colors.grey[400],
                ),
              ),
              trailing: isVisited
                  ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              )
                  : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
            ),
          ),
        );
      },
    );
  }
}