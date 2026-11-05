import 'package:flutter/foundation.dart';
import 'travelog_poll_service.dart';

/// Local developer preview: no fabricated result or preview vote reaches Firebase.
class TravelogPollWeekPreview implements TravelogPollGateway {
  String? _choice;
  @override
  Future<Map<String, dynamic>> load() async {
    if (!kDebugMode) throw StateError('Poll preview is debug-only');
    final now = DateTime.now().toUtc();
    final monday = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return {
      'preview': true,
      'serverNow': now.toIso8601String(),
      'active': {
        'id': 'preview_east_asia',
        'question': 'Your favorite country in East Asia?',
        'questionKo': '가장 좋아하는 동아시아 나라는?',
        'releaseAt': monday.add(const Duration(days: 7)).toIso8601String(),
        'choice': _choice,
        'options': [
          {'code': 'CN', 'label': 'China', 'detail': 'Ancient wonders'},
          {'code': 'JP', 'label': 'Japan', 'detail': 'Tradition & city lights'},
          {
            'code': 'KR',
            'label': 'South Korea',
            'detail': 'Food & pop culture',
          },
          {
            'code': 'TW',
            'label': 'Taiwan',
            'detail': 'Night markets & mountains',
          },
          {'code': 'MN', 'label': 'Mongolia', 'detail': 'Steppe & open skies'},
        ],
      },
      'previous': [
        {
          'id': 'best_food_20261109',
          'preview': true,
          'released': true,
          'releaseAt': monday.toIso8601String(),
          'question': 'Which country has the best food?',
          'questionKo': '음식이 가장 맛있는 나라는?',
          'options': [
            {'code': 'IT', 'label': 'Italy', 'ko': '이탈리아'},
            {'code': 'JP', 'label': 'Japan', 'ko': '일본'},
            {'code': 'MX', 'label': 'Mexico', 'ko': '멕시코'},
            {'code': 'FR', 'label': 'France', 'ko': '프랑스'},
            {'code': 'TH', 'label': 'Thailand', 'ko': '태국'},
          ],
          'counts': {'IT': 32, 'JP': 22, 'MX': 17, 'FR': 17, 'TH': 12},
        },
      ],
    };
  }

  @override
  Future<void> vote(String pollId, String country) async {
    if (!kDebugMode ||
        pollId != 'preview_east_asia' ||
        !['CN', 'JP', 'KR', 'TW', 'MN'].contains(country)) {
      throw ArgumentError('Invalid preview vote');
    }
    _choice = country;
  }
}
