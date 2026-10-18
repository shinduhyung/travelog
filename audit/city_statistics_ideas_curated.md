# 기존 주제·단순 세분화를 제외한 도시 통계 후보

기존 앱 자산과 통계 화면을 대조한 13개 후보. 앞선 170개는 수치 확보 목록이며 신규 추천 목록으로 사용하지 않음.

각 항목: 유럽 밖 도시 10곳 이상, 서로 다른 수치 10개 이상 확인. 원자료 도시 수이며 앱 도시와의 매칭 수는 아님. JRC는 도시 중심지 경계를 사용하며 추정값·과거 자료를 포함.

- [ ] 소득 대비 주택가격 배율 — 2026 / 유럽 밖 최소 177개 도시 / [출처](https://www.numbeo.com/property-investment/rankings.jsp?title=2026)
- [ ] 도심 주택 임대수익률 — 2026 / 유럽 밖 최소 177개 도시 / [출처](https://www.numbeo.com/property-investment/rankings.jsp?title=2026)
- [ ] 현지 소득의 구매력 — 2026 / 유럽 밖 최소 215개 도시 / [출처](https://www.numbeo.com/cost-of-living/rankings.jsp?title=2026)
- [ ] 녹색도가 높은 구역에 사는 인구 비율 — 2025 / 유럽 밖 최소 10,256개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 강한 열 스트레스를 겪는 연평균 일수 — 2020 참조 / 유럽 밖 최소 10,257개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 해안 도시 주변 해수면 상승 속도 — 1993~2023 / 유럽 밖 최소 1,112개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 해발 10m 미만 해안 저지대 거주 인구 비율 — 2025 / 유럽 밖 최소 4,349개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 100년 재현기간 하천 홍수 위험구역 거주 인구 — 2025 / 유럽 밖 최소 10,257개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 진도 MMI 6 이상 지진 위험구역 거주 인구 비율 — 2025 / 유럽 밖 최소 10,257개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 인구 증가에 비해 도시 땅이 얼마나 늘어나는지 — 2010~2020 / 유럽 밖 최소 8,443개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 2015~2025년 새로 개발된 시가지 비율 — 2025 / 유럽 밖 최소 10,257개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 도시 주민 1인당 CO₂ 배출량 — 2020 / 유럽 밖 최소 10,257개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)
- [ ] 도시의 태양광 발전 잠재량 — 2020 참조 / 유럽 밖 최소 10,255개 도시 / [출처](https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php)

## 제외 기준

- 인터넷 전부: technology.json과 관련 모델·화면
- 의료시설·의료지수 전부: health.json, society_stats_screen.dart의 Hospital Beds 등 기존 의료 주제
- 생활비/식료품/외식/임대료 지수: average_price.json 및 기존 물가 주제와 가까움
- 교통 혼잡/속도/손실시간: traffic.json의 기존 교통 주제
- 삶의 질 종합: liveability.json
- 층수별·고층/저층 세분화: skyscraper.json과 인접하고 독립 주제로 약함
- 성비·연령대별 인구: health.json의 sex_ratio_total, average_age.json 등 기존 인구 주제와 가까움
- 건축물 총 면적/부피/인당 파생값의 반복
- LCZ 17분류를 각각 별도 추천으로 나열
- 토지 피복 세부 분류를 각각 나열
- 가스·산업 부문별 배출량을 수십 개로 나열
- CISI 세부 지수처럼 사용자에게 의미를 설명하기 어려운 지표
- 임대수익률의 역수인 가격/임대료 배율을 중복 나열
