// lib/services/storage_service.dart

import 'dart:convert';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/itinerary_entry_model.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/models/airport_visit_entry.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class StorageService {
  static final StorageService instance = StorageService._init();
  static Database? _database;

  StorageService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('jido.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ❗️ [수정] 버전 2로 설정 (이전에 rating으로 인한 충돌 방지)
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trip_logs(
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            date TEXT,
            summary TEXT,
            generatedItinerary TEXT 
            -- ❗️ [제거] rating REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE itineraries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            generatedItinerary TEXT,
            date TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE trip_logs ADD COLUMN generatedItinerary TEXT');
        }
        // ❗️ [제거] rating 관련 onUpgrade 로직 전체 제거
      },
    );
  }

  // --- TripLogEntry Methods ---
  Future<TripLogEntry> create(TripLogEntry entry) async {
    final db = await instance.database;
    await db.insert('trip_logs', entry.toMap());
    return entry;
  }

  Future<TripLogEntry?> read(String id) async {
    final db = await instance.database;
    // ❗️ [수정] select columns에서 'rating' 제거
    final maps = await db.query(
      'trip_logs',
      columns: ['id', 'title', 'content', 'date', 'summary', 'generatedItinerary'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return TripLogEntry.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<TripLogEntry>> readAllLogs() async {
    final db = await instance.database;
    final result = await db.query('trip_logs', orderBy: 'date DESC');
    return result.map((json) => TripLogEntry.fromMap(json)).toList();
  }

  Future<int> update(TripLogEntry entry) async {
    final db = await instance.database;
    return db.update(
      'trip_logs',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete(
      'trip_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- ItineraryEntry Methods ---
  Future<ItineraryEntry> createItinerary(ItineraryEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('itineraries', entry.toMap());
    return ItineraryEntry(
      id: id,
      title: entry.title,
      content: entry.content,
      generatedItinerary: entry.generatedItinerary,
      date: entry.date,
    );
  }

  Future<List<ItineraryEntry>> readAllItineraries() async {
    final db = await instance.database;
    final result = await db.query('itineraries', orderBy: 'date DESC');
    return result.map((json) => ItineraryEntry.fromMap(json)).toList();
  }

  Future<int> updateItinerary(ItineraryEntry entry) async {
    final db = await instance.database;
    return db.update(
      'itineraries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteItinerary(int id) async {
    final db = await instance.database;
    return await db.delete(
      'itineraries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Clear Database Methods ---
  // 계정 로그아웃 시 기기에 남아있는 SQLite 데이터를 모두 초기화합니다.
  Future<void> clearLocalDatabase() async {
    final db = await instance.database;
    await db.delete('trip_logs');
    await db.delete('itineraries');
  }

  // --- SharedPreferences Methods ---

  Future<void> saveVisitDetails(String key, Map<String, VisitDetails> details) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(
      details.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(key, jsonString);
  }

  Future<Map<String, VisitDetails>> loadVisitDetails(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(key);
    if (jsonString != null) {
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return jsonMap.map(
            (key, value) => MapEntry(key, VisitDetails.fromJson(value)),
      );
    }
    return {};
  }

  Future<void> saveFlightLogs(List<Airline> airlines) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(
      airlines.map((airline) => airline.toJson()).toList(),
    );
    await prefs.setString('flight_logs', jsonString);
  }

  Future<List<Airline>> loadFlightLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('flight_logs');
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Airline.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> saveAirportVisitDetails(Map<String, List<AirportVisitEntry>> details) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(
      details.map((key, value) => MapEntry(
          key,
          value.map((entry) => entry.toJson()).toList()
      )),
    );
    await prefs.setString('airport_visit_details', jsonString);
  }

  Future<Map<String, List<AirportVisitEntry>>> loadAirportVisitDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('airport_visit_details');
    if (jsonString != null) {
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return jsonMap.map(
            (key, value) => MapEntry(
            key,
            (value as List).map((entryJson) => AirportVisitEntry.fromJson(entryJson)).toList()
        ),
      );
    }
    return {};
  }
}