// 프로필 숫자 타일에서 열리는 목록 화면을 모든 카테고리 × 사용자 × 화면 크기 × 글자 크기로 그려서
// 레이아웃 오류가 없는지 확인한다.
//
//   flutter test test/list_overflow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/screens/category_list_screen.dart';

import 'fixtures.dart';

void main() {
  final errors = <String>[];

  setUpAll(setUpTestWorld);

  setUp(() => collectLayoutErrors(errors));

  for (final category in ListCategory.values) {
    for (final uid in const ['me', 'f1', 'f3']) {
      for (final size in sizes) {
        for (final scale in scales) {
          testWidgets('${category.name} $uid ${size.width.toInt()}w x$scale', (tester) async {
            addTearDown(tester.view.reset);
            await pumpScreen(tester, CategoryListScreen(uid: uid, category: category), size, scale);
            await scrollThrough(tester);
            expect(errors, isEmpty, reason: errors.toSet().join('\n---\n'));
          });
        }
      }
    }
  }
}
