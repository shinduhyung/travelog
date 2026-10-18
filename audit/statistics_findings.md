# 앱 통계 감사 결과 — 2026-10-17

후속 작업에서 통계 JSON 69개를 공통 스키마로 리팩터링했다. 이 보고서는 그 이전 감사 시점의 결과이며, 수치 자체는 변경하지 않았다. 새 구조와 검증 방법은 [통계 스키마 문서](../docs/statistics_schema.md)를 참고한다.

## 결론과 범위

수치 오류, 국가 코드 연결 오류, 갱신 누락, 계산 오류가 모두 발견됐다. 특히 올림픽, 도시 병합, MLS, 자산가 수, 부가세 분류, 세계유산, 항공 순위는 먼저 손봐야 한다.

이번 작업은 **확인과 감사**다. 앱의 Dart 코드와 원본 assets 데이터는 변경하지 않았다. 감사 스크립트와 결과 파일만 추가했다. 기존 미추적 파일 `test/region_load_tmp_test.dart`도 수정하지 않았다.

- `assets` 최상위 JSON **109개**를 모두 파싱·목록화하고, 키·중복·참조·국가 코드·누락을 검사했다. 이 중 통계 외에 지도, 추천 성향, 설명 자료도 포함된다.
- 이름에 `stats`가 들어가는 화면 31개와 추가 도시 통계, 여권, 국가·도시 상세, Top Picks 화면의 데이터 경로와 주요 계산을 추적했다.
- 세계은행 **16개 지표 × 앱 레코드 2,608건**을 검사했다. 공식 관측치와 연결된 비교는 **2,389건**, 허용한 반올림 오차를 넘는 차이는 **1,881건**이다. **이는 오류 1,881건이라는 뜻이 아니다.** 연도·통계 정의·자료 개정·GDP 전망치/실적치·면적 범위 차이도 포함된다. 같은 면적을 육지면적과 총면적에 각각 비교하므로 독립적인 사실의 개수도 아니다.
- UNDP HDI 194개 행 중 공식 자료가 있는 **193개국은 소수 셋째 자리까지 전부 일치**했다. 대만 1건은 해당 UNDP 원자료에 없어 별도 검증 대상이다.
- Skytrax 2026 항공사 100개·공항 100개와 Global Firepower 2026 전체 순위를 읽어 비교했다. 표기 차이로 연결하지 못한 항목은 오류로 세지 않았다.
- 앱이 도시 지도에 사용하는 공개 서버 파일도 읽었다. 서버와 번들 파일이 다르므로 두 경로를 각각 검사했다. 사용자 기기의 현재 캐시와 개인 계정 기록은 직접 읽지 않았다.

**모든 수치가 최신임을 인증한 결과는 아니다.** 출처·기준 연도·정의가 없는 자료는 검증 보류로 남겼다. 아래 확정 문제와 검증 보류를 구분해서 봐야 한다. 공식 자료가 오래된 관측치만 제공하는 경우도 있어, 오래된 연도라는 이유만으로 틀렸다고 판단하지 않았다.

파일별 완료·보류 범위는 [statistics_review_status.md](statistics_review_status.md), 전체 파일 목록은 [statistics_inventory.md](statistics_inventory.md), 국가별 원값·공식값·관측연도·차이는 [worldbank_comparison.csv](worldbank_comparison.csv), 외부 자료 및 코드 대조 결과는 [source_and_logic_checks.json](source_and_logic_checks.json)에 있다.

## 1. 수치 또는 데이터 연결이 명확하게 잘못된 항목

### 1-01. 올림픽: ISO 코드와 IOC 코드 혼용 — 우선순위 P1

`assets/olympics.json`의 `iso_a3`에 ISO가 아닌 IOC 코드 **43종**이 들어 있다. 예: 독일 `GER` → 앱 국가 코드 `DEU`, 스위스 `SUI` → `CHE`, 덴마크 `DEN` → `DNK`, 포르투갈 `POR` → `PRT`, 남아공 `RSA` → `ZAF`. `CountryProvider`는 변환 없이 ISO 키로 조회하므로 해당 국가들의 메달이 null이 되고, 스포츠 순위의 `value > 0` 필터에서 사라진다.

여기에 수치 자체도 잘못됐다. 인도는 하계 금 38개·전체 151개로 저장돼 있다. 파리 2024까지 공식 인도 자료는 전체 41개를 제시한다. 단순히 2026년 자료를 덧붙일 문제가 아니라, 국가 코드와 집계 기준부터 재구축해야 한다. [인도 정부의 올림픽 메달 자료](https://cdnbbsr.s3waas.gov.in/s3kv03d4057861196bea4cae0b310f0095/uploads/2025/05/2025052096.pdf)

근거: `lib/providers/country_provider.dart`의 `olympicsMap`과 `lib/screens/sports_stats_screen.dart`의 `_prepareList`. 코드 목록은 `statistics_inventory.json`의 `assets/olympics.json.codes_not_in_map`.

### 1-02. 올림픽: 중복 국가 행의 뒤쪽 값이 앞쪽 값을 덮어씀 — P1

칠레 `CHL`: 하계 금 9/총 56 → 뒤쪽 금 6/총 32. 슬로베니아 `SVN`: 금 9/총 43 → 뒤쪽 금 3/총 18. 아이슬란드 `ISL`: 하계 총 4 → 뒤쪽 총 0. Dart Map 생성 과정에서 뒤쪽 행이 이긴다. 원자료 하나를 고르는 임의의 중복 제거로 끝내지 말고 공식 메달 자료로 교체해야 한다.

### 1-03. WBC 우승국의 국가 코드가 잘못됨 — P1

`Dominican Rep.`가 `DMA`로 연결돼 있다. `DMA`는 도미니카이며, 도미니카공화국은 `DOM`이다. 방문률과 지도 강조가 다른 나라에 적용된다. 위치: `sports_stats_screen.dart`, `WBC Winners`.

### 1-04. MLS 도시가 MLB 도시 파일의 복사본 — P1

`assets/mls_cities.json`과 `assets/mlb_cities.json`은 파싱한 내용이 **완전히 동일**하다. MLS 파일에 Baltimore·Milwaukee·Oakland 등이 들어 있고, Columbus·Austin·Nashville·Montreal·Vancouver 등 실제 MLS 시장이 빠져 있다. 30행이라는 숫자가 맞아도 30개 MLS 구단 자료가 아니다. 방문 도시 컬렉션과 완료율에 직접 영향을 준다. [MLS 공식 구단 목록](https://www.mlssoccer.com/clubs/)

### 1-05. 도시 ‘Millionaires’가 백만장자 수가 아님 — P1

`assets/millionaire.json`의 San Francisco 675, New York City 744 등은 Henley 2024 자료의 **centi-millionaires, 즉 미화 1억 달러 이상 자산가 수**와 일치한다. UI는 이를 `Millionaires`로 표시한다. 같은 2024 원자료의 Bay Area 백만장자는 305,700명이다. 또한 Bay Area는 San Francisco와 Silicon Valley를 포함하므로 San Francisco 단일 도시명도 범위가 다르다. [Henley 2024 원표](https://www.henleyglobal.com/publications/usa-wealth-report-2024/americas-wealthiest-cities)

해결: 지표를 Centi-millionaires로 정확히 바꾸거나, 백만장자 자료를 별도로 넣고 도시권 범위와 기준일을 표시한다. 현재 숫자에 100을 곱하는 식으로 고칠 수 없다.

### 1-06. 이름만으로 도시를 병합해 다른 나라 좌표·인구를 붙임 — P1

`city_provider.dart`의 `_mergeAndProcessCities`는 `statsMap[city.name]`을 만들고, 지도 데이터의 동명 도시 중 인구가 가장 많은 도시에 상세 통계를 붙인다. 국가 코드를 함께 확인하지 않는다. 번들·서버 파일 양쪽에서 **11개 국가 불일치 + Windhoek의 국가 코드 누락 1개**를 확인했다.

| 앱 상세 통계의 도시 | 실제로 선택되는 지도 데이터 |
|---|---|
| Stanley, 포클랜드 | 영국 Stanley |
| Douglas, 맨섬 | 아일랜드 Douglas |
| Queenstown, 뉴질랜드 | 남아공 Queenstown |
| Victoria, 세이셸 | 홍콩 Victoria, 인구 956,800 |
| St. John's, 앤티가 바부다 | 캐나다 St. John's |
| St. George's, 그레나다 | 버뮤다 St. George's |
| Panama City, 파나마 | 미국 Panama City |
| Hamilton, 버뮤다 | 캐나다 Hamilton, 인구 519,949 |
| George Town, 케이맨제도 | 말레이시아 George Town |
| Saint-Pierre, 생피에르 미클롱 | 레위니옹 Saint-Pierre |
| Hyderabad, 인도 | 파키스탄 Hyderabad |
| Windhoek, 나미비아 | 지도 행의 `country_code`가 null |

좌표·인구·국가·GDP가 서로 다른 공간 범위가 되는 문제다. `(국가 코드, 도시 식별자)`로 병합해야 한다. `cities.json`에도 Kingston이 두 번 있어 Norfolk Island 행이 Jamaica 상세 통계를 덮는다. 지도 병합 후 문제가 있는 도시 전체는 `source_and_logic_checks.json.city_merge`에 보존했다.

### 1-07. 국가별 살인율의 충돌하는 중복 행 — P1

`homicide_rate.json`에는 21개 국가 코드가 중복된다. 이 중 베냉 1.13/1.1, 부르키나파소 1.25/1.3, 중앙아프리카공화국 29.1/19.8, 코트디부아르 45.7/11.8, 콩고민주공화국 35.2/13.4, 콩고공화국 0/10.1, 토고 62.7/8.29는 값도 다르다. 앱은 뒤쪽 값을 사용한다. 어느 쪽이 옳은지는 출처 없이 판정할 수 없지만 **하나의 기준으로 관리되지 않는 데이터 충돌 자체는 확정**이다.

추가로 `GBN`, `GBS`는 앱 국가 코드와 연결되지 않는다. 단순히 둘 다 GBR로 바꾸면 국가 전체와 하위 지역 통계를 혼합할 수 있으므로 원출처 확인이 필요하다.

### 1-08. 군사력 지수 중복·국가 코드 문제 — P1

`power_index.json`에서 나이지리아 0.5771/2.6689, 말레이시아 0.7429/2.2379, 세르비아 1.2576/1.3941, 슬로바키아 1.3978/2.9371, 시에라리온 2.1016/3.9701이 충돌한다. 뒤쪽 값으로 순위가 바뀐다. `MTN`도 앱 국가 코드에 없다.

### 1-09. 기대수명 중복 충돌 — P2

`life_expectancy.json`의 Gibraltar `GIB`가 78.7과 79.6으로 중복되며 79.6이 사용된다. Timor-Leste 중복은 같은 값이다. 지니계수의 MUS·SYC, 지리 자료의 KOS도 중복이지만 값이 같아 현재 수치 차이를 만들지는 않는다. 이들은 정리 대상이며 충돌 오류와 구분해야 한다.

### 1-10. 경제 생산 통계의 국가 코드 연결 누락 — P1

`economics_trivia.json`의 원유 생산 UAE 행은 `UAE`로 저장됐지만 앱은 `ARE`를 쓴다. 우라늄 생산의 `NGR`도 앱 국가 코드에 없으며, 나이지리아/니제르의 코드 혼동 가능성이 있어 원출처 확인 후 정규화해야 한다. 해당 생산량은 순위에서 누락된다.

### 1-11. 랜드마크 중복이 방문 수·분모를 부풀림 — P1

`all_landmarks.json`에 Petřín Lookout Tower, Capilano Suspension Bridge, Walt Disney World Resort, Cape of Good Hope, Glacier National Park, Death Valley, Amalfi Coast, Ngorongoro Crater가 각각 두 번 있다. 좌표·국가도 같은 대상이다. 통계 화면은 리스트 행을 세고 방문 여부는 이름 Set으로 판단하므로 하나를 방문해도 두 행이 방문된 것으로 집계될 수 있다. `localRanks`를 이름 Map으로 적용할 때는 마지막 중복 객체만 갱신된다.

### 1-12. 교량 20개 순위와 실제 랜드마크 DB 연결이 전부 끊김 — P2

`top_bridges_screen.dart`의 교량 20개 이름 모두 `all_landmarks.json`에 정확한 이름이 없다. 클릭하면 상세 자료를 찾지 못하며 방문 컬렉션도 정상 연결하기 어렵다. 길이 수치의 외부 검증 여부와 별개로 연결 문제는 전수 확인됐다.

### 1-13. Öresund Bridge 위도 누락 — P2

`all_landmarks.json`의 해당 행에 `latitude`가 없다. 모델은 누락값을 0.0으로 바꾸므로 지도·위치 기반 통계에서 적도 부근 좌표로 처리된다. 경도만 존재하는 상태다.

### 1-14. 가장 높은 조각상 순위가 높이순이 아님 — P1

`top_statues_screen.dart`: 100m가 108m보다 앞서고, 80m가 88m보다 앞서며, 42m가 42.7m보다, 30m가 34m보다 앞선다. **인접 순위 역전 4곳**이다. 높이의 받침대 포함 여부도 자료마다 맞춰야 한다. Awaji Kannon은 철거된 대상인데 현존 최고 높이 순위에 계속 포함돼 있다. [일본 재무국의 철거·부지 활용 자료](https://lfb.mof.go.jp/kinki/content/006/00600035.pdf)

### 1-15. 폭포 높이 순위 역전 — P2

`top_falls_screen.dart`에서 Vinnufossen 860m가 6위, Skorga 864m가 7위다. 표시한 숫자를 기준으로도 순서가 틀렸다. 폭포 총낙차·단일낙차·조사값의 정의 차이는 별도로 검증해야 한다.

### 1-16. 로마제국 영역의 네덜란드 면적이 국가 전체보다 큼 — P1

`history_stats_screen.dart`의 `_romanEmpireAreas['Netherlands'] = 150000`km². 앱의 네덜란드 전체 면적은 41,526km²다. 현대 네덜란드 안에 포함되는 제국 영역을 뜻한다면 성립하지 않으며, 제국 방문 면적과 완료율 분모를 왜곡한다. 역사 자료 출처 없이 임의의 대체 숫자를 넣지 말아야 한다.

### 1-17. 북회귀선 위의 수도 분류가 좌표와 모순 — P2

`city_stats.json.capitals_on_tropic_of_cancer`의 5개 수도는 앱 좌표 기준으로도 북위 약 23.436°에서 떨어져 있다. Nassau 약 179km, Riyadh 약 142km, Abu Dhabi 약 113km, Havana 약 36km, Muscat 약 17km 차이다. ‘위’가 아니라 ‘근처’라면 거리 기준을 정의해야 한다. 현재 제목대로라면 부정확한 컬렉션이다.

## 2. 공식 자료로 갱신 누락 또는 잘못된 분류가 확인된 항목

### 2-01. 세계유산 총수와 분류 — P1

앱은 **1,221개**, 공식 목록은 확인 시점 **1,273개**다. 총수 차이 52개는 순누락 규모이며 개별 신규·통합·확장 대조 없이 ‘신규 52개만 추가’하면 안 된다. 앱 자료의 유형은 Cultural 951/Natural 226/Mixed 44이며 기준 시점도 표시하지 않는다. 2026 등재 항목은 없다. [UNESCO 현재 목록](https://whc.unesco.org/en/list/), [2026 신규 등재 목록](https://whc.unesco.org/en/newproperties/)

`Petroglyphs along the Bangucheon Stream`의 등재연도도 앱 2024 → 공식 2025로 잘못돼 있다. [UNESCO 등재 결정](https://whc.unesco.org/en/decisions/8954/)

### 2-02. 항공사 순위 — P1

`top_airlines.json`은 2026 순위가 아니다. 이름을 보수적으로 연결한 결과 80개는 순위가 다르고, 2개는 같으며, 18개는 표기 또는 Top 100 포함 여부를 추가 확인해야 한다. 예: 앱 Qatar 1위/Singapore 2위 → 2026 Singapore 1위/Qatar 2위. Vistara·Air Malta·Buta Airways 등 과거 운영 자료도 포함돼 기준 연도가 꼭 필요하다. [Skytrax 2026](https://www.worldairlineawards.com/worlds-top-100-airlines-2026/)

### 2-03. 공항 순위 — P1

`top_airports.json`도 현행 순위와 다르다. 이름 연결 결과 84개 순위 변경, 9개 동일, 7개 추가 확인이다. 예: 앱 Incheon 4위 → 2026 2위. 단순히 1위 Changi가 같다고 최신인 자료가 아니다. [Skytrax 2026](https://www.worldairportawards.com/worlds-top-100-airports-2026/)

### 2-04. Global Firepower 군사력 지수 — P1

2026 전체 공식 목록 145개를 파싱했다. 앱 143행 중 이름 연결 가능한 137행의 지수가 모두 다르다. 나머지 6행은 이름/수록 범위 확인 대상이다. 중복 행도 포함한 비교이므로 ‘137개 국가 오류’라고 세면 안 된다. 예: USA 0.0744 → 0.0741, China 0.0788 → 0.0919. [공식 2026 순위](https://www.globalfirepower.com/countries-listing.php)

### 2-05. 인구·기대수명·출산율 등 — P1/P2

국가별 전체 대조표는 CSV에 있다. 대표적인 갱신·기준 혼용 사례:

| 지표 | 앱 값 | 확인한 공식 자료 | 판단 |
|---|---:|---:|---|
| 인도 인구 | 1,417,492,000 | 세계은행 2025: 1,463,865,525 | 약 4,637만 명 차이; 관측연도 명시 필요 |
| 미국 인구 | 340,110,988 | 세계은행 2025: 341,784,857 | 오래된 스냅샷 |
| 한국 기대수명 | 84.3세 | KOSIS 2024: 83.7세 | 출처·연도 재확인 필요 |
| 미국 기대수명 | 77.2세 | CDC 2024: 79.0세 | 갱신 필요 |
| 한국 출산율 | 0.75 | KOSIS 2025: 0.799 | 더 최신 확정 통계가 존재 |
| 독일 군사비/GDP | 1.5% | 세계은행/SIPRI 2025: 약 2.269% | 연도 갱신 필요 |

[세계은행 인구 지표](https://data.worldbank.org/indicator/SP.POP.TOTL), [KOSIS](https://kosis.kr/index/index.do), [CDC 2024 기대수명](https://www.cdc.gov/nchs/products/databriefs/db548.htm), [SIPRI 지출 DB](https://www.sipri.org/databases/milex)

주의: 세계은행과 각국 통계청의 값은 추계 방식·범위·개정 때문에 다를 수 있다. ‘세계은행 값과 다름’을 자동 오류로 바꾸지 않았다. 국가별 latest_year도 같지 않다.

### 2-06. GDP 자료는 기준 연도와 전망/실적 구분이 없음 — P2

미국 30,507.217 billion, 인도 4,187.017 billion, 일본 4,186.431 billion 등은 과거 전망치 조합으로 보인다. 앱에는 출처·연도·forecast 여부가 없고, GDP 계산 분모인 population도 다른 시점 자료다. IMF에는 October 2026 공개 자료가 있으므로 기준판을 정해 명목·PPP·인구·1인당 GDP를 같은 판으로 맞춰야 한다. 세계은행 실적과 IMF 전망 차이는 그 자체로 오기가 아니다. [IMF WEO 데이터](https://data.imf.org/datasets/WEO)

### 2-07. 국가 상세 화면과 통계 화면 수치 불일치 — P1

`country_info.json`은 별도의 문자열 수치다. 한국 GDP는 상세 $2.05T / 통계 $1.790322T, 미국 $28.9T / $30.507217T, 독일 인구 약 84.7M / 83,577,140으로 다르다. 미국 면적도 9,833,520 / 9,363,520km², 한국 면적 100,210 / 99,434km²다. 서로 다른 지표·연도라면 명시해야 하며, 현재는 같은 앱에서 같은 이름의 숫자가 달라 보인다.

### 2-08. 일본 섬 개수·에베레스트 고도 — P2

일본은 6,852개로 저장돼 있지만 일본 국토지리원 재집계는 **14,125개**다. 측정·집계 기준 변경에 따른 갱신이다. [국토지리원](https://www.gsi.go.jp/common/000247634.pdf)

에베레스트는 Top Mountains 8,848m 및 지리 자료 8,848m로 저장됐다. 2020년 네팔·중국 공동 발표는 **8,848.86m**다. 정수 반올림 표시라면 8,849m이며, 모델의 int 제약도 함께 정해야 한다. [공동 발표](https://www.mfa.gov.cn/gjhdq_676201/gj_676203/yz_676205/1206_676812/xgxw_676818/202012/t20201208_9301006.shtml)

### 2-09. UN 회원국 목록: 개수는 193이지만 구성 오류 — P1

`geopolitics_stats_screen.dart`의 UN 목록에 `NIU`(니우에)가 들어 있고 `VCT`(세인트빈센트 그레나딘)가 빠져 있다. 개수가 맞는지만 보는 검사로는 놓치는 오류다. 니우에는 UN 전문기구 가입과 UN 회원국 지위가 다르다. [UN 현 회원국 자료](https://research.un.org/en/unmembers/currentmembers), [니우에 지위 관련 뉴질랜드 외교부 자료](https://www.mfat.govt.nz/assets/OIA/OIA-2023/OIA-28505-US-recognition-of-Cook-Islands-and-Niue-30-March-2023.pdf)

### 2-10. ASEAN·SCO·BRICS 가입 누락 — P1

- ASEAN: 10개만 있으며 2025-10 가입한 Timor-Leste `TLS` 누락. [ASEAN 공식 확인](https://asean.org/secretary-general-of-asean-attends-commemorative-reception-to-mark-timor-lestes-asean-membership/)
- SCO: 9개이며 2024-07 가입한 Belarus `BLR` 누락. [SCO 공식 성명](https://eng.sectsco.org/20240704/1460010.html)
- BRICS: Indonesia `IDN` 누락. 사우디아라비아의 지위는 자료마다 다뤄온 방식이 달라 기준일·채택 출처를 표시해야 하지만, 인도네시아 정회원 가입 누락은 확실하다. [BRICS 의장국 공식 발표](https://brics.br/en/news/brazil-announces-indonesia-as-full-member-of-brics)

### 2-11. 팔레스타인 승인국 — P1

앱의 151개 목록에는 영국·프랑스·캐나다·호주·포르투갈 등이 없다. 2025년 9월 승인 변화를 반영하지 않았다. 현재 최종 숫자는 승인 철회·조건부 승인·대상국 집계 기준을 정해 별도로 동결해야 한다. [영국 정부](https://www.gov.uk/government/news/uk-formally-recognises-palestinian-state), [호주 정부](https://www.foreignminister.gov.au/minister/penny-wong/media-release/australia-recognises-state-palestine), [영국 의회 정리](https://commonslibrary.parliament.uk/research-briefings/cbp-10323/)

### 2-12. ‘부가세 없음’에 실제 부가세 시행국 포함 — P1

`economy_stats_screen.dart._noVatCountryCodes`에 UAE, Bahrain, Bahamas, Vanuatu가 들어 있다. 공식 표준세율은 각각 **5%, 10%, 10%, 15%**다. 단순 최신화 문제가 아니라 수년 전부터 시행 중인 제도와도 맞지 않는다. [UAE 정부](https://u.ae/en/information-and-services/finance-and-investment/taxation/vat/valueaddedtaxvat), [바레인 국세청 지침](https://nbrproduserdata-ir.s3.eu-west-1.amazonaws.com/media/TjifwIUNJsy20MvW1ueSYqyColOmV9V8vqxUZIK9.pdf), [바하마 세무당국](https://inlandrevenue.finance.gov.bs/value-added-tax/about-vat/), [바누아투 세무당국](https://vanuatucustoms.gov.vu/index.php/taxes-and-licensing/taxes/value-added-tax-vat/introduction)

`No Income Tax`에는 소말리아가 있지만 소말리아 재무부는 소득세 제도를 운영한다. `No Corporate Tax`의 버뮤다는 2025년부터 일정 대규모 다국적기업에 법인세가 적용되므로 전면 무세국처럼 분류하면 부정확하다. [소말리아 소득세 자료](https://www.mof.gov.so/index.php/publications/income-tax-manual-english-version), [버뮤다 정부](https://www.gov.bm/articles/cit)

### 2-13. 탄소세와 배출권거래제 혼동 — P2

`Carbon Tax` 목록에 한국·중국·카자흐스탄·뉴질랜드 등이 들어 있다. 탄소가격제 전체와 탄소세는 같은 지표가 아니다. 세계은행은 ETS와 Carbon Tax를 분리한다. 제목을 넓히거나 제도별로 나눠야 한다. [세계은행 Carbon Pricing Dashboard](https://carbonpricingdashboard.worldbank.org/dashboard)

### 2-14. 시간대·내륙국 분류 — P2

`multipleTimeZonesData['KAZ'] = 2`지만 카자흐스탄은 2024-03-01부터 전국 UTC+5 단일 시간대다. [카자흐스탄 정부](https://www.gov.kz/org/mfa-jakarta/press/news/details/715495?lang=en)

`allLandlockedCodes`에는 Eswatini `SWZ`가 빠져 있다. [UN 내륙개도국 목록](https://www.un.org/en/node/205691). Kosovo를 포함할지는 앱의 국가 범위 정책과 일치시켜야 한다.

### 2-15. WBC 우승국 갱신 누락 — P1

2026 우승국 Venezuela `VEN`이 목록에 없다. 1-03의 Dominican Republic 코드 수정과 함께 처리해야 한다. [MLB의 2026 우승 보도](https://www.mlb.com/news/venezuela-wins-world-baseball-classic-2026)

### 2-16. MLB·NHL 도시 자료 갱신 — P2

MLB에 Oakland가 남아 있고 Athletics의 현 홈구장 소재 West Sacramento/Sacramento가 없다. NHL에는 Phoenix·Tempe가 남아 있고 Utah의 Salt Lake City가 없다. 구단 시장명/경기장 소재 도시를 함께 중복 집계하는 방식도 통일해야 한다. [MLB 공식 구장](https://www.mlb.com/athletics/ballpark), [NHL Utah 공식 페이지](https://www.nhl.com/utah/)

### 2-17. QS 대학 순위 — P2

`all_landmarks.json`의 University `attribute_rank`를 QS 순위로 사용한다. 앱 Stanford 3, Caltech 10, ETH 7 등의 배열은 최신 2027판과 다르다. 2027판은 2026년에 발표돼 이미 사용할 수 있다. 기준판과 공동 순위도 보존해야 한다. 100개 대학 전체의 최신 순위 개별 대조는 아직 완료하지 않았다. [QS 공식 Top 100](https://www.topuniversities.com/student-info/choosing-university/worlds-top-100-universities), [QS 발표문](https://www.prnewswire.com/news-releases/qs-world-university-rankings-2027-302803295.html)

### 2-18. 도시 대기오염·금융 중심지 지수 — P2

대기오염 자료는 Byrnihat 128.2를 맨 위에 둔 과거 자료다. 2025 IQAir 보고서는 2026-03 발표됐고 Loni 112.5µg/m³가 최고 도시다. 화면에 단위와 기준연도도 필요하다. [IQAir 공식 발표](https://www.iqair.com/in-en/newsroom/waqr-2025-pr)

`financial_index.json`의 New York 763/London 750은 13점 차이다. 최신 GFCI 40 공식 보도자료는 4점 차이라고 설명하므로 같은 판의 현행 표가 아니다. 30개 도시 전체의 GFCI 40 원표 다운로드는 승인 검토의 사용량 한도 때문에 실행되지 못했다. 그 부분은 개별 수치 검증 완료로 표시하지 않았다. [GFCI 40 공식 발표](https://www.longfinance.net/news/press-releases/press-release-global-financial-centres-index-40-asian-financial-centres-challenge-the-established-players/)

### 2-19. 언어·종교 분류 — P2

`language_data.json`에서 캐나다 English dominant=true인데, 화면의 `isDominant()`는 Canada를 강제로 false로 처리한다. Non-dominant를 끄면 영어 주사용국 목록에서 캐나다가 빠진다. 공식언어·모국어·가정사용어 중 무엇을 뜻하는지도 명시해야 한다. [캐나다 통계청](https://www150.statcan.gc.ca/n1/daily-quotidien/220817/dq220817a-eng.htm)

`religion_data.json`은 아르메니아·에티오피아를 Eastern Orthodoxy로 분류하지만 해당 주류 교회는 Oriental Orthodox 전통이다. 화면의 분류 체계에도 별도 항목이 없어 종파별 국가 수가 틀어진다. [세계교회협의회 분류](https://www.oikoumene.org/church-families/orthodox-churches-oriental)

## 3. 개인 기록 통계의 계산·갱신 문제

아래는 실제 사용자의 계정에서 잘못된 숫자를 관측했다는 뜻이 아니라, **해당 입력 조건에서 잘못된 결과를 만드는 코드 경로**를 확인한 것이다.

### 3-01. 라운지 전체 평균 평점의 가중치 오류 — P1

`flights_lounge_stats_screen.dart`는 공항별 평균을 평가가 있는 방문으로 계산한 뒤, 전체 평균에서 평가 여부와 관계없는 `visitCount`로 가중한다. 예: 공항 A에 5점 1건+미평가 9건, B에 1점 1건이면 실제 평가 평균은 3.0이지만 코드는 `(5×10 + 1×1)/11 = 4.636…`을 낸다. 평가 건수와 점수 합을 따로 누적해야 한다.

### 3-02. 현금과 마일을 더하는 구매 순위 — P1

`purchase_stats_screen.dart`의 전체 합계는 현금/마일을 나누지만, 항공사 순위는 `purchasePrice += log.upgradePrice!`로 단위를 확인하지 않고 더한다. 현금 티켓 100 + 마일 업그레이드 10,000이면 현금 순위에 10,100이 들어갈 수 있다. 역방향 조합도 문제다. 업그레이드를 구매 방식별로 별도 귀속해야 한다.

### 3-03. 기간 밖 구간이 구매 순위 분모에 포함 — P1

같은 파일에서 여정별 그룹을 끈 경우, 가격 행은 `logsInPeriod`로 고르지만 `flightCountInPurchase`는 `allLogs.where(itineraryId 동일)`에서 계산한다. 왕복 중 한 구간만 기간 내여도 두 구간이 분모에 들어가 편당 평균이 낮아질 수 있다. 취소된 구간도 이 분모 검색에서 제외하지 않는다.

### 3-04. 항공편 수와 거리·시간의 기간 경계가 서로 다름 — P1

`FlightOverviewStatsScreen`의 거리/시간은 `logDate < startDate`를 제외하지만 `AirlineProvider._filterLogsByDate()`는 `startDate - 1일` 이후를 허용한다. 같은 Last 7 Days 카드에서 비행 횟수만 하루 앞의 기록을 더 포함할 수 있다. endDate도 +1일을 사용하므로 미래/경계 기록에서 불일치가 가능하다. 달력 날짜를 기준으로 한 포함 경계를 한 함수로 통일해야 한다.

### 3-05. All Time 평균 비행 횟수 0 — P2

`calculateFlightCountStats()`는 startDate/endDate가 둘 다 있어야 `daysInPeriod`를 계산한다. All Time 호출은 둘 다 없어 평균이 항상 0이다. 평균 토글이 제공되므로 전체 기간에서 의미 없는 0이 표시된다. 첫/마지막 유효 기록 등 명시적인 기준으로 전체 기간을 정의해야 한다.

### 3-06. 시간 분포와 개요의 duration 파서 불일치 — P1

개요 화면은 `HH:MM`, `1h30m`, 숫자 분 형식까지 해석하지만 provider의 `parseDuration()`는 공백으로 나눈 `1h 30m` 패턴만 처리한다. `01:30`은 분포/산점도에서 0이 될 수 있고, `1h30m`도 올바로 해석되지 않는다. 한 기록이 개요 총시간에는 들어가고 분포에서는 빠질 수 있다.

### 3-07. In-flight 시간대 분포가 분·시차를 무시 — P1

`getHourlyFrequencyStats(inFlight)`는 출도착 현지시각의 hour만 비교한다. 10:15→10:55는 같은 시간대인데 반복문을 한 번도 돌지 않아 비행 중 시간대 기록이 없다. 국제선은 출발지·도착지 시간대를 같은 시계처럼 비교하므로 더 큰 오차가 생긴다. UTC 기준 실제 구간을 만들고 표시 시간대 정책을 정해야 한다.

### 3-08. 취소 항공편이 환승 통계에 포함 — P1

`flight_transfer_stats_screen.dart`의 항공편 필터와 연간 그래프는 `isCanceled`를 제외하지 않는다. 개요·좌석·기종·구매 통계는 취소편을 제외하므로 동일 기간 총편수와 환승 비율이 맞지 않는다.

### 3-09. 날짜 미입력 기록의 All Time 처리 불일치 — P2

기종·좌석은 All Time에서도 날짜 해석이 되는 기록만 포함하고, 구매는 날짜 없이도 포함한다. 공항 순위는 year/month/day 중 하나라도 있어야 세지만 라운지 All Time은 날짜가 없어도 센다. ‘전체 기록’과 ‘날짜가 알려진 기록’을 구분해 설명하거나 기준을 통일해야 한다.

### 3-10. 부분 날짜를 1월 1일/1900년으로 확정해 집계 — P2

`AirportVisitEntry.date`는 없는 year=1900, month=1, day=1을 대입한다. 연도만 입력한 방문이 실제로 1월 1일에 발생한 것처럼 월·요일·기간 통계에 반영될 수 있다. 입력 정밀도를 보존하고 해당 수준에 맞는 통계에만 포함해야 한다.

### 3-11. Provider 변경 후 화면 통계가 남을 수 있음 — P2 / 조건부

항공 개요·라운지·빈도 주요 집계는 `listen:false`로 읽고 initState/didChangeDependencies에서 캐시한다. 이 집계 자체는 provider 변경을 구독하지 않는다. 다른 화면에서 기록을 편집한 뒤 같은 State가 유지되면 필터를 바꾸거나 화면을 다시 만들기 전까지 값이 남을 수 있다. 빈도 화면의 일부 하위 Consumer가 있다고 상위 캐시까지 재계산되는 것은 아니다. 실제 앱 경로에서 retained-tab/편집 후 복귀 재현 검증이 추가로 필요하다.

### 3-12. 혼합 방문 유형을 국가/도시 단위로 배제 — P2

Overview는 한 국가/도시에 환승 기록이 하나라도 있으면 `hasTransfer=true`로 보고 정상 방문국 판정에서 제외한다. 정상 관광 방문과 환승이 섞인 국가도 Transfer 스위치를 끄면 전체가 빠질 수 있다. 방문별 조건을 먼저 적용한 뒤 국가/도시로 합산해야 한다. 사용자가 ‘환승만 한 나라 제외’를 기대할 경우 통계가 달라진다.

### 3-13. 날짜·방문 필터의 적용 범위가 화면별로 다름 — P2

국가 Overview 요약의 날짜/대륙 필터와 아래 순위·산점도는 서로 다른 목록을 사용한다. 날짜를 바꿔도 순위/그래프가 모두 바뀌는 구조가 아니다. 도시 순위도 Home/Lived/Transfer/Layover 조건과 `visitCount`·총체류일에 적용되는 범위가 서로 다를 수 있다. 필터가 영향을 주는 카드 범위를 명확히 표시하고 동일 범위면 공통 필터 결과를 써야 한다.

### 3-14. 지리적 평균 중심의 경도 계산 — P2

`city_geography_screen.dart`는 경도를 산술평균한다. 경도 +179°와 -179° 도시의 중심이 날짜변경선 근처가 아니라 0°가 된다. 방문 도시의 지리적 중심을 뜻한다면 구면 평균/원형 경도 평균을 써야 한다.

### 3-15. 체류일 합산의 정의 — 검증 보류

국가·도시의 체류일은 방문 구간을 더하는 방식이다. 겹치는 방문 구간, 시간 포함 DateTime, `isDurationUnknown`과 저장된 날짜가 동시에 있는 경우 어떤 결과가 의도인지 추가 검토가 필요하다. 사용자 기록을 읽지 않았으므로 실제 중복 체류가 발생했다고 단정하지 않았다.

## 4. 출처·정의·데이터 범위 때문에 최신/정확 여부를 확정하지 못한 항목

### 4-01. 공통 메타데이터 부재 — P1

대부분 통계 파일에 source URL, observation year, release date, retrieved_at, unit, methodology, coverage가 없다. 단순한 수정일은 통계 기준 연도가 아니다. 최상위 파일 전체의 메타데이터 필드 검사 결과는 `statistics_inventory.json`에 있다.

최소한 지표마다 `source`, `referencePeriod`, `releaseDate`, `unit`, `definition`, `coverage`, `isEstimate`를 별도 manifest로 관리해야 한다. 파일 이름에 2025가 들어 있다고 2025 관측값임을 보장하지 않는다.

### 4-02. 부분 국가 목록이 세계 전체 순위처럼 보임 — P2

건강·인터넷·종교 인구·연령·경제 생산 통계 중 상당수는 10~40개국만 있다. 건강 파일 예: HIV 10국, 병상 10국, 의사 급여 10국, 알츠하이머 18국, 성비 40국. 경제 trivia 32개 지표도 각각 10국이다. 다른 나라의 값이 없어 ‘기록된 나라 중 상위’만 계산할 수 있다. 원래 상위 10개를 수집한 경우라도 출처와 선정 시점 없이는 최신 세계 상위 10개임을 확인할 수 없다.

### 4-03. 건강 지표의 정의 — P2

HIV의 연령대, 암 ASR의 표준인구/비흑색종 피부암 포함 여부, 알츠하이머의 유병률/발생률, 백신의 1회/기초접종/추가접종, 의사 급여의 고용형태/PPP/환율, 학력의 연령대가 없다. `health.json`의 암 2022와 음주 2019는 과거 기준임이 파일 안에만 있고 화면에는 숨겨진다. 2019 자료 자체를 틀렸다고 판정하지는 않았다. 출처 정의를 고정한 뒤 갱신해야 한다.

### 4-04. 소셜미디어·인터넷 — P2

Facebook/Instagram/YouTube 수치가 광고 도달 가능 인구인지 실제 월간 사용자 수인지 구분되지 않는다. 인터넷 속도는 `internet_speed_legacy`로 고정돼 있지만 모바일/고정망, 평균/중앙값, 월이 없다. 사용자 수와 보급률도 동일 연도라고 확인할 수 없다. YouTube 절대 인원을 백만 단위로 나누는 코드 자체는 확인했으며 그 변환은 일관적이다.

### 4-05. 연령·키·비만·IQ·탈모 — 검증 보류

중위연령, 초혼연령, 첫출산연령의 성별·분모·기준연도, 키의 출생 코호트, 비만의 성인/연령표준화/BMI 기준, IQ 및 탈모의 표본·측정 방법·출처가 없다. 국가 간 비교 가능성부터 검증해야 한다. 숫자에 소수점이 많다는 이유로 정밀한 공식 통계로 볼 수 없다.

### 4-06. 지리·기후 값과 누락 0 처리 — P2

해안선 길이는 측정 축척, 섬과 호수는 최소 크기·계수 방식, 평균 기온/강수량은 기후평년 기간이 필요하다. 국가를 하나의 Köppen 주기후 코드로 분류하는 기준도 없다. 평균기후는 반드시 2026 단년도 값으로 바꿔야 하는 지표가 아니다.

Mauritius와 Seychelles는 기후 데이터가 아예 없고 provider가 0으로 바꾼다. 일부 국가/속령의 위도·면적·인구도 누락 → 0이다. 0은 실제 값일 수도 있어 null/N/A와 구분해야 한다. 저위도·낮은 고도 순위에는 이런 기본값이 들어갈 수 있다. 다만 남극 등 화면에서 제거되는 지형도 있으므로 원본 지도와의 차이를 전부 사용자 오류로 세지 않았다.

### 4-07. 면적과 영토 합산 정책 — P2

육지면적/수면 포함 총면적/해외영토 포함 여부가 다르다. Somalia 637,657km²와 Somaliland 176,120km²를 별도로 더하면 영역이 중첩된다. 프랑스의 인구가 해외영토를 이미 포함하는 시점 자료인지 확인하지 않고 별도 영토 인구를 더하면 중복 가능성이 있다. 현재 territory merge는 인구·면적은 더하지만, GDP 화면은 필터링만 해 빠진 영토 GDP를 합치지 않는다. 인구·면적·경제 카드의 국가 범위가 같아야 한다.

### 4-08. 도시 인구·GDP·관광객 — P1/P2

도쿄·뉴욕·파리 등의 도시권 인구와 서울·San Francisco 등의 행정시 인구가 혼재한다. 더구나 병합 후 `cities15000` 인구가 `cities.json` 인구를 덮어쓰므로 도시 GDP의 공간 범위와도 어긋날 수 있다. 런던 annualVisitors 210,000 같은 값은 출처·연도·관광객 정의를 재확인해야 하지만, 비교 대상을 정하지 않고 ‘정답’을 임의로 덮어쓰지는 않았다.

### 4-09. 도시 가격·안전·살인율·지하철·초고층 건물·CCTV — P2

가격은 고급주택/전체 주택/㎡ 단위 여부, 안전은 체감지수/공식범죄, 도시 살인율은 행정구역과 연도, 지하철역은 환승역 중복·노선 범위, 초고층 건물은 높이 기준·완공 상태가 빠져 있다. CCTV의 117.0 등은 대수인지 인구당 지표인지 불명확한데 모델은 integer count로 반올림한다. 정확한 정의를 확인하기 전에는 이를 카메라 절대 대수로 해석하면 안 된다. QS Student Cities와 Liveability는 각 판 전체 표의 별도 대조가 필요하다.

### 4-10. 경제 생산·광물·차량·휴대폰·비트코인·외환 — P2

`economics_trivia.json`의 32개 지표 모두 출처/연도가 없다. 쌀은 정곡/벼, 우유는 축종 포함 범위, 육류는 도체중/소매중량, 차량은 승용차/상용차 포함, 광물은 광산 생산/제련, 가스는 달력연도/단위 기준이 필요하다. Bitcoin Ownership은 일반 암호자산 보유율과 혼동하지 않아야 하며, USD Reserves는 달러 자산만인지 미 달러로 표시한 전체 외환보유액인지 확인해야 한다. FAOSTAT·USGS·EIA·OICA 등 정의가 맞는 원자료로 지표별 재구축이 필요하다.

### 4-11. 군사 자산·핵무기·금 — P2

항공모함 20 등은 헬기/강습상륙함 포함 여부, 병력은 현역/예비군/준군사조직 포함 여부, 군함·전차·항공기는 보유/운용 가능/재고 여부가 없다. 세계은행 병력은 오래된 관측치와 준군사 포함 범위가 섞여 있을 수 있어 차이를 최신 오류로 단정하지 않았다.

핵무기는 총재고/군사비축/배치 탄두를 구분해야 한다. SIPRI는 2026-01 자료를 공개했지만 앱의 기준일이 없어 전체 9개국 수치를 같은 정의로 재검증해야 한다. 금 보유는 월별 갱신 지표이며 WGC의 다운로드·필터 기능은 로그인 제한이 있었다. 원표 전체 대조는 완료하지 않았다. [SIPRI 2026](https://www.sipri.org/media/press-release/2026/increasing-focus-nuclear-weapons-amid-heightened-escalation-risks-new-sipri-yearbook-out-now), [WGC 금 보유 자료](https://www.gold.org/goldhub/data/gold-reserves-by-country)

### 4-12. 법·정책 국가 분류 — P2

안락사와 조력자살, 낙태와 임신주수 제한, 성매매의 구매/판매/알선, 대마의 의료용/소지/재배/상업 판매, 무상대학의 국적/거주/과정별 조건을 분리해야 한다. 현재 한 나라를 한 범주에 넣는 방식으로는 정확성을 보장하기 어렵다. 사형 분류의 Zimbabwe는 2024년 폐지 변화를 재검토해야 한다. 여성 지도자도 ‘current/recent’ 기간과 대통령/총리/총독 등의 포함 기준이 없다. 이 표 전체의 각국 법률 대조를 끝냈다고 표시하지 않았다.

### 4-13. 종교 인구·노벨상·역사 통계 — P2

종교 인구는 자기정체성/의례 참여/등록 여부에 따라 달라지고, 일부 국가만 있다. 현재 교황 수 자료에는 미국 1이 있어 2025년 이후 변화 일부가 반영돼 있지만 살아 있는 추기경 수 전체의 기준일은 없다. 노벨상 국가별 수는 출생국/수상 당시 국적/소속/중복 수상 기준을 정해야 한다. YUG/TIB처럼 현 지도와 연결되지 않는 항목도 있다. 전쟁 사상자에서 소련 전체 피해를 현대 Russia 한 나라에 배정하는 방식도 별도 정의가 필요하다.

### 4-14. 추천 순위와 객관적 순위 혼재 — P2

도시·박물관·회화·오케스트라·광장·랜드마크 global/local rank에는 객관적인 선정 출처와 기준일이 없는 목록이 있다. 큐레이션이라면 그렇게 표시해야 한다. 강 길이는 본류/수계, 호수 면적은 연결호수 취급과 수위, 조각상은 받침대, 교량은 연속구조물 범위에 따라 순위가 달라진다. 가장 높은 건물 등도 완공된 구조물 기준을 표시해야 한다.

## 5. 업데이트 경로와 검사에서 확인한 정상 항목

- 국가 인구·경제·건강·군사, 도시별 테마 자료, UNESCO, 항공 순위는 `rootBundle.loadString()`으로 읽는다. 공식 사이트 변경만으로 자동 갱신되지 않는다.
- 예외적으로 `cities15000.json`은 공개 Firebase Storage와 SharedPreferences 캐시 경로가 있다. 현재 서버 **31,479행**, 번들 **32,870행**이며 파싱 결과가 다르다. 번들에는 완전히 같은 행의 추가 중복이 **1,386행** 있으나 서버에는 0행이다. 따라서 도시 중복 문제를 모든 설치 상태에서 발생한다고 단정하면 안 된다. 서버에서도 1-06의 이름 병합 문제는 남아 있다.
- HDI 공식 비교 가능 193개국은 전부 UNDP 2025판의 2023 관측값과 일치했다. ‘최신 보고서=2025, 관측연도=2023’ 둘 다 적어야 한다. [UNDP 다운로드](https://hdr.undp.org/data-center/documentation-and-downloads)
- 현재 코드의 NATO 32, EU 27, Schengen 29, OECD 38 목록 크기는 확인했다. 이는 이번 검사에서 가입 누락 증거가 발견된 ASEAN/SCO/BRICS와 구분한다. 전체 법적 지위·이후 변동을 독립적으로 인증했다는 의미는 아니다.
- 랜드마크 global_rank/local_rank/city_rank가 가리키는 이름은 현재 DB에 모두 존재했다. 교량 Top Picks의 별도 하드코딩 목록과는 경로가 다르다.
- 공항 데이터의 비어 있지 않은 IATA는 중복이 없었다. 항공사 IATA 코드는 **264종이 중복**되지만, 역사적 코드 재사용·동일 그룹·별도 법인도 있어 중복만으로 데이터 오류라고 단정하지 않았다. 이름과 코드로 과거/현재 항공사를 구분하는 정책이 필요하다.
- `ddad.json`은 JSON 파싱 오류지만 앱에서 직접 참조되거나 pubspec에 등록된 통계 자료는 아니어서 실행 중 통계 장애로 분류하지 않았다.
- `ActivityStatsScreen`, `FlightRecordsStatsScreen`에는 구현되지 않은 화면이 있다. 통계가 0인 것과 미구현 상태를 구분해야 한다.

## 6. 수정 순서

1. **잘못된 연결과 계산부터**: 올림픽 국가 코드·중복, 도시 국가별 식별자 병합, MLS 복사본, Millionaires 정의, 살인율/군사력 충돌, 라운지 가중평균, 현금/마일 혼합.
2. **확정된 누락 갱신**: UNESCO, 항공 순위, 국제기구·승인국, WBC, 카자흐스탄 시간대, 일본 섬 개수, 대학 순위, 세금 분류.
3. **출처 manifest 정립 후 일괄 재수집**: GDP/인구/1인당 GDP를 같은 판으로, 도시권 정의 통일, 건강·경제생산·소셜미디어·군사 자산의 분모와 단위 확정.
4. **재발 방지 검사**: 국가 코드 유효성, 통계 ID 유일성, 순위와 숫자 정렬 일치, 필수 메타데이터, source별 갱신 주기, null과 0 구분, 사용자 기록의 날짜/취소/필터 공통화.

## 7. 재현 방법과 남은 한계

리포지토리 루트에서:

```powershell
python tool/audit_statistics.py
python tool/compare_statistics_worldbank.py
python tool/audit_statistics_sources.py
python tool/statistics_review_coverage.py
```

첫 스크립트는 로컬 구조 검사, 두 번째는 저장된 원자료를 사용하거나 없으면 세계은행 공개 API 조회, 세 번째는 이번에 저장한 공식 자료 스냅샷과의 비교, 네 번째는 파일별 검증 범위 목록 생성이다. 앱 원본 데이터를 바꾸지 않는다. 원자료는 `audit/sources/`에 보존했다.

이번 검증은 소스·데이터 감사와 수치 대조이며, 실제 기기에서 모든 화면을 열어 사용자 계정 데이터로 UI 재현한 검사는 아니다. 공식 관측치가 없는 219개 비교 행, 동적/로그인 제한 자료, 출처가 불명확한 지표, 기준 정의가 다른 자료는 명시적으로 보류했다. 세계은행 `closest_historical_year`는 가장 가까운 수치를 찾은 진단값일 뿐 원본의 실제 기준 연도를 뜻하지 않는다.

추가로 GFCI CSV 다운로드 1건은 자동 승인 검토가 사용량 한도로 완료되지 않아 실행되지 않았다. 이는 자료가 위험하다는 판정이 아니며, 해당 원표 전체의 검증은 보류했다.
