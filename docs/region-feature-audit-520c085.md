# 지역 기능 재점검 — 520c085

검사일: 2026-10-16 (한국 시간). 대상: GitHub `origin/flight-search-wip`의 `520c085`.
새 커밋 2개를 fetch한 뒤 기존 로컬 브랜치를 fast-forward해 확인했다. 기존 미추적 감사 보고서는 보존했다.

## 결론

최신 버전에는 국가 내부 주·도·현 방문 기능의 메뉴 연결이 있다. 이전 `0eb026e`의 옛 화면에 대한 ‘메뉴 미연결’ 판정은 최신 지역 구현에 적용되지 않는다.
새 기능은 `CountryRegionsSection`, `CountryRegionDropdown`, `VisitedWorldMapLayer`를 사용하는 다른 경로다. Android/iOS 모두 동일한 데이터·접근 조건·화면·저장 코드를 사용한다. 관련 구현에는 한 플랫폼에서만 기능을 빼는 분기가 없다.

## 실제 진입과 기능

| 항목 | 실제 경로/처리 | Android / iOS |
|---|---|---|
| 국가별 지역 지도 | Countries → CountryDex → 국가 상세 → Regions | 공통 연결 |
| 지도에서 방문 체크 | Regions 지도 탭 → 지역 판정 → 체크/해제 | 공통 |
| 전체 화면 지도 | Regions → Full screen, 확대·이동·지역 탭 | 공통 |
| 검색 목록 | Regions → Region list → 검색·스위치 | 공통 |
| 방문 진행률 | 방문 지역 수 / 전체 지역 수, 퍼센트·진행 막대 | 공통 |
| 국가 목록 내 지역 펼치기 | 세계 지도 → + → Select Countries → Show regions | 공통 |
| 임시 선택 적용 | Apply Changes에서 지역 변경을 일괄 저장 | 공통 |
| 임시 선택 취소 | Cancel은 변경을 적용하지 않고 닫음 | 공통 |
| CountryDex 진행률 | 국가 항목에서 방문/전체 지역 수 표시 | 공통 |
| Countries 미리보기 | Share 옆 전환으로 국가/지역 지도 변경 | 공통 |
| 전체 세계 지도 | Settings 옆 전환으로 국가/지역 지도 변경 | 공통 |
| 선택 화면 모드 유지 | +로 열 때 현재 지도 모드 전달 | 공통 |
| 국가/지역 기록 분리 | 국가를 방문해도 모든 하위 지역을 자동 방문 처리하지 않음 | 공통 |
| 무료 접근 | 고정된 원본 30개국의 지역 | 공통 |
| Premium 접근 | 추가 국가의 지역. 상세·목록·지도·저장 단계에서 접근 제한 | 공통 |
| 권한 변경 반영 | 구독 상태 변경 시 표시 갱신, 잠긴 데이터의 지역 수정 차단 | 공통 |
| 업데이트 안내 | 기존 계정 첫 기능 접근 시 안내·NEW 표시, 계정 단위 중복 방지 | 공통 |
| 신규 가입자 제외 | Google 로그인 및 Android/iOS Apple 로그인에서 가입 여부 기록 | 공통 |

근거 파일:

- `lib/screens/country_detail_screen.dart`: 1737행의 Regions 삽입, 국가 부가 정보 유무 양쪽 경로에 포함.
- `lib/widgets/country_regions_section.dart`: 지도 탭, 전체 화면, 검색 목록, 진행률.
- `lib/screens/country_selection_screen.dart`: 421행 지역 펼치기, 551행 지역 변경 적용.
- `lib/screens/countrydex_screen.dart`: 지역 수 및 무료/Premium 표시.
- `lib/screens/countries_menu_screen.dart`, `lib/screens/countries_map_screen.dart`: 두 지도 전환 및 진입.
- `lib/widgets/visited_world_map_layer.dart`: 직접 체크한 지역만 색칠하고 국가 방문과 분리.
- `lib/services/country_region_access.dart`, `lib/widgets/country_region_access_gate.dart`: 접근 조건.
- `lib/providers/subregion_provider.dart`: 로컬/서버 저장 및 지역별 키.
- `lib/services/country_regions_notice_service.dart`, `lib/providers/auth_provider.dart`: 안내의 계정별 처리.

## 데이터 범위

실제 GeoJSON을 읽어 확인했다.

- 238개 국가·지역 코드.
- 213개 코드에 세부 지역 경계, 총 4,563개 방문 가능한 지역.
- 나머지 25개 코드는 국가·지역 외곽선만 제공. 지역 체크 항목이나 방문 개수를 제공하지 않으며, 경계 미지원 안내가 나온다.
- 한국 17개, 미국 51개(DC 포함), 일본 47개, 캐나다 13개.
- 미국만 지도가 있던 이전 미연결 프로토타입과 다른 전국가 자산을 사용한다.
- 무료 30개국은 KR, US, JP, CA 등을 포함한다. 추가 국가에서는 지역 기능에 Premium이 필요하다. 단순 외곽선만 있는 곳을 방문 가능한 세부 지역으로 판매하지 않는다.

## 발견 사항: 이전 이름으로 저장된 기록의 호환성

`SubregionProvider.isRegionVisited`는 새 `stableKey` 또는 현재 지역명과 일치하는 기록만 인식한다(162~167행).
옛 `CountrySubregionsScreen`의 지역명 목록과 새 자산 이름을 직접 대조하면 다음 차이가 있다.

| 대상 | 이전 이름 예 | 새 이름 예 | 옛 이름이 일치하지 않는 수 |
|---|---|---|---|
| 한국 | Gyeonggi-do, Gangwon-do, Chungcheongbuk-do | Gyeonggi, Gangwon, North Chungcheong | 8개 |
| 일본 | Hokkaido, Kyoto, Osaka | Hokkaidō, Kyōto, Ōsaka | 6개 |
| 캐나다 | Quebec | Québec | 1개 |
| 미국 | California 등 | California 등 | 0개 |

따라서 **옛 프로토타입 방식의 이름으로 저장된 기록이 실제로 존재한다면** 해당 지역이 새 화면에서 미방문처럼 보일 수 있다. 데이터가 삭제된다는 뜻은 아니다. 이름 별칭 변환 또는 지역 코드로의 마이그레이션이 필요하다. Android/iOS 공통 문제다.

실제 사용자 계정 데이터는 조회하지 않았고, 옛 프로토타입의 진입 경로도 기존 버전에서 연결되지 않았으므로 실제 영향 계정이 있는지는 이 감사로 확정하지 않는다. ‘원본 30개국 데이터/키 보존’ 테스트가 통과하더라도, 이 별도의 옛 화면 이름 기록까지 변환됐다는 뜻은 아니다.

## 검증

- 기존 Mac Flutter는 Dart 3.11.3으로 최신 `flutter_quill 11.5.1`의 Dart 3.12 요구 조건을 충족하지 못했다.
- 기존 설치를 변경하지 않고 `/private/tmp/travelog-flutter-3.44-audit`에 Flutter 3.44.0 / Dart 3.12.0을 준비해 의존성 설치를 완료했다. 추적된 의존성 파일의 변경은 없었다.
- 기존 지역 관련 테스트 6개 파일을 임시 복사하고, Flutter의 `TargetPlatformVariant`로 Android/iOS 각각의 화면 설정을 적용해 실행했다. 테스트 본문은 그대로 사용했다.
- Android: 27개 통과.
- iOS: 27개 통과.
- 대상: 데이터 범위·도형·고유 키·원본 30개국 데이터, Premium 잠금/복원 상태/만료 상태, 외곽선 전용 안내, 지역 선택 적용/취소, 국가 체크와 지역 체크 분리, 세계 지도 전환·모드 전달, 계정별 업데이트 안내.
- 관련 핵심 파일 10개 정적 분석: 오류·경고 없음, 스타일/사용 중단 API 안내 10개.
- 최초 임시 테스트 래퍼는 플랫폼 debug 변수 정리 시점 때문에 실패했다. 이를 Flutter 표준 플랫폼 variant 방식으로 수정한 뒤 위 두 결과를 얻었다. 해당 실패를 앱 결함으로 계산하지 않았다.
- 임시 테스트 파일은 실행 후 삭제했다. 앱 코드를 수정하거나 커밋·푸시하지 않았다.

### 검증의 한계

이 결과는 공통 로직 및 Android/iOS 화면 설정을 적용한 위젯 테스트다. 실제 Android 기기·iPhone에서 실행한 결과가 아니다. 테스트는 가짜 방문 Provider·가짜 결제/계정 저장소를 사용하므로 실제 Firebase 계정으로 두 기기 간 저장·복원, 실제 App Store/Google Play 결제와 구독 만료는 검증하지 않았다. 로컬/서버 저장 경로가 양쪽 공통인 것은 소스에서 확인했다.

Mac의 기본 Flutter 설치는 그대로이므로, 기본 `flutter` 명령으로 새 버전을 빌드하려면 요구 SDK에 맞추는 작업이 별도로 필요하다.
