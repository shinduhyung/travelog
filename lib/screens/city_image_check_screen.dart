// check_missing_images.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final jsonFile = File('assets/city_rank.json');
  final directory = Directory('assets/countrydex');

  if (!jsonFile.existsSync() || !directory.existsSync()) {
    print('경로 오류를 확인하세요.');
    return;
  }

  final String jsonString = jsonFile.readAsStringSync();
  final Map<String, dynamic> cityData = jsonDecode(jsonString);

  final List<FileSystemEntity> files = directory.listSync();
  final Set<String> existingFiles = files
      .whereType<File>()
      .map((file) => file.uri.pathSegments.last)
      .where((name) => name.endsWith('.jpg'))
      .toSet();

  // 앱 코드와 완벽히 동일하게 맞춘 로직 (특수문자 삭제)
  String toSnake(String s) {
    String r = s.toLowerCase();
    r = r.replaceAll(RegExp(r"[''`]"), '');
    r = r.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    return r.trim().replaceAll(RegExp(r'\s+'), '_');
  }

  final Set<String> expectedFiles = {};
  final Map<String, List<String>> missingByCity = {};
  final Map<String, List<String>> existingByCity = {};

  cityData.forEach((city, landmarks) {
    for (var landmark in landmarks) {
      final fileName = '${toSnake(landmark)}.jpg';
      expectedFiles.add(fileName);

      if (existingFiles.contains(fileName)) {
        existingByCity.putIfAbsent(city, () => []).add(fileName);
      } else {
        missingByCity.putIfAbsent(city, () => []).add(fileName);
      }
    }
  });

  final orphanedFiles = existingFiles.difference(expectedFiles).toList()..sort();

  print('--- 1. [필요 파일] (city_rank엔 있는데 사진 없음) ---');
  missingByCity.forEach((city, files) {
    print('\n[$city]');
    files.sort();
    files.forEach(print);
  });

  print('\n\n--- 2. [완료 파일] (city_rank에도 있고 사진도 있음) ---');
  existingByCity.forEach((city, files) {
    print('\n[$city]');
    files.sort();
    files.forEach(print);
  });

  print('\n\n--- 3. [정리 대상] (city_rank엔 없는데 사진 폴더엔 있음) ---');
  orphanedFiles.forEach(print);
}