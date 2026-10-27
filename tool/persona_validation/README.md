# 여행자 타입 오프라인 검증

프로젝트 루트에서 실행합니다. Python 표준 라이브러리와 설치된 Dart SDK를 사용하며, AI API나 네트워크를 호출하지 않습니다.

```powershell
python tool/persona_validation/run.py --source C:/Users/ahnlee123/Desktop/travelogdata/export/users_raw_20261016.json
# 이미 추출했다면:
python tool/persona_validation/run.py
```

`out/`은 Git에서 제외됩니다. 직접 식별자는 제거하지만 방문 장소와 평점도 민감한 사용자 데이터이므로 외부에 공유하지 않습니다. 원본은 수정하지 않습니다.

## 산출물

- `users_reduced.jsonl`: 사용자별 허용 필드만 추출. 설문, 방문, 평점, 실제 비행, 메모 길이/사진 개수. 이름, 계정 UID, 이메일, 자유 본문, 정확한 날짜 제외.
- `users_summary.jsonl`, `sample_30.jsonl`: 전체 요약과 설문 유무/활동량별 30명 표본.
- `vectors.jsonl`: 현재 설문 축과 앱 수식을 사용한 기존/관측값 기반 입력. 누락 축과 0점을 구분.
- `data_profile.json`: 응답 없는 완료 플래그, 설문 재계산 차이, 축 분포와 국가 매핑 누락.
- `baseline_audit.json`, `updated_audit.json`: 전체/설문만/여행만/혼합/무자료 그룹별 점수, 쏠림, 작은 잡음, 축 제거 진단.
- `validation_summary.json`: 핵심 결과와 검증 범위. 정확도 인증을 의미하지 않습니다.
- `baseline_results.jsonl`, `updated_results.jsonl`: 사용자별 비교용 상대 점수. 별도 정답 라벨이 아닙니다.

기존 알고리즘/프로토타입은 `baseline_scorer.dart`, `baseline_prototypes.json`에 고정했습니다. 캐시만 추가한 기존 계산과 현재 프로덕션 `PersonaScorer`를 비교합니다. 보정 표본 난수 시드는 고정합니다. 잡음은 축별 ±0.05, 3회이며 축 제거는 재현 가능한 무작위 100명(한 축), 40명(축별)을 사용합니다.

## 해석 범위

이 export에는 `trip_logs` 하위 컬렉션과 독립적인 본인 선택 타입 정답이 없습니다. AI가 추정하는 도시/랜드마크 13개 축을 만들어 넣지 않고 **AI 축이 없는 결정적 경로**만 검증합니다. 국가명 매핑은 번들 light/GeoJSON 자산을 사용하므로 앱 실행 시 일부 영토/별칭 정규화와 차이가 날 수 있습니다. 설문 완료 수는 DB 플래그 기준이고 실제 응답 수와 다릅니다. 추출 요약의 도시 수는 예비 수치이며, 벡터 생성 시에는 앱의 방문 조건인 날짜 구간 유무를 적용합니다.

타입 쏠림이 있다고 실제 사용자 타입이 동일 비율이어야 한다고 가정하지 않습니다. 이 자료를 정답으로 삼아 가중치를 맞추거나 균등 분포로 강제하지 않았습니다. 설문과 여행 간 일치도는 두 증거의 충돌 진단이고, 잡음 안정성은 수치적 안정성일 뿐 실제 성격 정확도가 아닙니다.

앱은 자료가 없거나 전부 중립이면 선두 타입을 저장/표시하지 않습니다. 자료가 적으면 균등 혼합 방향으로 점수를 완화하고 잠정 결과를 표시합니다. 이는 가중치 커버리지에 따른 휴리스틱으로, 확률 보정이 아닙니다. 계획/기록 축 방향과 타입 설명에 명백히 어긋난 일부 여유/집중 기준도 수정했습니다. 기존 13개 AI 축의 의미와 온라인 설명 품질은 이번 오프라인 검증으로 인증하지 않습니다.

## 앱 회귀 테스트

```powershell
flutter test --no-pub test/persona_scorer_test.dart test/traveler_type_store_test.dart test/travel_quantifier_evidence_test.dart
```

빈 자료/중립/비정상 입력, 입력 키 순서, 타입 방향, 반복 방문, 캐시 버전과 자료 없는 결과의 저장 거부를 검사합니다. 가상 타입 표본 회수율은 실제 사용자 정확도로 보고하지 않습니다.

## 대표 관광도시 / 분류별 Jev 채점

```powershell
# 오프라인 준비 및 호출 없는 점검
python tool/persona_validation/jev_pipeline.py prepare
python tool/persona_validation/jev_pipeline.py score
python -m unittest discover -s tool/persona_validation -p test_jev_pipeline.py -v
dart tool/persona_validation/rerun_jev.dart --self-test
```

`out/jev/`에 도시 목록, 랜드마크 분류 연결표, 질문과 축 방향, 공개 정보만 담은 요청 299개, 고정된 500명 코호트를 생성합니다. 도시 후보는 기존 `city_type`와 `city_rank`의 합집합이며 국가 정보까지 확인합니다. 기존 P/W 점수는 Jev 입력으로 재사용하지 않습니다. 음식 태그는 제외하고 숙박 시설도 관광지 채점에서 제외합니다. UNESCO 방문은 별도 기본 분류로 연결하고 같은 이름의 중복 방문은 한 번만 반영합니다. 동명이면서 분류가 다른 장소는 추측하지 않습니다.

**API 키를 넣기 전까지 `score --execute`를 실행하지 않습니다.** 키는 무시된 프로젝트 `.env`의 `TYPESAFE_API_KEY` 또는 환경변수로 설정합니다. 키는 화면이나 산출물에 출력하지 않습니다. 준비 시점에는 실제 API를 호출하지 않았습니다.

```powershell
# 키 설정 후 소량 파일럿: 대표 도시 3개, 분류 2개
python tool/persona_validation/jev_pipeline.py score --execute --limit 5 --max-usd 0.5
# 파일럿 실제 usage/누락 축을 확인한 후 나머지 캐시 채우기
python tool/persona_validation/jev_pipeline.py score --execute --limit 0 --max-usd 0.5
# 모두 채점된 경우에만 개인 기록과 로컬 결합 및 같은 500명 재계산
python tool/persona_validation/jev_pipeline.py aggregate
dart tool/persona_validation/rerun_jev.dart
```

채점은 버전 고정 `jev-1.14.0`, 공식 `https://api.typesafe.ai/v1/systemone` 엔드포인트를 사용합니다. [공식 API](https://docs.typesafe.ai/api/system-one), [Score 응답](https://docs.typesafe.ai/primitives/score), [모델/요금](https://docs.typesafe.ai/models)을 기준으로 구성했습니다. 요금 추적은 입력 100만 토큰당 $0.042를 사용하므로 실제 실행 전 변경 여부를 확인합니다. `--max-usd`는 실행 한 번의 추정 요금 한도이며 공급자 측 청구 한도를 대신하지 않습니다. POST를 자동 재시도하지 않으며, 받은 응답은 검증 전에 저장해 중복 요청을 방지합니다.

각 축은 5단계 점수와 근거 충분 여부를 함께 물어봅니다. 0~4점을 -1~1로 변환하고, 초기 confidence 0.35/근거 확률 0.75 미만은 제외합니다. 분류만으로 알 수 없는 혼잡도·비용·현지인/관광객 비율·밤문화는 계산하지 않습니다. 이 방식은 13개 축을 모두 강제로 채우지 않습니다. 4개 랜드마크 축은 기존 온라인 AI 프롬프트와 프로토타입 사이의 방향 충돌이 있어, 명시적인 `axis_contract.json`의 프로토타입 기준으로 채점합니다. 아직 프로덕션 AI 경로를 바꾸는 작업은 아닙니다.

방문 평점에는 음수가 되지 않는 제한된 상대 가중치를 쓰고, 분류별 기여량을 제한해 놀이공원 방문 목록이 길다는 이유로 결과를 지배하지 않게 합니다. 사용자 자료나 프로덕션 앱 파일은 API로 보내지 않습니다. 결과 캐시는 질문·자료·모델 버전의 해시로 묶고, 사용자 데이터가 준비 이후 바뀌면 재결합을 중단합니다.

실제 Jev 응답을 받은 뒤 `comparison_500.json`과 `results_500.jsonl`이 만들어집니다. `--self-test`는 가상 500개 행으로 계산 경로만 점검하며 실제 사용자 결과 파일을 생성하지 않습니다.

## 타입 분포 완화 실험

```powershell
python tool/persona_validation/calibrate_distribution.py
python -m unittest discover -s tool/persona_validation -p test_distribution_calibration.py -v
```

기존 Jev 결과를 유지한 채 350명을 기준 집단으로 삼고, 타입별 로그 점수의 백분위로 상대적인 쏠림을 완화합니다. 원래 상대 점수가 0.8 이상인 결과와 전부 중립인 결과는 보정하지 않습니다. 결과를 인원수 할당으로 옮기는 방식이 아니라 고정된 점수 변환이므로 같은 사용자는 배치 구성이나 순서와 무관하게 같은 결과를 받습니다.

보정 강도는 0~1의 0.05 간격 중 **350명에서 최대 타입 비중 25% 이하, 각 타입 2% 이상을 만족하는 가장 작은 값**으로 정합니다. 나머지 150명은 기준 분포 학습이나 강도 선택에 쓰지 않습니다. 목표를 만족하는 값이 없으면 할당을 강제하지 않고 중단합니다. 보정 기준은 이 앱의 특정 코호트에서 얻은 것으로 다른 모집단의 실제 성향 비율을 대표하지 않습니다.

`out/jev/distribution_profile.json`은 기준 집단과 고정 변환, `distribution_comparison.json`은 보정용/확인용/전체 비교, `distribution_results_500.jsonl`은 원래 점수와 실험 보정 점수를 담습니다. 현재 프로덕션 앱 계산에는 연결하지 않은 오프라인 실험이며 API를 추가 호출하지 않습니다. 점수 균형은 정확도 검증이나 정답 라벨이 아닙니다. 원래 상위 3개 밖의 타입으로 변경된 인원도 보고하므로 결과 해석 시 확인해야 합니다.

### 더 강한 균등 분포 보정

```powershell
python tool/persona_validation/balance_distribution.py
python -m unittest discover -s tool/persona_validation -p test_strong_distribution.py -v
```

같은 보정용 350명에서 각 타입이 약 10%가 되도록 타입별 로그 점수 오프셋을 학습합니다. 원래 상대 점수가 80% 이상인 결과는 그대로 유지하고, 남은 목표 인원에 맞춰 점수 오프셋을 조정합니다. 보호된 결과만으로 목표를 초과하는 등 충돌이 있으면 강제로 뒤집지 않고 중단합니다. 낮아지는 학습 온도는 1, 0.5, 0.2, 0.1, 0.05, 0.02로 고정하고 각 단계에서 300회 갱신합니다. 확인용 150명으로 강도나 오프셋을 재조정하지 않습니다.

이 목표는 실제 성향 비율에 관한 통계적 주장이 아니라 사용자가 요청한 제품상의 분포 목표입니다. 새로운 사용자를 타입별 정원에 배정하지 않고 저장된 고정 오프셋으로 개별 채점합니다. 따라서 보정 집단의 분포가 균등해도 확인용 집단이나 새 사용자의 분포가 정확히 10%가 된다는 보장은 없습니다. 정확도보다 분포 균형을 더 우선하므로 원래 추천과 크게 다른 타입으로 바뀔 수 있습니다.

`distribution_strong_profile.json`, `distribution_strong_comparison.json`, `distribution_strong_results_500.jsonl`에 별도로 저장하며 원본과 직전 보정 결과는 유지합니다. 프로덕션 앱에는 연결하지 않은 실험입니다.
