// lib/providers/personality_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/models/personality_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalityProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PersonalityQuestion> _questions = [];
  Map<int, int> _responses = {}; // Question ID -> Score (1..7)
  Map<String, double> _finalScores = {};
  bool _isCalculated = false;

  List<PersonalityQuestion> get questions => _questions;
  Map<int, int> get responses => _responses;
  Map<String, double> get finalScores => _finalScores;
  bool get isCalculated => _isCalculated;

  final List<String> dimensions = [
    "solo_social",
    "nature_culture",
    "relaxed_intensive",
    "planned_spontaneous",
    "budget_luxury",
    "transit_drive",
    "documenter_minimalist",
    "morning_night"
  ];

  PersonalityProvider() {
    _loadSavedState();
  }

  // Load saved state from Local & Server
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;

      // 1. Load from Local
      _loadFromLocal(prefs);

      // 2. Load from Server (Sync)
      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data();
            if (data != null) {
              bool serverHasData = false;

              if (data.containsKey('dna_responses')) {
                await prefs.setString('dna_responses', data['dna_responses']);
                serverHasData = true;
              }
              if (data.containsKey('dna_final_scores')) {
                await prefs.setString('dna_final_scores', data['dna_final_scores']);
                serverHasData = true;
              }
              if (data.containsKey('dna_is_calculated')) {
                await prefs.setBool('dna_is_calculated', data['dna_is_calculated']);
                serverHasData = true;
              }

              // Reload from local after sync
              _loadFromLocal(prefs);

              // If server is empty but local has data, upload local data
              if (!serverHasData && _isCalculated) {
                await _saveState();
              }
            }
          }
        } catch (e) {
          print("Failed to load personality state from server: $e");
        }
      }

      notifyListeners();
    } catch (e) {
      print("Error loading saved personality state: $e");
    }
  }

  void _loadFromLocal(SharedPreferences prefs) {
    if (prefs.containsKey('dna_responses')) {
      final String? responsesJson = prefs.getString('dna_responses');
      if (responsesJson != null) {
        Map<String, dynamic> decoded = json.decode(responsesJson);
        _responses = decoded.map((key, value) => MapEntry(int.parse(key), value as int));
      }
    }

    if (prefs.containsKey('dna_final_scores')) {
      final String? scoresJson = prefs.getString('dna_final_scores');
      if (scoresJson != null) {
        Map<String, dynamic> decoded = json.decode(scoresJson);
        _finalScores = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
      }
    }

    _isCalculated = prefs.getBool('dna_is_calculated') ?? false;
  }

  // Save state to Local & Server
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;

      Map<String, int> stringKeyResponses = _responses.map((key, value) => MapEntry(key.toString(), value));
      String responsesJson = json.encode(stringKeyResponses);
      String scoresJson = json.encode(_finalScores);

      // 1. Save Local
      await prefs.setString('dna_responses', responsesJson);
      await prefs.setString('dna_final_scores', scoresJson);
      await prefs.setBool('dna_is_calculated', _isCalculated);

      // 2. Save Server
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'dna_responses': responsesJson,
            'dna_final_scores': scoresJson,
            'dna_is_calculated': _isCalculated,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          print("Failed to save personality state to server: $e");
        }
      }
    } catch (e) {
      print("Error saving personality state: $e");
    }
  }

  Future<void> loadQuestions() async {
    if (_questions.isNotEmpty) return;
    try {
      final String response =
      await rootBundle.loadString('assets/personality_questions.json');
      final List<dynamic> data = json.decode(response);
      _questions =
          data.map((json) => PersonalityQuestion.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      print("Error loading personality questions: $e");
    }
  }

  void answerQuestion(int questionId, int score) {
    _responses[questionId] = score;
    _saveState(); // Save & Sync
    notifyListeners();
  }

  Future<void> resetQuiz() async {
    _responses.clear();
    _finalScores.clear();
    _isCalculated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dna_responses');
    await prefs.remove('dna_final_scores');
    await prefs.remove('dna_is_calculated');

    // Also remove from server
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'dna_responses': FieldValue.delete(),
          'dna_final_scores': FieldValue.delete(),
          'dna_is_calculated': FieldValue.delete(),
        });
      } catch (e) {
        print("Error clearing server state: $e");
      }
    }

    notifyListeners();
  }

  void calculateScores() {
    Map<String, double> rawScores = {for (var d in dimensions) d: 0.0};
    Map<String, double> maxRawScores = {for (var d in dimensions) d: 0.0};

    // Precompute Max Raw for normalization
    for (var q in _questions) {
      for (var entry in q.weights.entries) {
        if (dimensions.contains(entry.key)) {
          maxRawScores[entry.key] =
              (maxRawScores[entry.key] ?? 0) + (3.0 * entry.value.abs());
        }
      }
    }

    // Calculate Raw Scores
    for (var q in _questions) {
      if (_responses.containsKey(q.id)) {
        int r = _responses[q.id]!;
        int v = r - 4; // 1..7 -> -3..+3

        for (var entry in q.weights.entries) {
          if (dimensions.contains(entry.key)) {
            rawScores[entry.key] =
                (rawScores[entry.key] ?? 0) + (v * entry.value);
          }
        }
      }
    }

    // Normalize and Clamp (0-100)
    for (var d in dimensions) {
      if ((maxRawScores[d] ?? 0) == 0) {
        _finalScores[d] = 50.0;
      } else {
        double z = rawScores[d]! / maxRawScores[d]!;
        double score = 50 + 50 * z;
        _finalScores[d] = score.clamp(0.0, 100.0);
      }
    }

    _isCalculated = true;
    _saveState(); // Save & Sync
    notifyListeners();
  }

  // Helper to get formatted labels
  String getLeftLabel(String dimension) {
    switch (dimension) {
      case "solo_social":
        return "Social";
      case "nature_culture":
        return "Culture/City";
      case "relaxed_intensive":
        return "Intensive";
      case "planned_spontaneous":
        return "Spontaneous";
      case "budget_luxury":
        return "Luxury";
      case "transit_drive":
        return "Drive";
      case "documenter_minimalist":
        return "Minimalist";
      case "morning_night":
        return "Night";
      default:
        return "";
    }
  }

  String getRightLabel(String dimension) {
    switch (dimension) {
      case "solo_social":
        return "Solo";
      case "nature_culture":
        return "Nature";
      case "relaxed_intensive":
        return "Relaxed";
      case "planned_spontaneous":
        return "Planned";
      case "budget_luxury":
        return "Budget";
      case "transit_drive":
        return "Transit";
      case "documenter_minimalist":
        return "Documenter";
      case "morning_night":
        return "Morning";
      default:
        return "";
    }
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _loadSavedState();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveState();
  }

}