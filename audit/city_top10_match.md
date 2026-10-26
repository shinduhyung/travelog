# 도시 통계 상위 10개와 cities15000 매칭 확인

Eurostat 도시 코드 → GISCO 도시 중심점 → `assets/cities15000.json`(같은 국가, 10km 이내) 순으로 대응시켰습니다.
근거는 국가, 거리, 이름, 인구(Eurostat urb_cpopcb vs cities15000)이며 상태는 아래와 같습니다.

- exact: 같은 국가 40km 이내에 이름이 같은 항목이 하나(또는 인구 3배 이상 우세한 하나)
- name_similar: 20km 이내에 철자가 비슷한 항목이 하나(Lisboa/Lisbon, Veliko Tarnovo/Tŭrnovo 등)
- coords_only: 이름은 다르지만 5km 이내에 다른 후보 없이 하나(Eivissa/Ibiza 등)
- coords_name_diff: 이름은 다르지만 15km 이내에서 인구가 압도적인 항목 하나(영어/현지어 표기 차이 등)
- name_only: 좌표 파일에 없는 국가(IS, UK)라 같은 국가의 같은 이름으로만 대응
- name_only_far_label: GISCO 중심점이 실제 도시와 멀어서 같은 국가의 같은 이름으로만 대응(오슬로 등)
- ambiguous: 후보가 여러 개라 하나로 못 정함 (후보를 같이 표시)
- +pop_check: 위 판정이 났지만 인구가 3배 넘게 달라 눈으로 확인 필요(Eurostat 도시 범위 차이일 수 있음)
- no_match / no_coordinates: 대응 없음

## 극장 수 (2025, Eurostat 79개 도시, 단위 개)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | FR001C Paris (greater city) | 353.0 | Paris (FR) | 3.3 | 2,050,000 / 10,159,710 | exact+pop_check |
| 2 | FR002C Lyon (greater city) | 38.0 | Lyon (FR) | 2.3 | 522,969 / 1,229,077 | exact |
| 3 | FR006C Toulouse (greater city) | 29.0 | Toulouse (FR) | 3.3 | 493,465 / 716,000 | exact |
| 4 | FR003C Lille (greater city) | 28.0 | Lille (FR) | 3.0 | 234,475 / 937,308 | exact+pop_check |
| 5 | FR005C Bordeaux (greater city) | 28.0 | Bordeaux (FR) | 6.1 | 260,958 / 746,217 | exact |
| 6 | FR004C Marseille (greater city) | 23.0 | Marseille (FR) | 6.3 | 870,731 / 973,249 | exact |
| 7 | FR009C Strasbourg (greater city) | 18.0 | Strasbourg (FR) | 1.8 | 274,845 / 432,797 | exact |
| 8 | FR012C Grenoble (greater city) | 15.0 | Grenoble (FR) | 1.1 | 158,552 / 329,369 | exact |
| 9 | FR011C Montpellier (greater city) | 14.0 | Montpellier (FR) | 2.6 | 248,252 / 374,347 | exact |
| 10 | FR043C Avignon (greater city) | 13.0 | Avignon (FR) | 3.0 | 89,769 / 110,574 | exact |

## 공공도서관 수 (2024, Eurostat 375개 도시, 단위 개)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | FR001C Paris (greater city) | 516.0 | Paris (FR) | 3.3 | 2,050,000 / 10,159,710 | exact+pop_check |
| 2 | HR001C Zagreb | 340.0 | Zagreb (HR) | 1.8 | 663,592 / 760,020 | exact |
| 3 | PL001C Warszawa | 249.0 | Warsaw (PL) | 2.4 | 1,702,139 / 1,863,845 | name_similar |
| 4 | HU001C Budapest (greater city) | 240.0 | Budapest (HU) | 4.7 | 1,741,041 / 1,686,222 | exact |
| 5 | ES001C Madrid (greater city) | 107.0 | Madrid (ES) | 3.0 | 3,255,944 / 4,501,429 | exact |
| 6 | ES002C Barcelona (greater city) | 74.0 | Barcelona (ES) | 3.1 | 1,620,343 / 2,658,830 | exact |
| 7 | BE001C Bruxelles/Brussel (greater city) | 67.0 | Brussels (BE) | 0.8 | 1,019,022 / 1,271,709 | name_similar |
| 8 | PL002C Łódź | 67.0 | Łódź (PL) | 0.6 | 768,755 / 645,693 | exact |
| 9 | ES003C Valencia (greater city) | 66.0 | Valencia (ES) | 5.6 | 825,948 / 1,474,632 | exact |
| 10 | PL003C Kraków | 65.0 | Kraków (PL) | 3.6 | 755,050 / 809,168 | exact |

## 주민 1명당 관광숙박일수 (2025, Eurostat 89개 도시, 단위 일)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | IT011C Venezia | 51.81 | Mestre (IT) | 1.8 | 147,662 / 249,490 | manual_override |
| 2 | IT071C Rimini | 47.68 | Rimini (IT) | 3.5 | 148,688 / 150,333 | exact |
| 3 | IT007C Firenze | 31.84 | Florence (IT) | 0.1 | 367,150 / 361,705 | coords_only |
| 4 | IT040C Pisa | 25.14 | Pisa (IT) | 5.7 | 109,960 / 89,422 | exact |
| 5 | IT069C Ravenna | 20.0 | Ravenna (IT) | 0.6 | 80,868 / 156,340 | exact |
| 6 | IT001C Roma | 18.34 | Rome (IT) | 10.8 | 2,318,895 / 2,747,290 | coords_name_diff |
| 7 | IT039C Como | 17.13 | Como (IT) | 1.5 | 84,808 / 83,135 | exact |
| 8 | IT081C Grosseto | 14.66 | Grosseto (IT) | 1.6 | 60,922 / 81,264 | exact |
| 9 | IT009C Bologna | 13.43 | Bologna (IT) | 0.6 | 394,843 / 390,151 | exact |
| 10 | IT012C Verona | 12.94 | Verona (IT) | 1.3 | 258,031 / 255,039 | exact |

## 도심행 주간 택시 5km 요금 (2025, Eurostat 94개 도시, 단위 EUR)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | BE015C Verviers (greater city) | 19.38 | Verviers (BE) | 0.7 | 52,824 / 71,935 | exact |
| 2 | BE001C Bruxelles/Brussel (greater city) | 19.1 | Brussels (BE) | 0.8 | 1,019,022 / 1,271,709 | name_similar |
| 3 | BE005C Liège (greater city) | 18.88 | Liège (BE) | 1.1 | 195,278 / 412,835 | exact |
| 4 | BE007C Namur | 18.75 | Namur (BE) | 0.8 | 110,939 / 116,605 | exact |
| 5 | BE009C Mons (greater city) | 18.75 | Mons (BE) | 1.6 | 95,299 / 158,867 | exact |
| 6 | BE013C Mouscron | 18.75 | Mouscron (BE) | 3.3 | 52,069 / 61,242 | exact |
| 7 | BE004C Charleroi (greater city) | 17.88 | Charleroi (BE) | 1.3 | 200,132 / 242,973 | exact |
| 8 | BE014C La Louvière (greater city) | 17.58 | La Louvière (BE) | 1.3 | 76,668 / 106,050 | exact |
| 9 | BE006C Brugge | 17.33 | Bruges (BE) | 6.3 | 118,509 / 120,693 | name_similar |
| 10 | BE010C Kortrijk (greater city) | 17.33 | Kortrijk (BE) | 1.1 | 73,879 / 80,961 | exact |
| 11 | BE011C Oostende (greater city) | 17.33 | Ostend (BE) | 0.9 | 69,011 / 73,187 | name_similar |

## 아파트 평균 매매가격 (2024, Eurostat 252개 도시, 단위 EUR)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | ES089C Eivissa | 543,700.0 | Ibiza (ES) | 1.3 | 48,684 / 53,228 | coords_only |
| 2 | ES109C Las Rozas de Madrid (greater city) | 442,553.0 | Las Rozas de Madrid (ES) | 1.9 | 95,550 / 172,740 | exact |
| 3 | ES063C San Sebastián/Donostia (greater city) | 409,451.0 | Donostia / San Sebastián (ES) | 1.0 | 185,357 / 250,056 | coords_name_diff |
| 4 | PT004C Funchal (greater city) | 394,589.44 | Funchal (PT) | 1.6 | 100,847 / 108,129 | exact |
| 5 | FR001C Paris (greater city) | 355,475.0 | Paris (FR) | 3.3 | 2,050,000 / 10,159,710 | exact+pop_check |
| 6 | ES001C Madrid (greater city) | 354,705.0 | Madrid (ES) | 3.0 | 3,255,944 / 4,501,429 | exact |
| 7 | ES010C Palma de Mallorca | 324,028.0 | Palma (ES) | 10.9 | 409,661 / 438,234 | coords_name_diff |
| 8 | PT001C Lisboa (greater city) | 323,965.26 | Lisbon (PT) | 9.4 | 517,802 / 1,965,363 | name_similar+pop_check |
| 9 | BE003C Gent | 323,371.0 | Gent (BE) | 2.8 | 265,086 / 273,394 | exact |
| 10 | FR038C Annecy (greater city) | 323,208.0 | Annecy (FR) | 1.3 | 49,232 / 141,408 | exact |

## 남성 100명당 여성 수 (2025, Eurostat 303개 도시, 단위 명)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | EE003C Narva | 121.5 | Narva (EE) | 5.4 | 54,409 / 52,495 | exact |
| 2 | EE002C Tartu | 114.5 | Tartu (EE) | 6.1 | 91,407 / 100,685 | exact |
| 3 | BG010C Dobrich | 114.2 | Dobrich (BG) | 2.7 | 79,269 / 69,434 | exact |
| 4 | EE001C Tallinn | 114.1 | Tallinn (EE) | 3.6 | 394,024 / 456,518 | exact |
| 5 | PT005C Coimbra (greater city) | 113.5 | Coimbra (PT) | 2.5 | 106,582 / 146,899 | exact |
| 6 | PT004C Funchal (greater city) | 113.3 | Funchal (PT) | 1.6 | 100,847 / 108,129 | exact |
| 7 | PT001C Lisboa (greater city) | 113.0 | Lisbon (PT) | 9.4 | 517,802 / 1,965,363 | name_similar+pop_check |
| 8 | BG017C Veliko Tarnovo | 112.8 | Veliko Tŭrnovo (BG) | 15.2 | 66,217 / 77,049 | name_similar |
| 9 | BG002C Plovdiv | 112.6 | Plovdiv (BG) | 1.2 | 346,893 / 329,489 | exact |
| 10 | BG005C Pleven | 112.3 | Pleven (BG) | 5.3 | 100,952 / 109,080 | exact |
| 11 | IT031C Salerno | 112.3 | Salerno (IT) | 1.8 | 125,797 / 126,000 | exact |

## 실업률 (2024, Eurostat 230개 도시, 단위 %)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | ES051C Línea de la Concepción, La | 28.6 | La Línea de la Concepción (ES) | 3.8 | 64,595 / 64,987 | exact |
| 2 | ES090C Linares | 27.59 | Linares (ES) | 0.1 | 61,338 / 55,303 | exact |
| 3 | ES045C Melilla | 26.51 | Melilla (ES) | 1.2 | 85,985 / 85,985 | exact |
| 4 | ES039C Ceuta | 26.27 | Ceuta (ES) | 3.2 | 83,179 / 83,179 | exact |
| 5 | ES059C Granada (greater city) | 23.13 | Granada (ES) | 10.7 | 234,325 / 333,545 | exact |
| 6 | ES079C Algeciras | 22.6 | Algeciras (ES) | 3.9 | 116,209 / 125,047 | exact |
| 7 | ES062C Jerez de la Frontera | 21.8 | Jerez de la Frontera (ES) | 4.6 | 207,532 / 214,844 | exact |
| 8 | ES100C Armilla (greater city) | 21.74 | Armilla (ES) | 5.2 | 21,380 / 65,548 | exact+pop_check |
| 9 | ES074C Jaén | 21.71 | Jaén (ES) | 5.4 | 113,457 / 111,945 | exact |
| 10 | ES035C Talavera de la Reina | 20.82 | Talavera de la Reina (ES) | 1.9 | 88,856 / 85,138 | exact |

## 밤에 혼자 걸어도 안전하다는 응답률 (2023, Eurostat 80개 도시, 단위 %)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | DK001C København (greater city) | 86.5 | Copenhagen (DK) | 5.8 | 1,153,615 / 559,440 | coords_name_diff |
| 2 | ES013C Oviedo | 85.3 | Oviedo (ES) | 3.1 | 220,020 / 220,027 | exact |
| 3 | SI001C Ljubljana | 85.2 | Ljubljana (SI) | 2.3 | 272,220 / 297,575 | exact |
| 4 | CH002C Zurich (greater city) | 84.2 | Zurich (CH) | 3.1 | 415,367 / 725,893 | exact |
| 5 | NL018C Groningen | 83.9 | Groningen (NL) | 3.6 | 238,147 / 243,768 | exact |
| 6 | PL011C Białystok | 83.5 | Białystok (PL) | 0.4 | 291,855 / 290,386 | exact |
| 7 | DK004C Aalborg | 83.3 | Aalborg (DK) | 9.6 | 142,937 / 203,448 | exact |
| 8 | PT003C Braga (greater city) | 83.1 | Braga (PT) | 0.7 | 121,394 / 203,519 | exact |
| 9 | LU001C Luxembourg (greater city) | 81.9 | Luxembourg (LU) | 1.1 | 76,684 / 115,227 | exact |
| 10 | FI004C Oulu/Uleåborg | 81.5 | Oulu (FI) | 28.2 | 209,648 / 216,152 | exact |

## 성소수자가 살기 좋다는 응답률 (2023, Eurostat 80개 도시, 단위 %)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | IS001C Reykjavík | 89.4 | Reykjavík (IS) | None | 118,918 / - | name_only |
| 2 | MT001C Greater Valletta | 87.9 | Valletta (MT) | 3.5 | 6,794 / 466,066 | exact+pop_check |
| 3 | NL018C Groningen | 86.9 | Groningen (NL) | 3.6 | 238,147 / 243,768 | exact |
| 4 | CH002C Zurich (greater city) | 86.9 | Zurich (CH) | 3.1 | 415,367 / 725,893 | exact |
| 5 | DK001C København (greater city) | 86.4 | Copenhagen (DK) | 5.8 | 1,153,615 / 559,440 | coords_name_diff |
| 6 | ES006C Málaga | 85.9 | Málaga (ES) | 5.3 | 578,460 / 592,346 | exact |
| 7 | LU001C Luxembourg (greater city) | 85.5 | Luxembourg (LU) | 1.1 | 76,684 / 115,227 | exact |
| 8 | IT009C Bologna | 85.3 | Bologna (IT) | 0.6 | 394,843 / 390,151 | exact |
| 9 | NO001C Oslo (greater city) | 85.1 | Oslo (NO) | 123.1 | 1,082,575 / 699,827 | name_only_far_label |
| 10 | DE002C Hamburg | 84.8 | Hamburg (DE) | 2.3 | 1,845,229 / 1,862,565 | exact |

## 이민자가 살기 좋다는 응답률 (2023, Eurostat 80개 도시, 단위 %)

| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |
|---|---|---:|---|---:|---|---|
| 1 | PT003C Braga (greater city) | 86.4 | Braga (PT) | 0.7 | 121,394 / 203,519 | exact |
| 2 | UK009C Cardiff | 85.5 | Cardiff (GB) | None | 372,089 / 363,502 | name_only |
| 3 | PT001C Lisboa (greater city) | 84.3 | Lisbon (PT) | 9.4 | 517,802 / 1,965,363 | name_similar+pop_check |
| 4 | PL006C Gdańsk | 83.3 | Gdańsk (PL) | 1.2 | 461,865 / 488,651 | exact |
| 5 | ES013C Oviedo | 82.9 | Oviedo (ES) | 3.1 | 220,020 / 220,027 | exact |
| 6 | ES002C Barcelona (greater city) | 80.8 | Barcelona (ES) | 3.1 | 1,620,343 / 2,658,830 | exact |
| 7 | ES006C Málaga | 80.2 | Málaga (ES) | 5.3 | 578,460 / 592,346 | exact |
| 8 | DE002C Hamburg | 80.1 | Hamburg (DE) | 2.3 | 1,845,229 / 1,862,565 | exact |
| 9 | IE001C Dublin (greater city) | 79.7 | Dublin (IE) | 3.6 | 1,024,027 / 1,325,700 | exact |
| 10 | LU001C Luxembourg (greater city) | 78.8 | Luxembourg (LU) | 1.1 | 76,684 / 115,227 | exact |
| 11 | AT002C Graz | 78.8 | Graz (AT) | 1.3 | 303,270 / 269,997 | exact |

## 상태 요약

- coords_name_diff: 5
- coords_only: 2
- exact: 77
- exact+pop_check: 6
- manual_override: 1
- name_only: 2
- name_only_far_label: 1
- name_similar: 6
- name_similar+pop_check: 3