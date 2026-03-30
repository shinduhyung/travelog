// lib/providers/passport_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/models/visa_data_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassportProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, PassportData> _passportDataMap = {};
  bool _isLoading = true;
  String _selectedPassportIso = 'KOR';

  Map<String, PassportData> get passportDataMap => _passportDataMap;
  bool get isLoading => _isLoading;
  String get selectedPassportIso => _selectedPassportIso;
  PassportData? get selectedPassportData => _passportDataMap[_selectedPassportIso];

  // Mapping Territories to Sovereign States (Visa policy matches 100%)
  static const Map<String, String> _territoryMapping = {
    // USA Territories
    'GUM': 'USA', 'MNP': 'USA', 'PRI': 'USA', 'VIR': 'USA',

    // France Territories
    'BLM': 'FRA', 'MAF': 'FRA', 'NCL': 'FRA', 'PYF': 'FRA',
    'SPM': 'FRA', 'WLF': 'FRA',

    // Netherlands Territories
    'ABW': 'NLD', 'CUW': 'NLD', 'SXM': 'NLD',

    // New Zealand Territories
    'COK': 'NZL', 'NIU': 'NZL',

    // Australia Territories
    'NFK': 'AUS',

    // Finland Territories
    'ALA': 'FIN',

    // UK Crown Dependencies
    'GGY': 'GBR', 'IMN': 'GBR', 'JEY': 'GBR',
  };

  PassportProvider() {
    loadPassportData();
  }

  Future<void> loadPassportData() async {
    try {
      final String visaString = await rootBundle.loadString('assets/visa_data.json');
      String? territoryString;
      try {
        territoryString = await rootBundle.loadString('assets/territory_rules.json');
      } catch (_) {}

      final Map<String, dynamic> visaJson = json.decode(visaString);
      final Map<String, dynamic>? territoryJson = territoryString != null ? json.decode(territoryString) : null;

      // 1. Load Basic Data
      _passportDataMap = visaJson.map((passportIso, value) {
        var passportData = value as Map<String, dynamic>;
        var requirements = (passportData['visa_requirements'] as List<dynamic>)
            .map((e) => DestinationVisaInfo.fromJson(e))
            .toList();

        if (territoryJson != null) {
          territoryJson.forEach((terrIso, rules) {
            String status = rules['default'];
            final exceptions = rules['exceptions'] as Map<String, dynamic>?;
            if (exceptions != null && exceptions.containsKey(passportIso)) {
              status = exceptions[passportIso].toString();
            }

            int existingIndex = requirements.indexWhere((e) => e.destinationIsoA3 == terrIso);
            if (existingIndex != -1) {
              requirements[existingIndex] = DestinationVisaInfo(
                destinationIsoA3: terrIso,
                rawStatus: status,
              );
            } else {
              requirements.add(DestinationVisaInfo(
                destinationIsoA3: terrIso,
                rawStatus: status,
              ));
            }
          });
        }

        int newScore = 0;
        for (var item in requirements) {
          if (_isVisaFree(item.rawStatus)) {
            newScore++;
          }
        }

        return MapEntry(passportIso, PassportData(
          passportName: passportData['passport_name'] ?? passportIso,
          powerRank: 0,
          visaFreeCountries: newScore,
          visaRequirements: requirements,
        ));
      });

      // 2. Duplicate Territory Data (Use Sovereign Data)
      _territoryMapping.forEach((territoryIso, sovereignIso) {
        if (_passportDataMap.containsKey(sovereignIso)) {
          final sovereignData = _passportDataMap[sovereignIso]!;

          _passportDataMap[territoryIso] = PassportData(
            passportName: territoryIso,
            powerRank: sovereignData.powerRank,
            visaFreeCountries: sovereignData.visaFreeCountries,
            visaRequirements: sovereignData.visaRequirements,
          );
        }
      });

      // 3. Load User Selection (Sync with Firebase)
      await _loadUserSelection();

    } catch (e) {
      print('Error loading passport data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // [SYNC] Load user's selected passport from Local & Server
  Future<void> _loadUserSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. Load from Local
    String? localIso = prefs.getString('selectedPassportIso');
    if (localIso != null && _passportDataMap.containsKey(localIso)) {
      _selectedPassportIso = localIso;
    }

    // 2. Load from Server (if logged in)
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('selectedPassportIso')) {
          String serverIso = doc.data()!['selectedPassportIso'];
          if (_passportDataMap.containsKey(serverIso)) {
            _selectedPassportIso = serverIso;
            await prefs.setString('selectedPassportIso', serverIso); // Sync Local
          }
        } else if (localIso != null) {
          // If server is empty but local exists, sync to server
          await _saveUserSelection(localIso);
        }
      } catch (e) {
        print("Failed to sync passport selection from server: $e");
      }
    }
  }

  // [SYNC] Save selection
  Future<void> _saveUserSelection(String isoCode) async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. Save Local
    await prefs.setString('selectedPassportIso', isoCode);

    // 2. Save Server
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'selectedPassportIso': isoCode,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print("Failed to save passport selection to server: $e");
      }
    }
  }

  bool _isVisaFree(String status) {
    String lower = status.toLowerCase();

    if (lower.contains('e-visa')) return false;
    if (status == '-1' || lower.contains('admiss')) return false;

    if (int.tryParse(status) != null) return true;
    if (lower.contains('visa free')) return true;
    if (lower.contains('eta')) return true;
    if (lower.contains('arrival')) return true;

    return false;
  }

  void setSelectedPassport(String isoCode) {
    if (_passportDataMap.containsKey(isoCode)) {
      _selectedPassportIso = isoCode;
      _saveUserSelection(isoCode); // Save & Sync
      notifyListeners();
    }
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _loadUserSelection();
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveUserSelection(_selectedPassportIso);
  }

}