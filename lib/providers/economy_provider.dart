// providers/economy_provider.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/services/statistics_repository.dart';
import 'package:jidoapp/models/economy_data_model.dart';

class EconomyProvider with ChangeNotifier {
  List<EconomyData> _economyData = [];
  Map<String, Map<String, double>> _economicsTriviaData = {};
  bool _isLoading = false;

  List<EconomyData> get economyData => _economyData;
  Map<String, Map<String, double>> get economicsTriviaData =>
      _economicsTriviaData;
  bool get isLoading => _isLoading;

  EconomyProvider() {
    loadEconomyData();
  }

  Future<void> loadEconomyData() async {
    if (_economyData.isNotEmpty || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final dataset = await StatisticsRepository.instance.load(
        'assets/economy_data.json',
      );
      _economyData = dataset
          .table()
          .records
          .map((row) => EconomyData.fromJson(row.toLegacyJson()))
          .toList();

      await _loadEconomicsTriviaData();
    } catch (e) {
      debugPrint("Error loading economy data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEconomicsTriviaData() async {
    try {
      final dataset = await StatisticsRepository.instance.load(
        'assets/economics_trivia.json',
      );
      final Map<String, Map<String, double>> processedData = {};

      for (final table in dataset.tables) {
        if (table.metrics.length != 1) {
          throw FormatException('Expected one economic metric in ${table.id}');
        }
        final metric = table.metrics.single.id;
        final Map<String, double> cropMap = {};
        for (final row in table.records) {
          final iso = row.dimensions['iso_a3'];
          final value = row.number(metric);
          if (iso is String && value != null) {
            cropMap[iso] = value.toDouble();
          }
        }
        processedData[table.id] = cropMap;
      }

      _economicsTriviaData = processedData;
    } catch (e) {
      debugPrint('Economics Trivia Data Error: $e');
    }
  }
}
