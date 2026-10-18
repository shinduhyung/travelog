import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class CountryRegionsUpdateDialog extends StatelessWidget {
  const CountryRegionsUpdateDialog({super.key});

  Widget _feature(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF26A69A), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(title),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tr(body),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title:  Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('NEW · REGIONS'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF26A69A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              tr('Explore countries, region by region'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _feature(
                  Icons.workspace_premium_outlined,
                  '30 countries free',
                  'Regions in the original 30 countries remain free. Premium unlocks regions in additional countries.',
                ),
                _feature(
                  Icons.swap_horiz_rounded,
                  'Switch your map',
                  'Tap the switch beside Share in Countries to change from country colors to visited-region colors. The full world map has the same switch beside Settings. Opening + keeps your current map mode.',
                ),
                _feature(
                  Icons.checklist_rounded,
                  'Choose individual regions',
                  'In Select Countries, expand a country to search and check its states, provinces or other regions. Tap Apply Changes to save; Cancel discards your region edits.',
                ),
                _feature(
                  Icons.menu_book_rounded,
                  'Discover regions in CountryDex',
                  'Open a country in CountryDex to see its region map and visited / total progress. Tap a region to mark it visited, or use the full-screen map and searchable list.',
                ),
                _feature(
                  Icons.bookmark_added_outlined,
                  'Your country records stay intact',
                  'Country visits and region visits are tracked separately. Visiting a country does not automatically mark all its regions. Some areas do not yet have subdivision boundaries.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF26A69A),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child:  Text(tr('Got it')),
            ),
          ),
        ],
      ),
    );
  }
}
