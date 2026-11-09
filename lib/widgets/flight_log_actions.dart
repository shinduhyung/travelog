import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class FlightLogActions extends StatelessWidget {
  final VoidCallback onCancel, onSave;
  final VoidCallback? onDelete;
  final bool busy;
  const FlightLogActions({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.onDelete,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = 40 + 10 * (MediaQuery.textScalerOf(context).scale(13) / 13);
    final outline = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      minimumSize: Size.zero,
      foregroundColor: Colors.deepPurple.shade700,
      side: BorderSide(color: Colors.deepPurple.shade200),
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
    );
    Widget label(String text) =>
        Text(tr(text), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onDelete != null) ...[
              Expanded(
                child: OutlinedButton(
                  style: outline.copyWith(
                    foregroundColor: WidgetStatePropertyAll(
                      Colors.red.shade700,
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                  onPressed: busy ? null : onDelete,
                  child: label('Delete'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton(
                style: outline,
                onPressed: busy ? null : onCancel,
                child: label('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                onPressed: busy ? null : onSave,
                child: label(onDelete != null ? 'Save Changes' : 'Save Log'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
