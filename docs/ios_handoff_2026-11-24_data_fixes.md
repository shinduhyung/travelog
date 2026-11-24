# iOS 인수인계 — 도시·랜드마크·지역 데이터 수정 (2026-11-24)

(항상 한국어로 답할 것. Windows 쪽 Claude Code 세션이 만든 변경을 Mac에서 iOS에 반영하기 위한 문서다.)

## 1. 요약
사용자 제보(Enrico, 평생 구독자)로 시작한 데이터 수정이다. 변경은 전부 공통 코드(`lib/`, `assets/`, `test/`, `tool/`)이고
`ios/`·`android/` 네이티브 파일은 건드리지 않았다. **Mac에서는 동기화 → 테스트 → 빌드만 하면 된다.**

| 커밋 | 내용 |
|---|---|
| `eb81527` | 도시 배지 안도라 표시, 동명 도시 국가 뒤섞임, Valencia, 이스탄불 랜드마크, TopBridgesScreen 삭제 |
| `c3f77b4` | 몰타 통계 구역 6개, 크림·세바스토폴 우크라이나 이전, 지역 방문 기록 1회 이전 |

## 2. 받는 방법
```sh
python3 scripts/sync_project.py
flutter pub get
```
`pubspec.yaml`에 asset 하나(`assets/admin1_key_migration.json`)가 추가됐으므로 `flutter pub get`을 꼭 실행할 것.

## 3. 바뀐 것
### 도시 (`eb81527`)
- **배지 체크리스트:** 도시 이름을 못 찾으면 목록 첫 도시(안도라)를 쓰던 것을 빈 국기로 바꿨다 (`lib/widgets/badge_detail_checklists/city_checklist.dart`). Imperial Cities 배지 `Fez` → `Fes`.
- **도시 목록 `cities15000.json`:** Kotor, Český Krumlov, Bagan, Interlaken, Queenstown(NZ) 추가, `Washington, D.C.` → `Washington D.C.`, 나미비아 국가 코드(null → `NA`) 수정.
  - **Firebase Storage(`json/cities15000.json`)에는 이미 올려서 실서비스에 반영돼 있다.** 앱은 이 파일을 Storage에서 받으므로 구버전 iOS 앱도 새 목록을 받는다. 번들 asset도 같은 내용으로 맞췄다.
- **동명 도시:** 접미사 없는 대표 이름을 통계 데이터(`cities.json`) 국가의 도시가 갖도록 바꿨다(`lib/providers/city_provider.dart`). 예: Victoria=세이셸, Hamilton=버뮤다, Hyderabad=인도. Valencia는 예외로 스페인이 `Valencia`, 베네수엘라가 `Valencia(1)`. 다른 도시의 `(n)` 번호는 그대로다.
- **저장된 도시 키 1회 이전:** `Valencia(1)`→`Valencia` 등 7개 키, 홈 도시 포함. 플래그 `cityKeyMigrationV1`(기기 prefs + Firestore user 문서). `Washington, D.C.`는 항상 새 이름으로 읽는다.
- `cities.json` 통계 이름 `Chisinau` → `Chișinău`.
### 랜드마크 (`eb81527`)
- 이스탄불 Blue Mosque·Grand Bazaar를 선택할 수 없던 문제: 랜드마크 도시 화면과 Best of Istanbul 배지의 이름을 데이터 이름(`Blue Mosque`, `Grand Bazaar of Istanbul`)에 맞췄다.
- 사용되지 않던 `TopBridgesScreen` 삭제.
### 지역 (`c3f77b4`)
- **몰타:** 지방의회 68개 → 통계 구역 6개(키 `MT::<구역>`).
- **크림(UA-43)·세바스토폴(UA-40):** 러시아 → 우크라이나. 지역 데이터와 나라 윤곽(`assets/custom.geo.json`) 모두 옮겼다. 러시아 83, 우크라이나 27.
- **저장된 지역 키 1회 이전:** `assets/admin1_key_migration.json`을 `SubregionProvider`가 한 번 적용(몰타 지방의회 → 구역, RUS의 크림 키 → UKR). 버전은 prefs와 Firestore user 문서의 `subregionKeyMigrationVersion`.

## 4. Mac에서 확인할 것
1. 테스트
   ```sh
   flutter test test/admin_region_repository_test.dart
   ```
   9개 모두 통과해야 한다 (Windows에서 통과 확인함).
2. iOS 시뮬레이터 또는 실기기에서 눈으로 확인 (Windows에서는 실기기 확인을 못 했다):
   - 배지 → City → Imperial Cities, Kotor: 국기가 모로코·몬테네그로로 나오고 안도라가 없는지
   - 도시 검색 `Valencia`: 스페인, `Valencia(1)`: 베네수엘라
   - 랜드마크 → 도시별 → Istanbul: Blue Mosque, Grand Bazaar of Istanbul 선택 가능
   - 나라 → Malta → 지역: 6개 구역
   - 메인 지도에서 크림반도가 우크라이나 색으로 칠해지는지, 나라 → Ukraine 지역에 Crimea·Sevastopol이 있는지
   - (가능하면) 업데이트 전에 Valencia(1)·몰타 지방의회를 체크해 둔 계정으로 업데이트 후 기록이 새 이름으로 옮겨졌는지
3. 빌드: 새 버전은 iOS 최신 업로드(현재 `platform_versions.json` 기준 1.0.35 (1))보다 높게 올린 뒤
   ```sh
   python3 scripts/build_platform.py ios
   ```
   업로드·제출은 사용자 확인을 받고 할 것.

## 5. 주의
- Android도 아직 이 변경을 출시하지 않았다(현재 Android 1.0.12 (103)). 두 플랫폼 버전 정보는 각자 출시할 때 올린다.
- 작업 트리에 남아 있는 `functions/index.js`, `functions/partner_system.js`, `functions/subscription_lifecycle.js` 변경은 이 작업과 무관하며 커밋·푸시하지 않았다.
- 전체 국가의 지역 단위 정리 계획(213개국)은 Windows의 `reports/region_plan_2026-11-24.md`에 있다(git 미포함). 이번에 적용한 것은 영국 결정(12개, 미적용), 몰타·크림(적용)뿐이다.
