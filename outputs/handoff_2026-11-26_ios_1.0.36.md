# iOS 1.0.36 (1) 빌드·제출 — 맥북 전달용 (2026-11-26, Windows 세션)

(항상 한국어로 답할 것)

브랜치: `flight-search-wip` (저장소 `shinduhyung/travelog`)
최신 커밋: `f6518c4` (chore: release Android 1.0.13 (104) / iOS 1.0.36 (1))

## 할 일
1. 최신 코드 받기: `python3 scripts/sync_project.py` → `git log -1`이 `0295d67` 이후인지 확인
2. `flutter pub get` (새 asset 파일이 추가됐으므로 필수)
3. `docs/ios_handoff_2026-11-24_data_fixes.md`의 지역 테스트 9개와 화면 확인 항목을 실행
4. `platform_versions.json`의 iOS가 `1.0.36` / `1`인지 확인
5. 빌드: `python3 scripts/build_platform.py ios`
6. App Store Connect에 업로드 (Transporter 또는 Xcode Organizer)
7. 1.0.36 버전에 빌드를 붙이고 심사에 제출 (사용자가 제출까지 승인함, 2026-11-26)

## 이번 빌드에 들어간 변경 (iOS 1.0.35 이후, Android 1.0.13 (104)와 같은 코드)
| 커밋 | 내용 |
|---|---|
| eb81527 | 도시 국가 배지 오류, 이름이 같은 도시 중복, 이스탄불 랜드마크 수정 |
| c3f77b4 | 몰타 통계 지역 6개, 크림반도를 우크라이나로 표시, 저장된 키 마이그레이션 |
| bc04d58 | Cultural/Natural 랜드마크 전수조사: 중복 15개 병합, 좌표·국가코드·속성·이름 수정. 옛 이름은 `landmark_aliases.dart`로 기존 기록을 유지 |

## 출시 노트 (영어, "이번 버전의 새로운 기능")
- Improved landmark data: corrected locations, categories and duplicate entries
- Fixed country badges for some cities and updated regions for Malta
- Bug fixes and performance improvements
