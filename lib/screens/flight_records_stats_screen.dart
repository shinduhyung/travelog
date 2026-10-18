// lib/screens/flight_records_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class FlightRecordsStatsScreen extends StatelessWidget {
  const FlightRecordsStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      appBar: AppBar(title:  Text(tr('Flight Records'))),
      body:  Center(
        child: Text(tr('Flight Records Screen')),
      ),
    );
  }
}