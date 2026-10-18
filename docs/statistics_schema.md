# 통계 JSON 규격 v1

국가·도시 수치와 순위/테마 목록 69개 파일은 `StatisticsDataset` 규격을 사용한다.
대상 파일의 유일한 목록은 `tool/statistics_schema.py`의 `DATASETS`이며,
`lib/services/statistics_assets.dart`는 마이그레이션 도구가 생성한다.
지도 도형, 공항/항공사/랜드마크 카탈로그, 언어·종교의 국가별 관계 자료,
비자 규칙, 개인 방문 기록은 각각의 도메인 모델을 유지한다.

```json
{
  "schema_version": 1,
  "dataset_id": "example",
  "metadata": {"source_url": null, "reference_period": null, "updated_at": null},
  "legacy_layout": "list",
  "tables": [{
    "id": "main",
    "metadata": {"source_url": null, "reference_period": null, "updated_at": null},
    "dimensions": ["iso_a3"],
    "metrics": [{"id": "population", "unit": "persons", "source_url": null, "reference_period": null, "updated_at": null}],
    "records": [{"dimensions": {"iso_a3": "KOR"}, "values": {"population": 100}}]
  }]
}
```

- `dataset_id`는 파일명(확장자 제외)과 일치한다. `tables[].id`는 데이터셋 내에서 유일하다.
- `dimensions`는 대상 식별 필드다. `iso_a3`와 도시명 등 원래 필드명을 보존했다.
  이번 변경은 도시 ID나 IOC→ISO 변환을 하지 않는다. 동명 도시 문제는 별도 수정이 필요하다.
- `metrics`는 값 필드의 명시적 정의다. 지표별 단위·출처·관측기간을 기록한다.
  설명 문자열, 순위, 불리언, 부가 속성도 값으로 보존하며 `number()`는 수치만 반환한다.
- 원래 출처·기간·단위를 확인할 수 없던 항목은 `null`이다. 파일을 변환한 날짜를 통계 갱신일로 쓰지 않는다.
  출처와 기간은 지표 → 테이블 → 데이터셋 순으로 더 구체적으로 기록할 수 있다.
  소비자가 필요한 범위의 메타데이터를 명시적으로 선택한다.
- `null`, 누락 필드, `0`은 다르다. 원래 순서와 중복 행도 보존한다.
  중복 제거·정렬·단위 환산·통계 최신화는 이 마이그레이션에 포함하지 않는다.
- `legacy_layout`은 기존 도메인 모델 연결을 위한 호환 정보(`list` 또는 `sections`)다.
  새 기능은 이 필드를 읽지 않는다.

## 사용

```dart
final dataset = await StatisticsRepository.instance.load('assets/health.json');
final table = dataset.table('hospital_beds_per_1k');
for (final row in table.records) {
  final iso = row.dimensions['iso_a3'];
  final beds = row.number('value');
}
```

공통 저장소는 스키마·데이터셋 ID·선언된 필드·중복 지표를 검증하고,
동시 요청과 성공한 결과를 캐시한다. 실패 결과는 다시 읽을 수 있다.
도메인 모델/기존 화면은 `loadLegacyString()` 어댑터를 사용한다.
새 소비자는 `load()`로 읽고 `tables`, `records`, `metrics`를 직접 사용한다.
`EconomyProvider`는 새 API를 직접 사용하는 예다.

## 검증과 유지보수

```powershell
python tool/migrate_statistics_schema.py --check
python tool/verify_statistics_migration.py
flutter test --no-pub --no-test-assets test/statistics_dataset_test.dart
```

`migrate_statistics_schema.py`는 이전 형식을 손실 없이 변환하며 재실행해도 값이 바뀌지 않는다.
마이그레이션 전 Git 원본에서 만든 69개 구조 지문은 `test/fixtures/statistics_legacy_fingerprints.json`에 있다.
Python과 Dart 양쪽에서 모든 필드·값·숫자 타입·행 순서의 보존을 확인한다.
원본의 객체 키 순서는 의미가 없으므로 지문에서 정렬한다.
향후 통계 값을 의도적으로 바꾸면 해당 변경과 함께 지문/레코드 수 기준도 검토·갱신한다.
기존 감사 스크립트도 공통 Python 코덱으로 새 형식을 읽는다.

데이터셋 추가 시 `DATASETS`를 갱신하고 변환 도구를 실행한 뒤 pubspec 등록,
차원/지표 정의와 출처·기준기간·단위를 확인한다. 아직 모르는 메타데이터를 추정해 채우지 않는다.

## 적용 시 검증 결과 (2026-10-17)

- 69개 데이터셋, 7,982개 레코드의 스키마 검사와 원본 지문 비교 통과.
- Dart 실행 테스트 7개 통과: 전체 값 보존, 동시 읽기/캐시, 재시도,
  누락·null·0 구분/불변성, 잘못된 스키마, ID 불일치, 비통계 자료 호환.
- 공통 모델·저장소·레지스트리·경제 Provider·테스트의 정적 검사 통과.
- 변경된 기존 Provider/화면/유틸리티 10개 파일 정적 검사: 오류 0, 경고 20, 정보 140.
  사용하지 않는 import/변수, 기존 스타일·deprecated API 경고 등은 별도 정리 대상이다.
- 기존 감사 도구의 구조 검사와 공식 원표 비교 결과도 변환 전과 동일.

실기기에서 모든 통계 화면을 열어 확인한 결과는 아니다. 통계 수치 최신화와
감사에서 발견한 계산 오류 수정은 별도 작업으로 남아 있다.
