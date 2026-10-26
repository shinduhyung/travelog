# 고지도 테마 (보류 중)

앱에서는 주석 처리돼 있다. 되살리려면 `grep -rn "TODO(old-map)"` 로 위치를 찾아 주석을 푼다.

- `lib/widgets/old_map_view.dart` : 벡터 전용 고지도 위젯(전체 주석)
- `lib/screens/countries_map_screen.dart` : ⇄ 버튼 모드 시트, 고지도 분기(주석)
- `pubspec.yaml` : `assets/old_maps/` 등록(주석)
- `assets/old_maps/idrisi_vector.json` : 고지도 육지 윤곽 + 국가 폴리곤(고지도 좌표)
- `tool/old_maps/idrisi/` : 데이터 생성 스크립트
  `make_land_mask.py` -> `register_coast.py` -> `export_vector.py`
  (필요 패키지: numpy, scipy, pillow, shapely, opencv-python-headless)

알려진 한계: 원본 이미지가 720px라 육지 윤곽이 뭉툭하고 작은 섬이 일부 없음.
고해상도 원본(위키미디어 커먼즈, 퍼블릭 도메인)으로 바꾸고 `control_points.json`을 다시 찍으면 좋아진다.
