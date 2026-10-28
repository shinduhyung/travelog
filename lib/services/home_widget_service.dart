import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

enum WidgetType { countries, cities, flights }

class HomeWidgetService {
  // iOS 위젯 확장(TravelogWidget)과 앱이 이미지를 함께 읽는 App Group.
  // ios/Runner/Runner.entitlements, ios/TravelogWidget/TravelogWidget.entitlements와 같아야 한다.
  static const String iOSAppGroupId = 'group.com.ahnlee.travellog';

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static Future<void> updateWidget({
    required Uint8List? widgetImage,
    List<Country>? visitedCountries,
    WidgetType widgetType = WidgetType.countries,
  }) async {
    if (widgetImage == null) return;
    try {
      final fileKey = switch (widgetType) {
        WidgetType.countries => 'filename',
        WidgetType.cities    => 'cities_filename',
        WidgetType.flights   => 'flights_filename',
      };
      final widgetName = switch (widgetType) {
        WidgetType.countries => 'TravelogWidget',
        WidgetType.cities    => 'TravelogCitiesWidget',
        WidgetType.flights   => 'TravelogFlightsWidget',
      };
      final dirPath = await _imageDirectory();
      if (dirPath == null) return;
      final file = File('$dirPath/$fileKey.png');
      await file.writeAsBytes(widgetImage);
      await HomeWidget.saveWidgetData<String>(fileKey, file.path);
      await HomeWidget.updateWidget(
        name: widgetName,
        androidName: widgetName,
        iOSName: widgetName,
      );
    } catch (e) {
      debugPrint('🚨 [widgetdebug] ❌ 실패: $e');
    }
  }

  // iOS 위젯 확장은 앱 샌드박스를 못 읽으므로 App Group 컨테이너에 저장한다.
  static Future<String?> _imageDirectory() async {
    if (!Platform.isIOS) return (await getTemporaryDirectory()).path;
    await HomeWidget.setAppGroupId(iOSAppGroupId);
    return PathProviderFoundation().getContainerPath(
      appGroupIdentifier: iOSAppGroupId,
    );
  }
}
