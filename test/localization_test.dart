import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocale.instance.load();
  });

  test(
    'device language is the default and an explicit choice persists',
    () async {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.localesTestValue = const [Locale('ko', 'KR')];
      addTearDown(dispatcher.clearLocalesTestValue);
      expect(AppLocale.instance.language, isNull);
      expect(AppLocale.instance.locale.languageCode, 'ko');
      await AppLocale.instance.setLanguage('en');
      expect(tr('Settings'), 'Settings');
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppLocale.preferenceKey,
        ),
        'en',
      );
      await AppLocale.instance.load();
      expect(AppLocale.instance.language, 'en');
      await AppLocale.instance.setLanguage(null);
      expect(tr('Settings'), '설정');
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          AppLocale.preferenceKey,
        ),
        isFalse,
      );
      dispatcher.localesTestValue = const [Locale('fr')];
      expect(AppLocale.instance.locale.languageCode, 'en');
    },
  );

  test(
    'all canonical countries have display names without changing source data',
    () async {
      await AppLocale.instance.setLanguage('ko');
      final countries =
          jsonDecode(await rootBundle.loadString('assets/countries_light.json'))
              as List;
      for (final country in countries) {
        final name = country['name'] as String;
        expect(AppLocale.instance.countryName(name), isNot(name), reason: name);
        expect(country['name'], name);
      }
      expect(tr('United States'), '미국');
    expect(tr('China'), '중국');
    expect(tr('Taiwan'), '대만');
    expect(tr('North Korea'), '북한');
    expect(AppLocale.instance.countryName('Turkiye'), '튀르키예');
      expect(tr('France • Paris'), '프랑스 • Paris');
      expect(tr('South Korea (KR)'), '대한민국 (KR)');
      expect(
        tr('Memo & Photos for Singapore', entities: ['Singapore']),
        'Singapore의 메모 및 사진',
      );
      expect(
        tr('Singapore (pop. 1M)', entities: ['Singapore']),
        'Singapore (인구: 1M)',
      );
      await AppLocale.instance.setLanguage('en');
      expect(AppLocale.instance.countryName('South Korea'), 'South Korea');
    },
  );

  test(
    'entity names stay intact, including country words inside names',
    () async {
      await AppLocale.instance.setLanguage('ko');
      for (final name in [
        'Air France',
        'China Airlines',
        'Korean Air',
        'New York',
        'Eiffel Tower',
        'Historic Centre of Rome',
        'Statue of Liberty',
      ]) {
        expect(tr(name), name);
      }
      expect(tr('12 days'), '12일');
    expect(tr('Economy'), '경제');
    expect(trSeatClass('Economy'), '이코노미 클래스');
      expect(tr('SETTINGS'), '설정');
      expect(tr('Business Lounge: 3 Visits'), '비즈니스 라운지: 3회 이용');
      expect(tr('1 hop left'), '1단계 남음');
      expect(tr('2 hops left'), '2단계 남음');
      expect(AppLocale.instance.matchesCountry('United States', '미국'), isTrue);
      expect(AppLocale.instance.matchesCountry('South Korea', 'korea'), isTrue);
      expect(AppLocale.instance.matchesCountry('South Korea', '한국'), isTrue);
      expect(AppLocale.instance.matchesCountry('Japan', '미국'), isFalse);
      expect(tr('Go ad-free for ₩12,000 / year'), '연 ₩12,000에 광고 없이 이용하기');
    },
  );

  test(
    'bundled quizzes and personality questions have Korean display copy',
    () async {
      await AppLocale.instance.setLanguage('ko');
      for (final asset in [
        'functions/quizzes.json',
        'functions/quizzes_hard.json',
      ]) {
        final quizzes = jsonDecode(await rootBundle.loadString(asset)) as List;
        for (final quiz in quizzes) {
          for (final field in ['question', 'explanation']) {
            final source = quiz[field] as String;
            expect(
              RegExp('[가-힣]').hasMatch(tr(source)),
              isTrue,
              reason: '$asset: $field: $source',
            );
          }
        }
      }
      final questions =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/personality_questions.json',
                ),
              )
              as List;
      for (final question in questions) {
        expect(
          RegExp('[가-힣]').hasMatch(tr(question['text'] as String)),
          isTrue,
        );
      }
    },
  );

  testWidgets('changing locale updates visible labels and Material controls', (
    tester,
  ) async {
    await AppLocale.instance.setLanguage('en');
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: AppLocale.instance,
        builder: (context, _) => MaterialApp(
          locale: AppLocale.instance.locale,
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const _LocaleExample(),
        ),
      ),
    );
    expect(find.text('Settings'), findsOneWidget);
    await AppLocale.instance.setLanguage('ko');
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsOneWidget);
    final context = tester.element(find.byType(_LocaleExample));
    expect(MaterialLocalizations.of(context).cancelButtonLabel, '취소');
  });
}

class _LocaleExample extends StatelessWidget {
  const _LocaleExample();
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(body: Text(tr('Settings')));
  }
}
