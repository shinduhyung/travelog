# 파일별 검증 범위

기준일 2026-10-17. 아래 109개 파일 모두 구조 검사 대상이다. “구조 검사”는 JSON 파싱·중복·참조·일부 숫자 범위 검사이며, 내용 전체의 정확성이나 최신성을 뜻하지 않는다. 개별 보류 항목을 정상 판정으로 해석하면 안 된다.

외부 비교의 연도·정의 차이와 확정 문제는 [상세 결과](statistics_findings.md)를 함께 참고한다. Dart에 하드코딩된 국가 분류·Top Picks·개인 기록 계산은 상세 결과에 별도로 정리했다.

| 파일 | 외부 값/내용 검증 범위와 남은 작업 | 직접 참조 Dart 수 |
|---|---|---:|
| [admin1_coverage.json](../assets/admin1_coverage.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [aircraft_carries.json](../assets/aircraft_carries.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [aircraft_models.json](../assets/aircraft_models.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [aircrafts.json](../assets/aircrafts.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [airlines.json](../assets/airlines.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [airports.json](../assets/airports.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 2 |
| [alexander_empire_bc323_segments.json](../assets/alexander_empire_bc323_segments.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [all_landmarks.json](../assets/all_landmarks.json) | 이름 중복·좌표 누락·순위 참조 대조; 모든 명소의 사실 검증 보류 | 2 |
| [alpha.json](../assets/alpha.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [area_data.json](../assets/area_data.json) | 세계은행 공개 원표 전행 비교 (전체: land_area_km2; 전체: surface_area_km2); 정의·연도 차이는 별도 판정 필요 | 1 |
| [armed_forces.json](../assets/armed_forces.json) | 세계은행 공개 원표 전행 비교 (전체: armed_forces); 정의·연도 차이는 별도 판정 필요 | 1 |
| [average_age.json](../assets/average_age.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [average_price.json](../assets/average_price.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [bald.json](../assets/bald.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [british_empire_1920_segments.json](../assets/british_empire_1920_segments.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [capital_concentration.json](../assets/capital_concentration.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [casualties.json](../assets/casualties.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [cities.json](../assets/cities.json) | 지도 병합·좌표·동명 도시 대조; 인구/GDP/관광객 원수치 전수 검증 보류 | 2 |
| [cities15000.json](../assets/cities15000.json) | 번들/공개 서버 스냅샷·중복·병합 대조; 도시별 원수치 검증 보류 | 0 |
| [city_homicide_rate.json](../assets/city_homicide_rate.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [city_info.json](../assets/city_info.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [city_rank.json](../assets/city_rank.json) | 전체 이름 참조 무결성 검사; 선정 순위의 객관적 근거 미검증 | 2 |
| [city_stats.json](../assets/city_stats.json) | 북회귀선 5개 수도 좌표 대조; 나머지 테마 분류 전수 외부 검증 보류 | 1 |
| [city_tour_links.json](../assets/city_tour_links.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [city_tourist_ratio.json](../assets/city_tourist_ratio.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [city_type.json](../assets/city_type.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [climate_data.json](../assets/climate_data.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [cold_war.json](../assets/cold_war.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [continent.json](../assets/continent.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [countries_light.json](../assets/countries_light.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [country_color.json](../assets/country_color.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [country_history.json](../assets/country_history.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [country_info.json](../assets/country_info.json) | 인구·GDP·면적의 다른 앱 자료와 불일치 확인; 설명문 전체 사실 검증 보류 | 1 |
| [country_popularity.json](../assets/country_popularity.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [country_safety.json](../assets/country_safety.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [country_type.json](../assets/country_type.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [custom.geo.json](../assets/custom.geo.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 2 |
| [ddad.json](../assets/ddad.json) | 파싱 실패·직접 사용 경로 미발견; 통계 런타임 영향 미확인 | 0 |
| [democracy.json](../assets/democracy.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [economics_trivia.json](../assets/economics_trivia.json) | 32개 지표 구조·국가 코드 확인; 각 생산량/보유량 공식 최신값 대조 보류 | 1 |
| [economy_data.json](../assets/economy_data.json) | 세계은행 공개 원표 전행 비교 (전체: gdp_nominal; 전체: gdp_ppp); 정의·연도 차이는 별도 판정 필요 | 1 |
| [europe_asia_languages.json](../assets/europe_asia_languages.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [fertility_rate.json](../assets/fertility_rate.json) | 세계은행 공개 원표 전행 비교 (전체: fertility); 정의·연도 차이는 별도 판정 필요 | 1 |
| [financial_index.json](../assets/financial_index.json) | GFCI 40 공식 발표와 선두 격차 표본 대조; 전체 원표 미검증 | 1 |
| [french_empire_1920_segments.json](../assets/french_empire_1920_segments.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [gawc.json](../assets/gawc.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [geography_data.json](../assets/geography_data.json) | 일본 섬 개수·에베레스트 고도 표본 대조; 나머지 전수 검증 보류 | 1 |
| [gini_data.json](../assets/gini_data.json) | 세계은행 공개 원표 전행 비교 (전체: gini); 정의·연도 차이는 별도 판정 필요 | 1 |
| [global_rank.json](../assets/global_rank.json) | 전체 이름 참조 무결성 검사; 선정 순위의 객관적 근거 미검증 | 1 |
| [gold.json](../assets/gold.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [gov.json](../assets/gov.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [hdi_data.json](../assets/hdi_data.json) | UNDP 2025 원표 전행 대조: 193개국 일치, 대만 미검증 | 1 |
| [health.json](../assets/health.json) | 세계은행 공개 원표 전행 비교 (hospital_beds_per_1k: hospital_beds; hiv_prevalence_percent: hiv_prevalence; alcohol_consumption_2019: alcohol); 정의·연도 차이는 별도 판정 필요; 나머지 10개 섹션 외부 전수 검증 보류 | 1 |
| [height.json](../assets/height.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [historical_empires.json](../assets/historical_empires.json) | 로마제국 네덜란드 면적 모순 확인; 역사적 경계·면적 전수 검증 보류 | 0 |
| [hollywood.json](../assets/hollywood.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [homicide_rate.json](../assets/homicide_rate.json) | 세계은행 공개 원표 전행 비교 (전체: homicide); 정의·연도 차이는 별도 판정 필요 | 1 |
| [hub_airport.json](../assets/hub_airport.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [immigrants.json](../assets/immigrants.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [immigration_rate.json](../assets/immigration_rate.json) | 세계은행 공개 원표 전행 비교 (전체: immigrant_pct); 정의·연도 차이는 별도 판정 필요 | 1 |
| [iq.json](../assets/iq.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [landmark_type.json](../assets/landmark_type.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 0 |
| [language_data.json](../assets/language_data.json) | 캐나다 분류·화면 helper 불일치 확인; 전체 언어 비율 미검증 | 1 |
| [largest.json](../assets/largest.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [latitude_data.json](../assets/latitude_data.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [life_expectancy.json](../assets/life_expectancy.json) | 세계은행 공개 원표 전행 비교 (전체: life_expectancy); 정의·연도 차이는 별도 판정 필요 | 1 |
| [liveability.json](../assets/liveability.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [local_rank.json](../assets/local_rank.json) | 전체 이름 참조 무결성 검사; 선정 순위의 객관적 근거 미검증 | 1 |
| [military_expenditure.json](../assets/military_expenditure.json) | 세계은행 공개 원표 전행 비교 (전체: military_gdp_pct); 정의·연도 차이는 별도 판정 필요 | 1 |
| [millionaire.json](../assets/millionaire.json) | Henley 2024 표본으로 지표/범위 오표기 확인; 전행 최신값 대조 보류 | 1 |
| [mlb_cities.json](../assets/mlb_cities.json) | Athletics 연고지 갱신 누락 확인; 전 구단 세부 정보 미검증 | 1 |
| [mls_cities.json](../assets/mls_cities.json) | MLB 파일과 완전 동일 확인·공식 구단 목록 대조 | 1 |
| [mongol_empire_border.json](../assets/mongol_empire_border.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [navy_ships.json](../assets/navy_ships.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [nba_cities.json](../assets/nba_cities.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [nfl_cities.json](../assets/nfl_cities.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [nhl_cities.json](../assets/nhl_cities.json) | 유타 연고지 갱신 누락 확인; 전 구단 세부 정보 미검증 | 1 |
| [novel.json](../assets/novel.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [nukes.json](../assets/nukes.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [obesity_rate.json](../assets/obesity_rate.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [oldest.json](../assets/oldest.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [olympics.json](../assets/olympics.json) | 국가 코드·중복·인도 메달 대조; 전 국가 메달 수 재구축 필요 | 1 |
| [ottoman_empire_border.json](../assets/ottoman_empire_border.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [personality_questions.json](../assets/personality_questions.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [pollution.json](../assets/pollution.json) | IQAir 2025 최신 선두값과 판 차이 확인; 전행 원표 대조 보류 | 1 |
| [power_index.json](../assets/power_index.json) | GFP 2026 전체 순위 대조; 이름 미연결 항목 보류 | 1 |
| [religion_data.json](../assets/religion_data.json) | 아르메니아/에티오피아 교파 분류 표본 대조; 나머지 전수 검증 보류 | 1 |
| [religion_population.json](../assets/religion_population.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [roman_empire_100_segments.json](../assets/roman_empire_100_segments.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [safety.json](../assets/safety.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [skyscraper.json](../assets/skyscraper.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [sports.json](../assets/sports.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [starbucks.json](../assets/starbucks.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [stations.json](../assets/stations.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [student.json](../assets/student.json) | 관련 QS 최신 판 확인; 이 파일의 전체 Student Cities 순위 대조 보류 | 1 |
| [summer_olympics_cities.json](../assets/summer_olympics_cities.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [surveillance.json](../assets/surveillance.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [tanks.json](../assets/tanks.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [technology.json](../assets/technology.json) | 세계은행 공개 원표 전행 비교 (internet_users_penetration_pct: internet_penetration); 정의·연도 차이는 별도 판정 필요; 나머지 5개 섹션 외부 전수 검증 보류 | 1 |
| [territory_rules.json](../assets/territory_rules.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [top_airlines.json](../assets/top_airlines.json) | Skytrax 2026 전체 순위 대조; 이름 미연결 항목 보류 | 1 |
| [top_airports.json](../assets/top_airports.json) | Skytrax 2026 전체 순위 대조; 이름 미연결 항목 보류 | 1 |
| [top_city_hub_airport.json](../assets/top_city_hub_airport.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [traffic.json](../assets/traffic.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [transportation.json](../assets/transportation.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 2 |
| [unesco_landmarks.json](../assets/unesco_landmarks.json) | 공식 총수·분류·표본 등재연도 대조; 전체 개별 등재항목 대조 보류 | 1 |
| [updated_country_populations.json](../assets/updated_country_populations.json) | 세계은행 공개 원표 전행 비교 (전체: population); 정의·연도 차이는 별도 판정 필요 | 1 |
| [visa_data.json](../assets/visa_data.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |
| [winter_olympics_cities.json](../assets/winter_olympics_cities.json) | 구조 검사; 외부 원자료에 대한 내용 전수 검증 보류 | 1 |

직접 참조 수는 lib 내 파일명 문자열 검색 결과다. 동적 파일명, 다른 JSON의 참조, pubspec 등록 여부를 완전히 대체하지 않는다.
