> **이전 버전 감사:** 이 문서는 `0eb026e` 기준입니다. `520c085`에서 지역 기능이 새로 연결되었습니다. 최신 지역 기능 판정은 [지역 기능 재점검](region-feature-audit-520c085.md)을 참고하세요.

# Android·iOS 구현 기능 대조 보고서

검사일: 2026-10-16 (한국 시간)

## 범위와 판정 방법

- Android 작업본: `acdddc3` (`chore: checkpoint current work before further changes`)
- iOS 작업본: `354d21b` (`feat: expand geography games and update iOS subscriptions`)
- 현재 통합본: `0eb026e` (브랜치 `flight-search-wip`)
- Dart 파일 247개를 파일별 대조. 화면/공유 모듈 151개, 게임 모듈 10개, Provider 23개, Service 13개, Widget 16개, 그 외 모델·앱 진입 코드 포함.
- 문자열·식별자·연산자를 유지하고 주석과 공백을 제외한 비교에서 227개는 같고 20개는 차이가 있었다. 달랐던 파일은 아래에 별도로 판정했다. 151개의 파일 모두가 실제 진입 가능한 독립 화면이라는 의미는 아니다.
- 앱 진입점, 탭, 메뉴의 화면 생성, 게임 허브, 플랫폼 분기, 네이티브 위젯, 권한·알림 설정, 서버 코드와 자산도 확인했다.
- 이 보고서는 소스의 구현·연결 상태 감사다. 두 실제 출시 바이너리, 실기기, 스토어 상품 설정, Firebase 배포·Apple APNs 설정을 실행 검증한 결과는 아니다. 코드 동일성을 실제 서비스 정상 동작으로 확정하지 않는다.
- 감사 중 앱 코드나 데이터는 수정하지 않았다.

## 1. 현재 남은 사용자 기능 차이

| 기능 | Android | iOS | 판정 |
|---|---|---|---|
| 국가 지도 홈 화면 위젯 | 이미지 생성·저장·위젯 공급자와 OS 등록 구현 | 해당 업데이트 미실행. WidgetKit 확장 구현 확인 안 됨 | iOS 구현 없음 |
| 도시 지도 홈 화면 위젯 | 이미지 생성·저장·위젯 공급자와 OS 등록 구현 | 해당 업데이트 미실행. WidgetKit 확장 구현 확인 안 됨 | iOS 구현 없음 |
| 국가 통계 World / Geography / Specials 진입 | 비로그인 시 로그인 안내 | 이 진입 단계에서 바로 화면 이동 | 접근 조건 차이. 유료 여부를 검사하는 코드가 아니라 로그인 검사 |
| 도시 통계 Travel / Geography / Specials 진입 | 비로그인 시 로그인 안내 | 이 진입 단계에서 바로 화면 이동 | 접근 조건 차이 |
| iOS 추적 권한 요청 | 해당 OS 권한 요청 없음 | ATT 팝업 및 결과 처리 | OS 전용 기능, 일반 여행 기능 누락은 아님 |

근거: `lib/screens/countries_menu_screen.dart`, `lib/screens/cities_menu_screen.dart`, `lib/services/home_widget_service.dart`, `android/app/src/main/kotlin/com/example/jidoapp/TravelogWidget.kt`, `TravelogCitiesWidget.kt`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`, `ios/Runner.xcodeproj/project.pbxproj`.

항공 위젯은 Service에 `WidgetType.flights` 이름만 있다. 실제 호출, Android의 `TravelogFlightsWidget` 공급자·등록, iOS 확장이 확인되지 않아 Android에서 완성된 기능으로 계산하지 않았다.

## 2. 병합 전 한쪽에만 있던 보완과 현재 상태

| 항목 | 병합 전 차이 | 현재 통합본 |
|---|---|---|
| 랜드마크 목록의 작은 사진·상세 큰 사진 | Android 쪽에 추가 구현 | 공통 코드에 있어 양쪽 사용 |
| 랜드마크 이미지 로딩 실패 시 다른 주소 시도 | Android의 국가 상세·목록·방문기록 화면에 보완 | 세 화면 모두 공통 코드에 보존 |
| 랜드마크 상세 헤더·방문 표시 디자인 | Android가 더 최근 형태 | 현재 양쪽 같은 코드 |
| 랜드마크 기본 정렬 | iOS 이름순 / Android 국가순 | 현재 국가순으로 공통화 |
| 로그인 직후 방문 기록 표시 | Android에 Provider 재생성·리스너 정리 보완 | 공통 코드에 보존 |
| 유네스코 방문에 따른 뱃지 재계산 연결 | Android 앱 진입부에 의존성 묶음 보완 | 공통 코드에 보존 |
| 여행 성향 AI 결과의 계정 동기화 | iOS Provider 쪽에 보완 | 공통 코드에 보존. 새 분석을 매번 즉시 업로드한다는 의미는 아님 |
| 화면 위에 표시하는 뒤로가기 버튼 | iOS 작업본에 구현 | 플랫폼 조건 없이 양쪽 공통 적용 |
| 알림 탭 후 퀴즈 진입 재시도 | iOS 작업본에 보완 | 공통 코드에 보존 |
| 국가·도시·항공·뱃지 공유 팝업 위치 | iOS 작업본에 보완 | 5개 공유 모듈의 공통 코드에 보존 |
| 월간·연간·평생 결제, 구매 복원 | 양쪽 존재, 스토어별 처리 상이 | 두 스토어 처리 공존. 스토어 실제 상품/결제는 미검증 |
| 구독 갱신과 결제일 기록 | Android Play 갱신 기록 / iOS 원본 거래·결제일·서버 확인 | 양쪽 처리 코드 공존. 서버 배포 여부는 미확인 |
| TikTok 구매 전환 수집 | Android 구현 | Android만 유지. 사용자 화면 기능 아님 |

공유 팝업 위치는 iPad 계열에서 중요한 차이지만 이번 감사에서는 기기 실행을 하지 않았다. 기존 코드의 보완을 유지했는지 확인했다.

## 3. 양쪽 공통으로 연결되지 않았거나 미완성인 기능

### 게임 4개는 파일이 있지만 메뉴에 없음

`lib/screens/travelog_games_screen.dart`에서 import 및 진입 버튼이 있는 것은 아래 6개다.

1. Flag Guess
2. Which Is Farther?
3. Border Chain
4. Respawn
5. Timezone Impostor
6. Higher or Lower

다음 4개는 각 구현 파일이 양쪽 작업본과 현재 통합본에 모두 있으나, 다른 앱 파일에서 import하거나 진입 화면을 생성하는 연결이 없다.

| 게임/도구 | 구현 파일 | 확인한 진입 클래스 | 현재 판정 |
|---|---|---|---|
| Airport Code | `lib/games/airport_code.dart` | `AirportCodeDifficultyScreen` | 메뉴 미연결 |
| Second City | `lib/games/second_city.dart` | `SecondCityLobbyScreen` | 메뉴 미연결 |
| Reveal | `lib/games/reveal.dart` | `RevealModeScreen` | 메뉴 미연결 |
| Map Lab | `lib/games/map_lab.dart` | `MapLabScreen` | 메뉴 미연결 |

Airport Code, Second City, Reveal의 로컬 점수 키도 `GameScoresSyncService`의 동기화 대상에 포함되지 않는다. 이 게임들을 메뉴에 연결하더라도 점수 계정 동기화까지 자동으로 완성되지는 않는다. 이는 Android/iOS 한쪽 누락이 아닌 양쪽 공통 상태다.

### 지역 방문 기록 화면도 실제 진입 연결이 없음

**대상 구분:** 아래 판정은 미국 캘리포니아·뉴욕주, 한국 서울·경기도 같은 국가 내부 행정구역을 직접 체크하는 `CountrySubregionsScreen`에 한정한다. `Countries → General`에서 대륙을 선택해 동아시아·서유럽 등 세계 권역별 방문 국가 수/목록을 보고 국가 상세로 이동하는 기능은 `OverviewStatsScreen`에 실제 연결되어 있다. 이 세계 권역 통계까지 메뉴가 없다는 의미가 아니다.

- `CountrySubregionsScreen`에는 지역 체크리스트와 방문 체크 저장 코드가 있다.
- 미국/한국 목록을 만드는 `SpecificCountriesStatsScreen`이 그 지역 화면을 연다.
- 그러나 `SpecificCountriesStatsScreen` 자체를 앱에서 생성하는 호출이 없다. `MilitaryStatsScreen`은 import만 하고 현재 Military/Geopolitics 두 탭만 표시한다.
- 따라서 현재 일반 메뉴에서 이 경로로 지역 방문 화면에 들어갈 수 있다고 판단하면 안 된다.
- 지역 목록 함수에는 미국·한국·캐나다·일본 목록이 있지만, 국가 목록 화면은 미국·한국만 대상으로 한다.
- 실제 지역 GeoJSON 로드는 미국만 처리한다. 한국·캐나다·일본의 지역 지도는 이 화면에 구현되지 않았다.
- 이 상태는 두 작업본에서 동일하다. 한쪽 프로젝트에만 완성된 지역 기능이 있는 상황은 확인되지 않았다.

앞선 대화에서 “미국·한국 메뉴가 열린다”는 표현은 파일 내부 목록과 실제 앱 진입을 구분하지 못한 것이었다. 위 내용으로 정정한다.

## 4. 콘텐츠 차이와 이전 통합의 누락

- Android 작업본의 랜드마크는 8,221개, iOS 작업본은 8,223개였다.
- iOS에만 있던 항목: **The Walled Off Hotel**, **Vinicunca**.
- 현재 통합본은 Android의 8,221개 목록을 유지해 두 항목이 없다. 이전 자동 병합에서 iOS의 해당 두 데이터 항목까지 보존하지 못한 상태다. 이번 감사에서는 수정하지 않았다.
- 도시 데이터는 양쪽 모두 32,870개 레코드였고, 레코드별 값은 같았다. iOS 원본의 JSON 구분자 오류를 Android의 유효한 JSON으로 통합했다.
- 10개 게임 파일은 병합 전에도 주석·공백을 제외하면 같았다. 일부 데이터 파일 차이는 줄바꿈 형식 차이였다.

## 5. 화면은 양쪽에 있으나 실제 동작 검증이 필요한 부분

| 기능 | 소스 확인 | 남은 확인 |
|---|---|---|
| 일일 퀴즈 알림 | 클라이언트의 요청·토큰·탭 처리, 서버의 Android/APNs 메시지 구성 모두 존재 | iOS 소스의 entitlements에는 Apple 로그인만 있고 `aps-environment`가 없음. 서명된 앱의 푸시 권한·APNs 등록·Firebase 설정을 확인해야 함. 배포 앱의 알림 불능을 단정하지 않음 |
| 외부 웹 링크로 앱 열기 | Android Manifest에 웹 호스트 수신 선언 존재 | 앱 내부 화면으로 분기하는 링크 처리 코드 및 iOS associated domains 설정을 확인하지 못함. 완성된 Android 전용 딥링크 기능으로 계산하지 않음 |
| Google/Apple 로그인 | 양쪽 UI 및 플랫폼별 인증 구현 존재 | 각 스토어·OAuth 콘솔·실제 계정 로그인 검증 필요 |
| 사진 첨부/촬영 | 공통 ImagePicker 호출 및 iOS 카메라·사진 접근 설명, Android 관련 선언 존재 | 권한 승인/거부, 실기기 사진 선택·촬영·저장 검증 필요 |
| 유료 구독·복원 | 상품 ID·선택 UI·두 스토어 처리 존재 | 스토어 상품 설정, 만료·복원·갱신 실거래 미검증 |
| AI/추천·항공 데이터·예약 링크 | 공통 화면 및 서비스 호출 존재 | 로컬 환경 변수, 서버 응답, 계정별 데이터에 따라 달라질 수 있음 |

## 6. 기능군별 공통 구현 확인

‘공통’은 같은 소스·메뉴 흐름을 사용함을 뜻한다. 실제 기기에서 모든 입력과 저장 결과를 재현한 통과 표시는 아니다.

| 기능군 | 대조한 세부 내용 | 결과 |
|---|---|---|
| 기본 탭 | My Trips / Countries / Cities / Explore / Flights | 공통 |
| 국가 지도 | 방문 국가 색칠, 국가 선택, 국가 상세, 지도 표시 옵션 | 공통 |
| 국가 방문 기록 | 방문일, 방문 상태, 국가별 기록·통계 | 공통 |
| 국가 정보/통계 | 일반·문화·세계·지리·특수 통계, 인구·면적·경제·언어·종교 등 | 공통. 위 일부 메뉴 로그인 조건 차이 제외 |
| 도시 지도/목록 | 도시 탐색·방문 체크·도시 정보·목록·지도 공유 | 공통 |
| 도시 방문 기록 | 방문일·메모·사진·별점/관련 상세 | 공통 |
| 도시 통계 | 일반·문화·여행·지리·특수 및 경제·역사·기후·교통·스포츠 | 공통. 위 일부 메뉴 로그인 조건 차이 제외 |
| 랜드마크 탐색 | 카테고리 목록, 검색, 지도, 국가별 랜드마크 | 공통. 데이터 두 항목 누락 별도 기재 |
| 랜드마크 기록 | 방문 체크, 하위 위치, 위시리스트, 별점, 방문일·메모·사진 | 공통 |
| 랜드마크 이미지 | 상세 큰 사진, 목록 작은 사진, 이미지 실패 대체 | Android 보완을 현재 양쪽에 공유 |
| 유네스코 | 목록·지도·통계·방문 기록·사진·뱃지 연계 | 공통 |
| 명소/활동 카테고리 | 건축물·박물관·그림·다리·광장·산·강·호수·폭포·조각·음식·축제·놀이공원 등 | 공통 카테고리 코드 |
| 공항 | 목록·이용 기록·메모/사진·통계 | 공통 |
| 항공사 | 목록·상세·이용 기록·통계 | 공통 |
| 비행 기록 | 추가·목록·연결편·노선 지도·빈도·기종·좌석·환승·라운지 통계 | 공통 |
| 항공 지도 공유 | 지도 캡처·공유 | 공통 |
| 여행 일지 | 목록·상세·추가/수정·여행 지도·AI 요약 관련 흐름 | 공통 |
| 일정/달력 | 일정 데이터·달력·AI 일정 화면 | 공통 소스. 외부 서비스 실행 미검증 |
| 여권/비자 | 여권 선택·비자 정보·세부 정보 | 공통 |
| 여행 성향 | 질문·여행 DNA·AI 분석·저장 | 공통. AI 계정 동기화 보완도 현재 공유 |
| 일일 퀴즈 | Normal/Expert, 날짜별 문제·기록·기본 모드 | 공통. iOS 알림 권한 확인은 별도 |
| 게임 | 허브에 연결된 위 6개, 난이도·점수·체험·게임 광고 | 공통 |
| 추가 게임 4개 | Airport Code / Second City / Reveal / Map Lab | 양쪽 모두 파일만 존재, 메뉴 미연결 |
| 지역 방문 | 지역 체크·저장 및 미국 지도 코드 | 양쪽 모두 진입 연결 누락, 지도 지원 제한 |
| 뱃지/랭크 | 목록·상세 체크리스트·달성·랭크 팝업·공유 | 공통 |
| 프로필/계정 | Google/Apple 로그인·로그아웃·프로필·계정 데이터 연계 | 공통 UI. OS별 인증 방식은 상이 |
| 동기화 | 국가·도시·항공·여행·유네스코·지역·여행 성향·게임 데이터 | 공통 코드. 서버/계정 실제 동작 미검증 |
| 설정 | 테마, 영토 포함, 지도 경계, 순위 막대 색, 데이터 초기화 | 공통 |
| 공유 | 국가·도시·도시 지도·항공·뱃지 | 공통. iOS 공유 위치 보완 포함 |
| 구독 | 월간·연간·기존 연간·평생, 상품 조회·구매·복원 | 공통 상품 UI + 플랫폼별 결제 |
| 광고 | 일반 앱 광고·게임 광고·구독 시 비활성화 관련 처리 | 공통 정책 + 플랫폼별 광고 ID |
| 홈 위젯 | 국가·도시 | Android만 구현 |

## 7. 내용이 달랐던 Dart 파일 20개 개별 판정

| 파일 | 판정 |
|---|---|
| `lib/main.dart` | 기존 Android의 로그인 후 데이터 재생성·뱃지 의존성 수정과 iOS의 상시 뒤로가기·알림 진입 재시도 통합. ATT만 iOS 분기. 호출되지 않던 Android 테스트 팝업은 통합하지 않음. |
| `lib/providers/city_provider.dart` | 차이는 초기화·계정 전환 진단 로그. 도시 방문 기능의 별도 누락 없음. |
| `lib/providers/country_provider.dart` | 차이는 초기화·계정 전환 진단 로그. 국가 방문 기능의 별도 누락 없음. |
| `lib/providers/personality_provider.dart` | 기존 iOS에만 AI 여행 분석 결과의 계정 동기화 보완이 있었음. 현재 공통 코드에 보존. |
| `lib/screens/badge_share.dart` | 기존 iOS의 공유 팝업 위치 지정 보완을 현재 공통 코드에 보존. |
| `lib/screens/cities_map_share.dart` | 기존 iOS의 공유 팝업 위치 지정 보완을 현재 공통 코드에 보존. |
| `lib/screens/cities_menu_screen.dart` | Android의 도시 홈 위젯과 일부 통계 로그인 조건을 Android에 보존. iOS는 위젯 실행 없음·직접 통계 진입. |
| `lib/screens/cities_share.dart` | 기존 iOS의 공유 팝업 위치 지정 보완을 현재 공통 코드에 보존. |
| `lib/screens/countries_menu_screen.dart` | Android의 국가 홈 위젯과 일부 통계 로그인 조건을 Android에 보존. iOS는 위젯 실행 없음·직접 통계 진입. |
| `lib/screens/countries_share.dart` | 기존 iOS의 공유 팝업 위치 지정 보완을 현재 공통 코드에 보존. |
| `lib/screens/country_detail_screen.dart` | 기존 Android의 랜드마크 큰 사진·작은 사진·다중 이미지 주소 대체·상세 헤더를 현재 양쪽에 공유. |
| `lib/screens/flight_route_map_screen.dart` | 기존 Android의 타일 요청 진단 및 타일 이미지 로딩·오류 처리 차이. 현재 공통 코드. 항공 지도 기능 자체는 양쪽에 있었음. |
| `lib/screens/flights_share.dart` | 기존 iOS의 공유 팝업 위치 지정 보완을 현재 공통 코드에 보존. |
| `lib/screens/landmark_visit_log_screen.dart` | 기존 Android의 사진·대체 이미지 주소·상세 헤더 보완을 현재 공통 코드에 보존. 방문일·메모·사진 기록은 양쪽 구현. |
| `lib/screens/landmarks_list_screen.dart` | 기존 Android의 썸네일·큰 사진·이미지 대체 처리·상세 표시·기본 국가순 정렬을 현재 공통 코드에 보존. |
| `lib/services/ad_service.dart` | 광고 조건 130초/40터치 및 국가 실험은 공통. 현재 플랫폼별 광고 단위 선택. 역사적 난수 표현·주석 차이 존재. |
| `lib/services/game_ad_service.dart` | 게임 광고 흐름은 공통, 광고 단위만 플랫폼별 선택. |
| `lib/services/subscription_service.dart` | Android 주문·갱신·TikTok 이벤트와 iOS 원본 거래 ID·실제 결제일 처리를 공존시킴. 월간·연간·평생 상품 및 복원 UI는 공통. |
| `lib/widgets/firebase_badge_image.dart` | 기존 iOS의 URL 검증·진단 로그·에러 대체 표시 차이를 공통 코드에 보존. 기본 이미지 캐시 및 로컬 대체 기능은 양쪽 구현. |
| `lib/widgets/subscription_sheet.dart` | 상품 선택·구매·복원 구성은 공통. 스토어별 안내 문구 선택을 현재 통합. |

## 8. Dart 파일 전체 대조 목록

‘동일’은 두 병합 전 작업본을 주석·공백 제외로 비교한 결과다. 문자열(로그/문구 포함)이 다르면 ‘차이’로 표시했다. 따라서 ‘차이’가 곧 기능 누락이라는 뜻은 아니다. 상세 판정은 7절을 참고한다. 현재 하나의 통합 소스를 사용하는 구조이며 OS별 실제 기능 차이는 1절과 5절에 별도 기재했다.

| 파일 | Android/iOS 작업본 대조 | 현재 확인 |
|---|---|---|
| `lib/firebase_options.dart` | 동일 | 플랫폼별 Firebase 구성 선택 |
| `lib/games/airport_code.dart` | 동일 | 공통 파일, 메뉴 미연결 |
| `lib/games/border_chain.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/games/flag_guess.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/games/higher_or_lower.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/games/map_lab.dart` | 동일 | 공통 파일, 메뉴 미연결 |
| `lib/games/respawn.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/games/reveal.dart` | 동일 | 공통 파일, 메뉴 미연결 |
| `lib/games/second_city.dart` | 동일 | 공통 파일, 메뉴 미연결 |
| `lib/games/timezone_impostor.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/games/which_is_farther.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/main.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/main_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/airline_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/airport_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/airport_visit_entry.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/badge_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/calendar_memo_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/city_info_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/city_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/city_visit_detail_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/country_info_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/country_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/country_population_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/economy_data_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/flight_info.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/historical_empire_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/itinerary_entry_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/landmarks_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/language_data_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/language_family_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/personality_question.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/religion_data_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/subregion_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/trip_log_entry.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/unesco_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/user_visa_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/visa_data_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/visit_date_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/models/visit_details_model.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/my_tile_layer.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/airline_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/airport_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/auth_provider.dart` | 동일 | 공통 UI 연계, 인증 방식 플랫폼 분기 |
| `lib/providers/badge_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/calendar_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/city_info_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/city_provider.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/providers/country_info_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/country_provider.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/providers/economy_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/flight_map_settings_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/history_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/itinerary_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/landmarks_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/language_family_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/language_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/passport_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/personality_provider.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/providers/religion_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/subregion_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/trip_log_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/unesco_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/providers/visa_provider.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/activities_menu_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/activity_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/add_flight_log_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/aggregate_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/ai_itinerary_view.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/ai_summary_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/aircraft_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/airline_detail_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/airline_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/airlines_list_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/airport_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/airports_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/alexander_empire_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/area_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/badge_collected_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/badge_detail_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/badge_premium_pending_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/badge_share.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/badges_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/british_empire_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/calendar_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/capitals_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/champions_league_teams_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/cities_map_share.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/cities_menu_screen.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/cities_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/cities_share.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/city_climate_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_economy_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_geography_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_history_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_overview_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_society_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_specials_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_sports_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_stats_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_tiers_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/city_transportation_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/climate_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/climate_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/continents_list_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/countries_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/countries_menu_screen.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/countries_share.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/country_detail_screen.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/country_selection_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/country_subregions_screen.dart` | 동일 | 공통 파일, 지역 진입 경로 누락 |
| `lib/screens/country_tiers_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/countrydex_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/daily_quiz_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/disneyland_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/economy_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/edit_itinerary_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/edit_trip_log_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/explore_menu_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/favorites_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/film_festivals_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flags_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flight_connection_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flight_frequency_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flight_hub_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flight_log_list_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flight_overview_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flight_records_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flight_route_map_screen.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/flight_transfer_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flights_lounge_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flights_menu_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/flights_share.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/french_empire_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/geography_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/geolocation_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/geopolitics_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/historical_empire_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/history_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/home_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/home_tab_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/instagram_ranking_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/item_list_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/landmark_cities_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/landmark_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/landmark_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/landmark_visit_log_screen.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/landmarks_list_screen.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/screens/landmarks_menu_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/language_family_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/language_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/language_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/loading_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/login_prompt_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/login_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/military_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/mongol_empire_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/my_journey_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/my_trips_tab_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/natural_menu_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/onboarding_tutorial_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/ottoman_empire_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/overview_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/passport_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/passport_visa_detail_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/population_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/populations_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/profile_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/purchase_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/rank_collected_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/recommendations_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/religion_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/religion_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/roman_empire_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/seat_class_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/settings_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/society_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/specials_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/specific_countries_stats_screen.dart` | 동일 | 공통 파일, 지역 진입 경로 누락 |
| `lib/screens/sports_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_activities_menu_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_bridges_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_buildings_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_cities_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_falls_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_lakes_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_landmarks_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_mountains_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_museums_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_orchestras_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_paintings_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_picks_menu_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_public_squares_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_rivers_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_statues_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/top_universities_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/tourism_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/travel_features.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/traveler_type_ai_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/traveler_type_selector_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/travelog_games_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/trip_dna_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/trip_log_detail_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/trip_log_list_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/trip_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/unesco_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/unesco_sites_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/unesco_stats_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/universal_studios_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/visa_map_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/visa_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/welcome_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/world_discover_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/screens/world_wonders_screen.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/ad_service.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/services/aero_data_box_service.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/ai_service.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/flight_price_service.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/game_ad_service.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/services/game_insane_trial_service.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/game_scores_sync_service.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/home_widget_service.dart` | 동일 | Android 위젯 연결, iOS 구현 없음 |
| `lib/services/perplexity_service.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/storage_service.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/subscription_service.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/services/travel_persona_engine.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/services/travel_quantifier.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/travel_persona/travel_features.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/utils/city_utils.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/utils/premium_access_manager.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/badge_detail_checklists/city_checklist.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/badge_detail_checklists/continent_checklist.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/badge_detail_checklists/country_checklist.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/badge_detail_checklists/flight_checklist.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/badge_detail_checklists/landmark_checklist.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/city_detail_modal.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/city_travel_modal.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/firebase_badge_image.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/widgets/landmark_info_card.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/landmark_visit_editor_card.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/likert_scale_widget.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/plane_loading_logo.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/premium_badge_shimmer.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/premium_theme.dart` | 동일 | 공통 파일; 소스 비교 |
| `lib/widgets/subscription_sheet.dart` | 차이 — 개별 판정 완료 | 7절 참고 |
| `lib/widgets/unesco_visit_editor_card.dart` | 동일 | 공통 파일; 소스 비교 |

## 9. 다음 확인 우선순위

1. iOS에도 국가·도시 홈 위젯이 필요한지 결정하고 별도 구현.
2. 6개 통계 메뉴의 로그인 조건을 양쪽 동일하게 할지 결정.
3. 지역 방문 목록을 실제 메뉴에 연결하고, 미국 외 지역 지도 지원 범위를 정하기.
4. 게임 4개를 공개하려면 메뉴·진입·점수 동기화까지 연결.
5. 이전 통합에서 빠진 랜드마크 두 데이터 항목을 복구할지 확인.
6. iOS 푸시 권한/서명·APNs와 실제 알림 수신, 두 스토어 구매·복원은 기기 테스트.

이 문서는 감사 결과이며 위 수정 사항을 수행하거나 새 커밋을 푸시하지 않았다.
