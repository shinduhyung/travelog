# 랜드마크 전수조사 (Cultural + Natural) — 2026-11-24

대상: `assets/all_landmarks.json` 중 Cultural Wonders(27개 속성) 또는 Natural Wonders(15개 속성)에 속하는 **5,817개**
방법: ① 스크립트 검사(좌표↔국가 폴리곤, 도시 거리, 중복, 빈 필드, 이름 키워드↔속성) ② 6분할 모델 검토(속성 오분류·국가·좌표·오타). 아래는 확인을 거친 항목만 정리했습니다. `idx`는 JSON 배열 인덱스입니다.

## A. 데이터 깨짐 (확실)
| idx | 이름 | 문제 | 수정안 |
|---|---|---|---|
| 1955 | Öresund Bridge | latitude = null | 55.5724 |
| 8768 | Lake Vostok | iso `"Antarctica"` (코드 아님) | `ATA` |
| 8731 | Yosemite National Park | overview 비어있음 | 작성 필요 |
| 8732 | Yellowstone National Park | overview 비어있음 | 작성 필요 |
| 8387 | Gulf of Guinea | 좌표 0,0 (앱에서 '좌표 없음'으로 취급될 수 있음) | 예: 2.0, 4.0 |
| 1114 | "Nijmeh Square " | 이름 끝 공백 | 공백 제거 |
| 254, 8367, 8424, 8562, 8631 | — | overview/highlights 공백 이상 | trim |

## B. 국가 코드 오류
| idx | 이름 | 현재 | 수정 |
|---|---|---|---|
| 7356, 7377, 7389, 7401, 7409 | 홍콩 대학 5곳 (HKU, CUHK, HKUST, CityU, PolyU) | CHN | HKG (다른 홍콩 항목은 전부 HKG) |
| 7643 | Saint Helena | GBR | 다른 영국령(PCN, TCA)처럼 별도 코드 쓸지 결정 (SHN은 앱 국가목록에 없음) |

## C. 좌표 오류
| idx | 이름 | 현재 | 실제 근사 |
|---|---|---|---|
| 8754 | Vishwas Swaroopam | 23.18, 72.65 (간디나가르) | 24.94, 73.82 (나트드와라) |
| 8759 | Dai Kannon of Kita no Miyako Park | 42.32, 140.99 (홋카이도 남부) | 43.50, 142.17 (아시베츠) |
| 216 | Thien Hau Temple (HCMC) | 10.98, 106.65 (빈즈엉) | 10.7527, 106.6615 (쩌런) |
| 837 | Sonargaon | 23.75, 90.38 (다카 시내) | 23.65, 90.60 — city도 Sonargaon |
| 5658 | Sanhe Ancient Town | 허페이 시내 좌표 복붙 | 31.68, 117.17 |
| 3444 | Lagos Island waterfront | 6.58, 3.75 (~40km 동쪽) | 6.45, 3.40 |
| 3747 | Johnny Cash Museum | 36.33, -86.57 | 36.1617, -86.7763 |
| 8553 | Simien Lava Desert | 다나킬 좌표인데 이름은 시미엔 | 이름/위치 불일치 → 삭제 또는 개명 |

## D. 중복 (같은 장소)
| 남길 것 | 삭제/병합 대상 |
|---|---|
| 3614 Capilano Suspension Bridge | 8815 (완전 동일) |
| 8600 Cape of Good Hope | 8783 (완전 동일) |
| 8602 Death Valley | 8784 (완전 동일) |
| 2808 Lujan Basilica | 1227 Basilica de Lujan |
| 3653 Thomas Jefferson Memorial | 3675 Jefferson Memorial (3653의 Museum 태그도 제거) |
| 2138 Central Market Hall | 2147 Great Market Hall (부다페스트) |
| 2320 Arbat Street | 2330 Old Arbat Street |
| 2174 Village Museum | 2169 Muzeul Național al Satului (좌표 동일) |
| 3891 Museo Ixchel | 3905 Ixchel Museum of Indigenous Textiles |
| 1508 Archiginnasio of Bologna | 1426 Palazzo dell'Archiginnasio anatomical theatre |
| 2095 Golden Roof | 2099 "Golden Hall" (실존 별도 명소 아님) |
| 309 Drum and Bell Towers | 251 Drum Tower |
| 544 Binondo Chinatown | 554 Binondo |
| 628 Eureka Tower | 600 Melbourne Skydeck |
| 7617 Socotra (Island) | 8687 Socotra Island (Unique Landscape) — 의도적 중복인지 확인 |
| 7316 Mount Bromo | 8635 Mount Bromo Caldera — 동일 좌표, 의도 확인 |

애매(별도 유지 가능): 2250 Lavra Caves↔2255 Lavra, 2154 Motherland Calls↔2376 Mamayev Kurgan, 3027 Serapeum↔3003 Pompey's Pillar.

## E. 속성(카테고리) 오류
**엉뚱한 `Other Religion` 태그 (확실한 실수)**
- 5638 Charlotte Motor Speedway, 3283 Champ de Mars Racecourse, 2205 Multimedia Fountain Park, 1204 Mirror House → Other Religion 제거
- 4005 Basílica de Suyapa → Christian만
- 2037 Hill of Crosses → Christian
- 765 Varanasi Ghats → Hindu (+River)
- 39 Samneung Park (왕릉) → Tomb

**태그 틀림/누락**
| idx | 이름 | 현재 | 수정 |
|---|---|---|---|
| 8335 | Lake Peigneur | Falls | Lake |
| 2335 | Hermitage Museum | Palace | Palace + Museum |
| 2861, 2913 | 베네수엘라/파라과이 Panteón Nacional | Palace | Tomb |
| 758 | Rani ki Vav (계단식 우물) | Tomb | Ancient Site (+Hindu) |
| 841 | Jatiyo Sangsad Bhaban | Palace | Modern Architecture |
| 1817 | Römerberg | Palace | Historical Square |
| 3201 | Arch 22 | Tower | Gate |
| 3282 | Citadel Fort Adelaide | Ancient Site, Tower | Castle |
| 8561 | Špania Dolina | Cave | Traditional Village |
| 8858 | Colorado State Capitol | Palace | Modern History 등 |
| 238, 294, 322, 1555, 2454, 3978 | 카이딘 황릉, 중산릉, 공림, 페르 라셰즈, 미로고이, 산타 이피헤니아 | Tomb 누락 | +Tomb |
| 2627 | Philippi | Christian만 | +Ancient Site |
| 2153 | Victoria Peak | Park | +Mountain |
| 410 | Wat Phou | Ancient Site | +Hindu/Buddhist |
| 8846 | Twin Pagoda Temple | Tower | +Buddhist |
| 2520 | Mezquita-Cathedral of Córdoba | Islamic | +Christian (Hagia Sophia와 동일 처리) |
| 7292 | Mount Roraima | Canyon 포함 | Canyon 제거 (낮은 확신) |

## F. 이름 오타
- 2529 "Plaza Mayor, Salamance" → Salamanca
- 1850 "Wieskyrche" → Wieskirche
- 638 "Parliament Haus" → Parliament House
- 8095 "Sogne River" → Sognefjord (River 아님, Sea/Unique Landscape)

## G. city 필드 (경미)
- 2021 Rundāle Palace: Riga → Pilsrundāle/Bauska
- 3708 Harvard Square: Boston → Cambridge

## 오류 아님으로 판정한 것
- 바다·섬·해변 약 110건이 "국가 폴리곤 밖": 지도 폴리곤 해상도 문제(바다 중심점, 작은 섬). 정상.
- 예루살렘/키프로스 북부/바티칸/국경 근처 명소 등 폴리곤 경계 차이: 앱 정책대로라 정상.
- 도시 거리 오탐 대부분: 같은 이름 다른 도시(미국 Nara 등)나 city에 주/섬 이름(Bali, Oregon) 사용.

## 반영 결과 (2026-11-24)
- `all_landmarks.json`: 62개 수정, 중복 15개 삭제(Simien Lava Desert 포함) → 대상 5,802개. 수정한 줄만 바뀌고 나머지 서식은 그대로입니다.
- `lib/utils/landmark_aliases.dart`: 삭제·개명된 이름 17개를 별칭으로 추가해 기존 방문/위시리스트/평점 기록을 유지합니다.
- 옛 이름 갱신: city_search_keywords, city_tour_links, city_rank, social/landmarks, traveler_type/*, user_rankings.
- Firebase `new_countrydex/`: 개명한 4개 이미지를 새 이름으로 복사(기존 파일 유지)했고, 4개 모두 200 응답을 확인했습니다.
- 반영 안 함(결정 필요): Saint Helena의 GBR 코드, Socotra·Mount Bromo 이중 등재.
- 범위 밖 발견: `Walt Disney World Resort` 이름 중복(Amusement Park 항목).
