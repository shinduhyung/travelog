# Travelog 화면 사용량 추적

## 집계 기준

기존 152개 이름과 그룹은 `lib/services/screen_tracking.dart`의 `screenGroups`에 보존한다.
실제 연결된 120개 화면/탭은 `screen_registry.dart`의 **Dart Type** 매핑과 명시적인 `AnalyticsScreen`/`AnalyticsTabBarView` 신호로 식별한다.
화면 생성 함수를 다시 호출하거나 클래스 이름 문자열/번역된 제목으로 추측하지 않는다.

- `travelog_screen_view`: 새 화면 방문당 1회. `analytics_screen`, `screen_group`, `visit_id`를 포함한다.
- `travelog_screen_dwell`: 포그라운드 사용 시간 조각. 위 필드와 `duration_ms`를 포함한다.
- 표준 `screen_view`도 함께 전송하지만, 이 구현의 조회수 집계에는 **travelog_screen_view만** 사용한다. 네이티브 자동 화면 이벤트와 합산하지 않는다.
- 동일 화면 재빌드, 같은 탭 재선택, 광고 종료, 백그라운드 복귀는 조회수를 늘리지 않는다.
- 다른 화면에서 뒤로 돌아오는 것은 새로운 방문이다. 복귀 시 마지막에 선택한 탭을 사용한다.
- 광고, 앱의 resumed 이외 상태, 미분류 Flutter 팝업은 시간을 일시정지한다. 중첩 원인은 각각 관리한다.
- 분류된 팝업(로그인, 국가 선택, 뱃지/랭크 획득)은 별도 화면이다. 닫고 돌아오면 원래 화면의 새 방문이다.
- 미분류 일반 페이지(목록에 없는 미니게임 등)는 이전 화면의 시간을 계속 누적하지 않는다.

30초마다 사용 시간 조각을 전송한다. 종료 콜백을 보장할 수 없는 강제 종료에서는 마지막 30초 이내 조각 및 아직 전송되지 않은 이벤트가 손실될 수 있다. 저장/네트워크 전달을 정확히 한 번 보장하는 구조는 아니다. 화면 전환 애니메이션은 첫 프레임/경로 변경 기준이므로 작은 시간 오차가 있다.

## 보고서 설정

GA4 관리 화면에서 이벤트 범위 맞춤 측정기준 `analytics_screen`, `screen_group`과 맞춤 측정항목 `duration_ms`를 등록해야 콘솔 보고서에서 사용할 수 있다. `visit_id`는 높은 고유값 수 때문에 맞춤 측정기준으로 등록하지 않고 필요하면 BigQuery에서 사용한다.

Firebase 공식 문서: https://firebase.google.com/docs/analytics/flutter/events

| 지표 | 계산 |
|---|---|
| 화면 조회수 | travelog_screen_view 이벤트 수, analytics_screen별 |
| 그룹 조회수 | travelog_screen_view 이벤트 수, screen_group별 |
| 화면/그룹 총 체류 시간 | travelog_screen_dwell의 duration_ms 합계 |
| 화면별 평균 체류 시간 | 해당 화면의 총 duration_ms / 해당 화면의 조회수 |

시간 조각 이벤트의 평균을 평균 체류 시간으로 사용하지 않는다. A 50분 → B 20분 → A 50분이면 A의 조회수는 2, 총 시간은 100분, 평균은 50분이다. 그룹 조회수는 그룹에 속한 화면 방문 수의 합이며, 그룹에 진입한 세션 수와는 다르다.
자정 전후처럼 방문과 시간 조각이 서로 다른 날짜에 기록되면 일별 평균 해석에 주의하고, 방문 기준 분석은 BigQuery에서 visit_id로 연결한다.

## 유지한 미연결/비화면 이름

24개 미연결 항목은 이름을 보존하되 임의의 다른 화면에 붙이지 않는다:
login, item_list, home_tab, loading, country_subregions, flags,
specific_countries_stats, british_empire_map, french_empire_map, historical_empire,
religion_map, geolocation_stats, climate_map, continents_list, city_map, home,
aggregate_map, top_bridges, activity_stats, badge_premium_pending, my_journey,
edit_itinerary, visa_map, world_discover.

8개 비화면 항목은 화면 조회/체류로 기록하지 않는다:
flight_records_stats(미연결 스텁), travel_features.dart(데이터 모델),
countries_share, cities_map_share, cities_share, flights_share, badge_share(공유 액션),
CMakeLists.tx(빌드 파일). 공유 액션 이벤트 추가는 이 변경에 포함하지 않는다.
152 = 120 + 24 + 8. population_stats의 그룹은 원래 분류인 2-2를 유지한다.
LandmarksListScreen의 카테고리, CapitalsScreen의 모드, AddFlightLogScreen의 신규/수정,
AiItineraryView의 sourceType 등은 기존 152개 체계에서 각각 같은 이름이므로 합산한다.
여권/여행 기록 ID나 생성자의 사용자 데이터는 Analytics 파라미터로 보내지 않는다.

## 기존 기능 보호와 수정 범위

일반 화면의 Navigator 호출/경로/생성자, 전환 테마, 광고 노출 조건, 로그인 처리, 탭 컨트롤러/스크롤 물리는 변경하지 않는다.
새 NavigatorObserver는 화면 생성이 끝난 뒤 `MaterialPageRoute.subtreeContext`의 실제 루트만 읽는다. 현재 SDK의 투명한 RepaintBoundary → Builder → Semantics만 통과하며, 알 수 없는 래퍼는 추측하지 않고 제외한다. Flutter SDK를 업데이트하면 화면 이동 테스트를 다시 실행한다.
추가된 위젯 래퍼는 레이아웃을 만들지 않으며, Analytics 전송은 비동기로 오류를 격리한다.

기존 소스 17개를 수정한다: main.dart, main_screen.dart, services/ad_service.dart;
screens/ 아래 overview_stats, society_stats, military_stats, geography_stats,
specials_stats, city_overview_stats, city_geography, city_society, city_specials,
tourism, airport_stats, ai_summary, countries_map, login_prompt의 *_screen.dart.
신규 운영 소스 2개, 테스트 2개와 이 문서 1개를 추가한다.

## 비활성화 및 검증

`--dart-define=TRAVELOG_SCREEN_TRACKING=false`로 빌드하면 사용자 정의 화면 추적을 끈다. 기존 Firebase SDK의 자동 수집 설정이나 동의 상태는 이 코드에서 바꾸지 않는다.

```text
flutter test --no-pub test/screen_tracking_test.dart
flutter test --no-pub --dart-define=TRAVELOG_SCREEN_TRACKING=false test/screen_tracking_disabled_test.dart
flutter test --no-pub
dart analyze lib test
```

테스트는 Firebase 전송 대신 메모리 수집기를 사용한다. 시간 합산, 중첩 일시정지, 실패 격리, 화면 생성 1회, Android/iOS push/pop, 탭 선택/복귀/스와이프, IndexedStack, 다이얼로그/바텀시트, iOS 뒤로 가기 제스처와 비활성화 상태를 확인한다.
실제 기기의 로그인 SDK/AdMob 노출과 Firebase 수신은 기기 및 해당 계정 접근 환경에서 추가 확인해야 한다. 테스트 통과만으로 실기기 확인 완료를 의미하지 않는다.

## 이번 검증 결과

- 추적 전용 테스트 16개 통과. 첫 실행에서 발견한 화면 식별 문제를 고친 뒤 반복 실행하여 확인했다.
- 추적을 비활성화한 별도 테스트 1개 통과.
- 기존 테스트를 포함한 전체 실행: 58개 통과, 2개 건너뜀, 1개 실패.
- 실패는 `test/localization_test.dart:89`의 프랑스어 기기 설정 기대값(en)과 실제값(fr) 불일치다. 해당 테스트와 번역 코드는 이번 변경 대상이 아니며, 추적을 끈 별도 실행에서도 동일하게 실패했다. 번역 관련 파일은 수정하지 않았다.
- 전체 lib/test 정적 분석의 컴파일 오류는 0개였다.
- 독립적인 읽기 전용 코드 검토를 세 차례 수행했다. 기존 Navigator 호출, 탭 컨트롤러/스크롤 물리, 로그인 처리, 광고 노출 조건은 유지했다.
- 연결된 Android/iOS 기기는 없어 휴대폰에서의 실제 로그인/광고 및 Firebase 이벤트 수신은 확인하지 못했다. 앱 배포나 Firebase 콘솔 변경은 수행하지 않았다.
