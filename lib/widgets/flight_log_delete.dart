import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';

Future<bool> deleteFlightLog(BuildContext context, FlightLog log) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('Delete flight?')),
      content: Text(
        '${log.departureIata ?? "—"} → ${log.arrivalIata ?? "—"}\n${log.flightNumber}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(tr('Cancel')),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(tr('Delete')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  context.read<AirlineProvider>().removeFlightLog(log);
  return true;
}
