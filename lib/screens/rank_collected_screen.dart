// lib/screens/rank_collected_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class RankCollectedScreen extends StatelessWidget {
  final String rankName;

  const RankCollectedScreen({
    super.key,
    required this.rankName,
  });

  // MyTripsTabScreen의 기준과 동일한 색상 테마 적용
  Color _getLevelColor(String level) {
    switch (level) {
      case 'Rookie': return const Color(0xFF8B4513);
      case 'Explorer': return const Color(0xFFFFA726);
      case 'Nomad': return const Color(0xFF66BB6A);
      case 'Adventurer': return const Color(0xFF26A69A);
      case 'Globetrotter': return const Color(0xFF5C6BC0);
      case 'Worldmaster': return const Color(0xFFAB47BC);
      case 'Legend': return const Color(0xFFEC407A);
      default: return const Color(0xFF8B4513);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final Color levelColor = _getLevelColor(rankName);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(left: 20, top: 60, right: 20, bottom: 20),
            margin: const EdgeInsets.only(top: 45),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black26, offset: Offset(0, 10), blurRadius: 10),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  tr("RANK PROMOTED!"),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: levelColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                 Text(
                  tr("Your exploration level has increased."),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                Text(
                  tr(rankName),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: levelColor,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: levelColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child:  Text(
                      tr("Awesome!"),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // MyTripsTabScreen의 아이콘 경로 기준 (badge_levels/명칭.png)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: levelColor.withOpacity(0.2), width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ],
            ),
            child: CircleAvatar(
              backgroundColor: levelColor.withOpacity(0.1),
              radius: 45,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/badge_levels/${rankName.toLowerCase()}.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}