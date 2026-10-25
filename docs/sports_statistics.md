# 스포츠 통계 데이터 (2026-10-24)

`tool/sports_stats/build_sports_datasets.py`가 공개 출처에서 아래 에셋을 만든다 (`python -X utf8 tool/sports_stats/build_sports_datasets.py [이름...]`).
국가명 → ISO3 변환은 `isomap.py`(Natural Earth 이름 + 별칭)가 하고, 해석되지 않는 이름은 빌드를 멈추거나 출력한다.
화면은 `lib/screens/sports_extra_cards.dart`, 조사 근거는 `audit/sports_data_feasibility.md`.

| 에셋 | 내용 | 출처 | 기준 |
|---|---|---|---|
| `olympics.json` (갱신) | 하계·동계 금/전체 메달 | Wikipedia All-time Olympic Games medal table (CC BY-SA) | 하계 파리 2024, 동계 밀라노 코르티나 2026 |
| `sports_fifa_ranking.json` | 남/여 랭킹 (순위·점수) | FIFA 랭킹 JSON (`api.fifa.com/.../rankingsbyschedule`) | 남 2026-10-07, 여 2026-06-15 |
| `sports_ucl_titles.json` | 챔피언스리그 우승 국가별/도시별 | Wikipedia | 2026 결승까지 |
| `sports_world_cup_results.json` | 국가별 월드컵 최고 성적 (8단계) | Wikipedia | 2026 대회까지 |
| `sports_tennis_slam_men.json` | 남자 단식 우승 국적별 | Wikipedia | 2026 US 오픈까지 |
| `sports_fide_grandmasters.json` | 연맹별 그랜드마스터 | Wikipedia Geography of chess | 기준일 미표기(2026 초 추정) |
| `sports_mlb_international_players.json` | 해외 출생 선수 | MLB 보도자료 2026-03-26 | 2026 개막일 |

## 합산·제외 규칙

- 올림픽: 독일 = GER+EUA+FRG+GDR, 러시아 = RUS+ROC+OAR, 세르비아 = SRB+SCG. 소련·통합팀·체코슬로바키아·유고슬라비아·러시아제국 등 역사적 팀은 제외한다. 이전 파일은 IOC 코드(GER, SUI, RSA 등 42개)를 그대로 써서 앱의 ISO3와 맞지 않았고(독일·스위스 등 누락), 수치도 출처가 섞여 있었다.
- 영국 4개 협회(잉글랜드·스코틀랜드·웨일스·북아일랜드)는 ISO3 `GBR`로 합산한다. FIFA 랭킹만 팀별로 행을 유지한다.
- 인구당 올림픽 메달은 파일 없이 `Country` 데이터에서 계산한다 (인구 100만 명 이상).
- 다운로드 약관: FIFA·MLB 수치는 사실 정보지만 상업 재사용 허가는 확인하지 못했다. Wikipedia 출처는 CC BY-SA 표기가 필요하다.
