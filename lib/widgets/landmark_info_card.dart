import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class LandmarkInfoCard extends StatelessWidget {
  final String? overview;
  final String? historySignificance;
  final String? highlights;
  final Color themeColor;

  const LandmarkInfoCard({
    super.key,
    this.overview,
    this.historySignificance,
    this.highlights,
    this.themeColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final bool hasOverview = overview != null && overview!.trim().isNotEmpty;
    final bool hasHistory = historySignificance != null && historySignificance!.trim().isNotEmpty;
    final bool hasHighlights = highlights != null && highlights!.trim().isNotEmpty;

    if (!hasOverview && !hasHistory && !hasHighlights) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child:  Center(
          child: Text(
            tr('No detailed information available.'),
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasOverview) ...[
          _buildSection(
            context,
            icon: Icons.info_outline_rounded,
            title: 'Overview',
            content: overview!,
          ),
          if (hasHistory || hasHighlights) const Divider(height: 32, thickness: 0.5),
        ],
        if (hasHistory) ...[
          _buildSection(
            context,
            icon: Icons.history_edu_rounded,
            title: 'History & Significance',
            content: historySignificance!,
          ),
          if (hasHighlights) const Divider(height: 32, thickness: 0.5),
        ],
        if (hasHighlights)
          _buildSection(
            context,
            icon: Icons.star_outline_rounded,
            title: 'Highlights',
            content: highlights!,
          ),
      ],
    );
  }

  Widget _buildSection(BuildContext context,
      {required IconData icon, required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: themeColor),
            const SizedBox(width: 8),
            Text(
              tr(title),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            tr(content),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}