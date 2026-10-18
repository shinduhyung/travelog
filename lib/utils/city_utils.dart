// lib/utils/city_utils.dart

import 'dart:convert';
import 'package:jidoapp/services/statistics_repository.dart';
// City 모델 임포트는 더 이상 직접 사용하지 않지만, 다른 곳에서 필요할 수 있으므로 유지합니다.
// import 'package:jidoapp/models/city_model.dart'; // 이 부분은 주석 처리하거나 제거 가능

/// `assets/cities.json` 또는 `assets/transportation.json`과 같은 JSON 파일에서
/// 도시 데이터를 로드하고, 이름이 중복되는 도시들의 원본 JSON 맵을 찾아 반환합니다.
///
/// [assetPath] 로드할 JSON 파일의 경로 (예: 'assets/cities.json').
/// 반환값: 이름별로 그룹화된 Map<String, List<Map<String, dynamic>>>.
///        여기서 List<Map<String, dynamic>>의 길이가 1보다 큰 경우 해당 이름이 중복된 도시가 있다는 의미입니다.
Future<Map<String, List<Map<String, dynamic>>>> findDuplicateCityNames(String assetPath) async {
  try {
    // 1. JSON 파일 로드
    final String jsonString = await StatisticsRepository.instance.loadLegacyString(assetPath);

    // 2. JSON 문자열을 원본 Map<String, dynamic> 리스트로 파싱
    final List<dynamic> parsedJson = json.decode(jsonString);
    final List<Map<String, dynamic>> allCityMaps = parsedJson.map((json) => json as Map<String, dynamic>).toList();

    // 3. 이름별로 도시 맵들을 그룹화
    final Map<String, List<Map<String, dynamic>>> citiesByName = {};
    for (var cityMap in allCityMaps) {
      final String? cityName = cityMap['name'] as String?;
      if (cityName != null && cityName.isNotEmpty) {
        if (!citiesByName.containsKey(cityName)) {
          citiesByName[cityName] = [];
        }
        citiesByName[cityName]!.add(cityMap);
      }
    }

    // 4. 중복된 이름(즉, 리스트 길이가 1보다 큰)만 필터링
    final Map<String, List<Map<String, dynamic>>> duplicateCities = {};
    citiesByName.forEach((name, cityMapList) {
      if (cityMapList.length > 1) {
        duplicateCities[name] = cityMapList;
      }
    });

    return duplicateCities;
  } catch (e) {
    print('Error finding duplicate city names from $assetPath: $e');
    return {}; // 에러 발생 시 빈 맵 반환
  }
}
