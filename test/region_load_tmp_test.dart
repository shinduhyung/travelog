import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/admin_region_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('regions load', () async {
    for (final iso in ['KR', 'US', 'JP', 'FR']) {
      final r = await AdminRegionRepository.regionsFor(iso);
      // ignore: avoid_print
      print('$iso: ${r.length}');
      expect(r, isNotEmpty);
    }
  });
}
