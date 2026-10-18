import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class LikertScaleWidget extends StatelessWidget {
  final int? selectedValue; // 1 to 7
  final ValueChanged<int> onChanged;

  const LikertScaleWidget({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr("Agree"),
                style: TextStyle(
                    color: const Color(0xFF009688), // Greenish
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(tr("Disagree"),
                style: TextStyle(
                    color: const Color(0xFF7B1FA2), // Purpleish
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(7, (index) {
            final int value = index + 1;
            final bool isSelected = selectedValue == value;

            // Sizes mimicking the screenshot: Large on ends, Small in middle
            // Index: 0, 1, 2, 3, 4, 5, 6
            // Value: 1, 2, 3, 4, 5, 6, 7
            // Size logic:
            // 1,7 -> Large (48)
            // 2,6 -> Medium (40)
            // 3,5 -> Small (32)
            // 4   -> Smallest (24)
            double size;
            if (value == 1 || value == 7) size = 48;
            else if (value == 2 || value == 6) size = 40;
            else if (value == 3 || value == 5) size = 32;
            else size = 24;

            // Color logic: Left side Green, Right side Purple, Middle Gray
            Color activeColor;
            if (value <= 3) {
              activeColor = const Color(0xFF009688); // Green
            } else if (value >= 5) {
              activeColor = const Color(0xFF7B1FA2); // Purple
            } else {
              activeColor = Colors.grey;
            }

            return GestureDetector(
              onTap: () => onChanged(value),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? activeColor : activeColor.withOpacity(0.5),
                    width: isSelected ? 3.0 : 2.0,
                  ),
                  color: isSelected ? activeColor : Colors.transparent,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}