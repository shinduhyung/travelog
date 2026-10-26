// lib/widgets/new_tag.dart
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

/// 신규/갱신 기능 안내용 NEW 태그 (Travelog Social 카드와 같은 모양, 정적).
class NewTag extends StatelessWidget {
  const NewTag({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFFB300)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.6), blurRadius: 8, spreadRadius: 0.5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 9, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            tr('NEW'),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}
