# iOS 1.0.36 (1) 빌드·제출 — 맥북 전달용 (2026-11-26, Windows 세션)

(항상 한국어로 답할 것)

브랜치: `flight-search-wip` (저장소 `shinduhyung/travelog`)
Android 1.0.13 (104)와 **완전히 같은 코드**로 iOS를 빌드한다. 광고·온보딩·결제 규칙도 모두 공용 `lib/` 코드라서 최신 코드를 받으면 자동으로 들어간다. iOS용으로 따로 고칠 것은 없다.

## 할 일
1. 최신 코드 받기: `python3 scripts/sync_project.py` → `git log --oneline -1`이 `5107632` 이후인지 확인
2. `flutter pub get` (새 asset 파일이 추가됐으므로 필수)
3. 아래 "확인할 것"을 시뮬레이터나 실기기로 확인 (`docs/ios_handoff_2026-11-24_data_fixes.md`의 지역 테스트 9개 포함)
4. `platform_versions.json`의 iOS가 `1.0.36` / `1`인지 확인
5. 빌드: `python3 scripts/build_platform.py ios`
6. App Store Connect에 업로드 (Transporter 또는 Xcode Organizer)
7. 1.0.36 버전에 빌드를 붙이고 심사에 제출 (사용자가 제출까지 승인함, 2026-11-26)

## 지금 코드의 광고 규칙 (Android 1.0.13과 동일, `lib/services/ad_service.dart`)
| 항목 | 현재 값 | 이전 값 |
|---|---|---|
| 배너 광고 | **모든 플랫폼에서 끔** (`bannersEnabled => false`) | iOS 배너 있음 |
| 전면광고 간격 | **115초 또는 터치 35회** (`_fixedTimeCondition`, `_fixedTouchCondition`) | 130초 / 40회 |
| 첫 전면광고 유예 | 시작 화면·튜토리얼이 끝난 뒤 **2분**(`_postTutorialGraceSeconds = 120`). 유예 중에는 터치로 광고가 뜨지 않음. 첫 광고 후 115초/35회 | 3분 |
| 디버그 빌드 | 테스트 광고 단위 사용(`!kReleaseMode`). 실제 광고는 릴리스 빌드에서만 나옴 | — |

## 이번 빌드에 들어간 변경 전체 (iOS 1.0.34 이후)
iOS 1.0.35를 실제로 스토어에 내지 않았다면 아래 1.0.35 항목도 이번에 처음 들어가는 것이다. App Store Connect에서 지금 판매 중인 버전을 먼저 확인할 것.

**1.0.35에서 넣은 것 (커밋 01e369a, 095be5a, d616461, 5781f2e)**
- 위 표의 광고 규칙 (배너 끔, 115초/35회, 첫 광고 유예 2분)
- 온보딩: 기존 6단계 튜토리얼만 사용. "바로 국가 추가" A/B는 종료(코치 코드와 24개 언어 번역은 남아 있지만 배정 없음)
- 구매 기록: 주문(orders)에 설치 기기 ID(deviceId)를 붙임(게스트 포함). Apple Ads 귀속(adservices_attribution)과 구독 갱신 매칭용
- Firestore 규칙은 이미 배포됨

**1.0.36에서 새로 넣은 것**
| 커밋 | 내용 |
|---|---|
| eb81527 | 도시 국가 배지 오류, 이름이 같은 도시 중복, 이스탄불 랜드마크 수정 |
| c3f77b4 | 몰타 통계 지역 6개, 크림반도를 우크라이나로 표시, 저장된 키 마이그레이션 |
| bc04d58 | Cultural/Natural 랜드마크 전수조사: 중복 15개 병합, 좌표·국가코드·속성·이름 수정. 옛 이름은 `landmark_aliases.dart`로 기존 방문 기록 유지 |

## 확인할 것 (릴리스 빌드 또는 실기기)
- 새로 설치 → 기존 6단계 튜토리얼이 나오는지 ("바로 국가 추가" 코치가 안 나와야 함)
- 배너가 어느 화면에도 안 보이는지
- 튜토리얼 후 2분 동안 전면광고가 안 뜨고, 그 뒤 약 115초 또는 터치 35회마다 뜨는지
- Imperial Cities·Kotor 배지 국기, Valencia가 스페인인지, 이스탄불 Blue Mosque·Grand Bazaar, 몰타 지역 6개, 지도에서 크림반도 색
- 랜드마크: "Sognefjord", "Plaza Mayor, Salamanca", "Wieskirche"가 사진과 함께 나오는지, 예전에 "Jefferson Memorial"을 방문 체크한 계정이면 "Thomas Jefferson Memorial"로 체크가 유지되는지

## 출시 노트 (영어, "이번 버전의 새로운 기능")
- Banner ads removed for a cleaner view
- Improved landmark data: corrected locations, categories and duplicate entries
- Fixed country badges for some cities and updated regions for Malta
- Bug fixes and performance improvements
