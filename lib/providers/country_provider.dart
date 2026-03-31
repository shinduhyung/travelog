// lib/providers/country_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Color _parseThemeColor(String? hexColor, String? colorName) {
  if (hexColor != null && hexColor.startsWith('#')) {
    String colorStr = hexColor.substring(1);
    if (colorStr.length == 6) {
      colorStr = 'FF$colorStr';
    }
    if (colorStr.length == 8) {
      try {
        return Color(int.parse(colorStr, radix: 16));
      } catch (e) {
        // Parsing failed
      }
    }
  }

  if (colorName != null) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
      case 'light blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'maroon':
        return const Color(0xFF800000);
      default:
        return Colors.grey;
    }
  }
  return Colors.grey;
}

List<Country> _parseAndProcessCountries(Map<String, dynamic> args) {
  final Map<String, String> jsons = args['jsons'];

  final data = json.decode(jsons['geoJsonMain']!);
  final List<dynamic> features = data['features'];
  final Map<String, String> isoA2toA3Map = {
    for (var feature in features)
      if (feature['properties']['iso_a2'] != null &&
          (feature['properties']['iso_a3_eh'] ??
              feature['properties']['iso_a3']) !=
              null)
        feature['properties']['iso_a2'] as String:
        (feature['properties']['iso_a3_eh'] ??
            feature['properties']['iso_a3']) as String
  };

  final List<dynamic> popularityJson = json.decode(jsons['popularityJson']!);
  final Map<String, int> popularityMap = {
    for (var item in popularityJson)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['country_popularity'] as num).toInt()
  };

  final List<dynamic> colorJson = json.decode(jsons['colorJson']!);
  final Map<String, Color> colorMap = {};
  for (var item in colorJson) {
    final isoA2 = item['iso_a2'] as String;
    final isoA3 = isoA2toA3Map[isoA2];
    if (isoA3 != null) {
      colorMap[isoA3] = _parseThemeColor(
          item['theme_color_hex'] as String?, item['theme_color'] as String?);
    }
  }

  final List<dynamic> areaData = json.decode(jsons['areaJson']!);
  final Map<String, double> areaMap = {};
  for (var item in areaData) {
    String? key;
    if (item['iso_a3'] != null)
      key = item['iso_a3'] as String;
    else if (item['country'] != null) key = item['country'] as String;
    if (key != null && item['area'] != null) {
      areaMap[key] = (item['area'] as num).toDouble();
    }
  }

  final List<dynamic> climateData = json.decode(jsons['climateJson']!);
  final Map<String, Map<String, dynamic>> climateMap = {
    for (var item in climateData)
      item['iso_a3'] as String: {
        'temp': (item['avg_temp'] as num).toDouble(),
        'precip': (item['avg_precipitation'] as num).toDouble(),
        'zone': item['climate_zone'] as String?,
      }
  };

  final List<dynamic> geoData = json.decode(jsons['geographyJson']!);
  final Map<String, Map<String, int>> geographyMap = {
    for (var item in geoData)
      item['iso_a3'] as String: {
        'island_count': (item['island_count'] as num).toInt(),
        'coastline_length': (item['coastline_length'] as num).toInt(),
        'elevation_highest': (item['elevation_highest'] as num).toInt(),
        'elevation_average': (item['elevation_average'] as num).toInt(),
        'lake_count': (item['lake_count'] as num).toInt(),
      }
  };

  final List<dynamic> latData = json.decode(jsons['latitudeJson']!);
  final Map<String, Map<String, double>> latitudeMap = {
    for (var item in latData)
      item['iso_a3'] as String: {
        'centroid_lat': (item['centroid_lat'] as num).toDouble(),
        'north_lat': (item['north_lat'] as num).toDouble(),
        'south_lat': (item['south_lat'] as num).toDouble(),
        'capital_lat': (item['capital_lat'] as num).toDouble(),
      }
  };

  final List<dynamic> popEstJson = json.decode(jsons['populationJson']!);
  final Map<String, int> populationMap = {
    for (var item in popEstJson)
      if (item['iso_a3'] != null && item['population_est'] != null)
        item['iso_a3'] as String: (item['population_est'] as num).toInt()
  };

  final List<dynamic> fertilityJson = json.decode(jsons['fertilityJson']!);
  final Map<String, double> fertilityMap = {
    for (var item in fertilityJson)
      if (item['iso_a3'] != null && item['fertility_rate'] != null)
        item['iso_a3'] as String: (item['fertility_rate'] as num).toDouble()
  };

  final List<dynamic> homicideJson = json.decode(jsons['homicideJson']!);
  final Map<String, double> homicideMap = {
    for (var item in homicideJson)
      if (item['iso_a3'] != null && item['homicide_rate'] != null)
        item['iso_a3'] as String: (item['homicide_rate'] as num).toDouble()
  };

  final List<dynamic> lifeExpectancyJson =
  json.decode(jsons['lifeExpectancyJson']!);
  final Map<String, double> lifeExpectancyMap = {
    for (var item in lifeExpectancyJson)
      if (item['iso_a3'] != null && item['life_expectancy'] != null)
        item['iso_a3'] as String: (item['life_expectancy'] as num).toDouble()
  };

  final List<dynamic> immigrantJson = json.decode(jsons['immigrantJson']!);
  final Map<String, double> immigrantMap = {
    for (var item in immigrantJson)
      if (item['iso_a3'] != null && item['immigrant_rate'] != null)
        item['iso_a3'] as String: (item['immigrant_rate'] as num).toDouble()
  };

  final List<dynamic> hdiJson = json.decode(jsons['hdiJson']!);
  final Map<String, double> hdiMap = {
    for (var item in hdiJson)
      if (item['iso_a3'] != null && item['hdi'] != null)
        item['iso_a3'] as String: (item['hdi'] as num).toDouble()
  };

  final List<dynamic> obesityJson = json.decode(jsons['obesityJson']!);
  final Map<String, double> obesityMap = {
    for (var item in obesityJson)
      if (item['iso_a3'] != null && item['obesity_rate'] != null)
        item['iso_a3'] as String: (item['obesity_rate'] as num).toDouble()
  };

  final List<dynamic> powerIndexJson = json.decode(jsons['powerIndexJson']!);
  final Map<String, double> powerIndexMap = {
    for (var item in powerIndexJson)
      if (item['iso_a3'] != null && item['PwrIndx'] != null)
        item['iso_a3'] as String: (item['PwrIndx'] as num).toDouble()
  };

  final List<dynamic> militaryExpenditureJson =
  json.decode(jsons['militaryExpenditureJson']!);
  final Map<String, double> militaryExpenditureMap = {
    for (var item in militaryExpenditureJson)
      if (item['iso_a3'] != null && item['military_expenditure'] != null)
        item['iso_a3'] as String:
        (item['military_expenditure'] as num).toDouble()
  };

  final List<dynamic> armedForcesData = json.decode(jsons['armedForcesJson']!);
  final Map<String, int?> armedForcesMap = {
    for (var item in armedForcesData)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['armed_forces_personnel_total'] as num?)?.toInt()
  };

  final List<dynamic> nukesData = json.decode(jsons['nukesJson']!);
  final Map<String, int?> nukesMap = {
    for (var item in nukesData)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['nukes_total'] as num?)?.toInt()
  };

  final List<dynamic> aircraftCarriersData =
  json.decode(jsons['aircraftCarriersJson']!);
  final Map<String, int?> aircraftCarriersMap = {
    for (var item in aircraftCarriersData)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['aircraft_carriers_total'] as num?)?.toInt()
  };

  final List<dynamic> navyShipsData = json.decode(jsons['navyShipsJson']!);
  final Map<String, int?> navyShipsMap = {
    for (var item in navyShipsData)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['navy_ships_total'] as num?)?.toInt()
  };

  final List<dynamic> aircraftData = json.decode(jsons['aircraftsJson']!);
  final Map<String, int?> aircraftMap = {
    for (var item in aircraftData)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['total_aircraft_2024'] as num?)?.toInt()
  };

  final List<dynamic> tanksData = json.decode(jsons['tanksJson']!);
  final Map<String, int?> tanksMap = {
    for (var item in tanksData)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['tanks_total'] as num?)?.toInt()
  };

  final List<dynamic> iqJson = json.decode(jsons['iqJson']!);
  final Map<String, double> iqMap = {
    for (var item in iqJson)
      if (item['iso_a3'] != null && item['iq'] != null)
        item['iso_a3'] as String: (item['iq'] as num).toDouble()
  };

  final List<dynamic> heightData = json.decode(jsons['heightJson']!);
  final Map<String, Map<String, double>> heightMap = {
    for (var item in heightData)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: {
          'male': (item['male'] as num?)?.toDouble() ?? 0.0,
          'female': (item['female'] as num?)?.toDouble() ?? 0.0,
        }
  };

  final List<dynamic> novelJson = json.decode(jsons['novelJson']!);
  final Map<String, double> novelMap = {
    for (var item in novelJson)
      if (item['iso_a3'] != null && item['novel'] != null)
        item['iso_a3'] as String: (item['novel'] as num).toDouble()
  };

  final List<dynamic> democracyJson = json.decode(jsons['democracyJson']!);
  final Map<String, double> democracyMap = {
    for (var item in democracyJson)
      if (item['iso_a3'] != null && item['democracy'] != null)
        item['iso_a3'] as String: (item['democracy'] as num).toDouble()
  };

  final List<dynamic> olympicsJson = json.decode(jsons['olympicsJson']!);
  final Map<String, Map<String, int>> olympicsMap = {
    for (var item in olympicsJson)
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: {
          'summer_gold': (item['summer_gold'] as num?)?.toInt() ?? 0,
          'summer_total': (item['summer_total'] as num?)?.toInt() ?? 0,
          'winter_gold': (item['winter_gold'] as num?)?.toInt() ?? 0,
          'winter_total': (item['winter_total'] as num?)?.toInt() ?? 0,
        }
  };

  final Map<String, dynamic> healthJson = json.decode(jsons['healthJson']!);

  final Map<String, double> hivMap = {
    for (var item in (healthJson['hiv_prevalence_percent'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };
  final Map<String, double> alzheimersMap = {
    for (var item in (healthJson['alzheimers_case_rate_per_100k'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };
  final Map<String, double> cancerMap = {
    for (var item in (healthJson['cancer_rate_asr_2022'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };
  final Map<String, double> opiateMap = {
    for (var item in (healthJson['opiate_usage_percent'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };
  final Map<String, double> covidVaccineMap = {
    for (var item in (healthJson['covid_vaccination_rate_percent'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };
  final Map<String, int> doctorPayMap = {
    for (var item in (healthJson['specialist_doctor_pay_usd'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toInt()
  };
  final Map<String, double> bedsMap = {
    for (var item in (healthJson['hospital_beds_per_1k'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };

  final Map<String, double> alcoholMap = {
    for (var item in (healthJson['alcohol_consumption_2019'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['alcohol_consumption_liters'] as num).toDouble()
  };
  final Map<String, double> smokerMap = {
    for (var item in (healthJson['total_smokers_2025'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['total_smokers_percent'] as num).toDouble()
  };
  final Map<String, double> firearmMap = {
    for (var item in (healthJson['firearm_ownership'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['firearms_per_100'] as num).toDouble()
  };

  final Map<String, double> tertiaryEduMap = {
    for (var item in (healthJson['tertiary_education_percent'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };
  final Map<String, double> sexRatioMap = {
    for (var item in (healthJson['sex_ratio_total'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['value'] as num).toDouble()
  };

  final Map<String, dynamic> baldJson = json.decode(jsons['baldJson']!);
  final List<dynamic> baldData =
  baldJson['male_pattern_baldness'] as List<dynamic>;
  final Map<String, double> baldnessMap = {
    for (var item in baldData)
      if (item['iso_a3'] != null &&
          item['male_pattern_baldness_percent'] != null)
        item['iso_a3'] as String:
        (item['male_pattern_baldness_percent'] as num).toDouble()
  };

  final Map<String, dynamic> techJson = json.decode(jsons['technologyJson']!);

  final Map<String, double> internetPenetrationMap = {
    for (var item in (techJson['internet_users_penetration_pct'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['internet_users_pct'] as num).toDouble()
  };
  final Map<String, double> internetSpeedMap = {
    for (var item in (techJson['internet_speed_legacy'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['internet_speed_mbps'] as num).toDouble()
  };
  final Map<String, double> internetUsersMap = {
    for (var item in (techJson['internet_users_total_million'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['internet_users_million'] as num).toDouble()
  };
  final Map<String, double> facebookMap = {
    for (var item in (techJson['facebook_users_2025'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['facebook_users_million'] as num).toDouble()
  };
  final Map<String, double> instagramMap = {
    for (var item in (techJson['instagram_users_2024'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['instagram_users_million'] as num).toDouble()
  };

  final Map<String, double> youtubeMap = {
    for (var item in (techJson['youtube_users'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['users'] as num).toDouble() / 1000000.0
  };

  final Map<String, dynamic> ageJson = json.decode(jsons['averageAgeJson']!);

  final Map<String, double> medianAgeMap = {
    for (var item in (ageJson['median_age'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['median_age'] as num).toDouble()
  };
  final Map<String, double> marriageAgeMap = {
    for (var item in (ageJson['age_at_first_marriage'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['age_at_first_marriage'] as num).toDouble()
  };
  final Map<String, double> birthAgeMap = {
    for (var item in (ageJson['average_age_at_first_birth'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['average_age_at_first_birth'] as num).toDouble()
  };

  final Map<String, dynamic> relPopJson =
  json.decode(jsons['religionPopJson']!);

  final Map<String, int> hinduMap = {
    for (var item in (relPopJson['hindu_population'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['population'] as num).toInt()
  };
  final Map<String, int> sikhMap = {
    for (var item in (relPopJson['sikh_population'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['population'] as num).toInt()
  };
  final Map<String, int> jewishMap = {
    for (var item in (relPopJson['jewish_population'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['population'] as num).toInt()
  };
  final Map<String, int> muslimMap = {
    for (var item in (relPopJson['muslim_population'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['population'] as num).toInt()
  };
  final Map<String, int> christianMap = {
    for (var item in (relPopJson['christian_population'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['population'] as num).toInt()
  };
  final Map<String, int> buddhistMap = {
    for (var item in (relPopJson['buddhist_population'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['population'] as num).toInt()
  };

  final Map<String, int> popeMap = {
    for (var item in (relPopJson['pope_count'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['count'] as num).toInt()
  };
  final Map<String, int> cardinalMap = {
    for (var item in (relPopJson['cardinal_count'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String: (item['count'] as num).toInt()
  };

  final Map<String, dynamic> casualtyJson =
  json.decode(jsons['casualtiesJson']!);

  final Map<String, int> ww1Map = {
    for (var item in (casualtyJson['world_war_1_casualties'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['estimated_total_casualties'] as num).toInt()
  };
  final Map<String, int> ww2Map = {
    for (var item in (casualtyJson['world_war_2_casualties'] as List))
      if (item['iso_a3'] != null)
        item['iso_a3'] as String:
        (item['estimated_total_casualties'] as num).toInt()
  };

  List<Country> countries = features.map((feature) {
    final countryName = feature['properties']['name'];
    final isoA2 = feature['properties']['iso_a2'] as String;
    final isoA3 = feature['properties']['iso_a3_eh'] ??
        feature['properties']['iso_a3'] ??
        'N/A';
    final area = areaMap[isoA3] ?? areaMap[countryName] ?? 0.0;
    final temp = climateMap[isoA3]?['temp'] ?? 0.0;
    final precip = climateMap[isoA3]?['precip'] ?? 0.0;
    final climateZone = climateMap[isoA3]?['zone'] as String?;
    final geography = geographyMap[isoA3] ?? {};
    final latitude = latitudeMap[isoA3] ?? {};
    final populationEst = populationMap[isoA3] ?? 0;
    final popularity = popularityMap[isoA3] ?? 0;
    final themeColor = colorMap[isoA3];

    return Country.fromJson(
      feature,
      area: area,
      avgTemp: temp,
      avgPrecipitation: precip,
      islandCount: geography['island_count'] ?? 0,
      coastlineLength: geography['coastline_length'] ?? 0,
      lakeCount: geography['lake_count'] ?? 0,
      elevationHighest: geography['elevation_highest'] ?? 0,
      elevationAverage: geography['elevation_average'] ?? 0,
      centroidLat: latitude['centroid_lat'] ?? 0.0,
      northLat: latitude['north_lat'] ?? 0.0,
      southLat: latitude['south_lat'] ?? 0.0,
      capitalLat: latitude['capital_lat'] ?? 0.0,
      countryPopularity: popularity,
      climateZone: climateZone,
      fertilityRate: fertilityMap[isoA3],
      homicideRate: homicideMap[isoA3],
      lifeExpectancy: lifeExpectancyMap[isoA3],
      immigrantRate: immigrantMap[isoA3],
      hdi: hdiMap[isoA3],
      obesityRate: obesityMap[isoA3],
      PwrIndx: powerIndexMap[isoA3],
      militaryExpenditure: militaryExpenditureMap[isoA3],
      armedForcesPersonnel: armedForcesMap[isoA3],
      nukesTotal: nukesMap[isoA3],
      aircraftCarriersTotal: aircraftCarriersMap[isoA3],
      navyShipsTotal: navyShipsMap[isoA3],
      totalAircraft: aircraftMap[isoA3],
      tanksTotal: tanksMap[isoA3],
      iq: iqMap[isoA3],
      maleHeight: heightMap[isoA3]?['male'],
      femaleHeight: heightMap[isoA3]?['female'],
      novel: novelMap[isoA3],
      democracy: democracyMap[isoA3],
      summerGold: olympicsMap[isoA3]?['summer_gold'],
      summerTotal: olympicsMap[isoA3]?['summer_total'],
      winterGold: olympicsMap[isoA3]?['winter_gold'],
      winterTotal: olympicsMap[isoA3]?['winter_total'],
      hivPrevalence: hivMap[isoA3],
      alzheimersCaseRate: alzheimersMap[isoA3],
      cancerRate: cancerMap[isoA3],
      opiateUsage: opiateMap[isoA3],
      covidVaccinationRate: covidVaccineMap[isoA3],
      specialistDoctorPay: doctorPayMap[isoA3],
      hospitalBeds: bedsMap[isoA3],
      alcoholConsumption: alcoholMap[isoA3],
      smokersPercent: smokerMap[isoA3],
      firearmOwnership: firearmMap[isoA3],
      tertiaryEducation: tertiaryEduMap[isoA3],
      sexRatio: sexRatioMap[isoA3],
      malePatternBaldness: baldnessMap[isoA3],
      internetPenetration: internetPenetrationMap[isoA3],
      internetSpeed: internetSpeedMap[isoA3],
      internetUsers: internetUsersMap[isoA3],
      facebookUsers: facebookMap[isoA3],
      instagramUsers: instagramMap[isoA3],
      youtubeUsers: youtubeMap[isoA3],
      medianAge: medianAgeMap[isoA3],
      ageAtFirstMarriage: marriageAgeMap[isoA3],
      avgAgeFirstBirth: birthAgeMap[isoA3],
      hinduPop: hinduMap[isoA3],
      sikhPop: sikhMap[isoA3],
      jewishPop: jewishMap[isoA3],
      muslimPop: muslimMap[isoA3],
      christianPop: christianMap[isoA3],
      buddhistPop: buddhistMap[isoA3],
      popeCount: popeMap[isoA3],
      cardinalCount: cardinalMap[isoA3],
      ww1Casualties: ww1Map[isoA3],
      ww2Casualties: ww2Map[isoA3],
      themeColor: themeColor,
    )..populationEst = populationEst;
  }).toList();

  final int siachenIndex =
  countries.indexWhere((c) => c.name == 'Siachen Glacier');
  final int indiaIndex = countries.indexWhere((c) => c.name == 'India');
  if (siachenIndex != -1 && indiaIndex != -1) {
    final india = countries[indiaIndex];
    final combinedPolygons = List<List<List<LatLng>>>.from(india.polygonsData)
      ..addAll(countries[siachenIndex].polygonsData);
    countries[indiaIndex] = Country(
      name: india.name,
      isoA2: india.isoA2,
      isoA3: india.isoA3,
      continent: india.continent,
      subregion: india.subregion,
      populationEst: india.populationEst,
      gdpMd: india.gdpMd,
      area: india.area,
      polygonsData: combinedPolygons,
      avgTemp: india.avgTemp,
      avgPrecipitation: india.avgPrecipitation,
      islandCount: india.islandCount,
      coastlineLength: india.coastlineLength,
      lakeCount: india.lakeCount,
      elevationHighest: india.elevationHighest,
      elevationAverage: india.elevationAverage,
      centroidLat: india.centroidLat,
      northLat: india.northLat,
      southLat: india.southLat,
      capitalLat: india.capitalLat,
      isTerritory: india.isTerritory,
      countryPopularity: india.countryPopularity,
      climateZone: india.climateZone,
      fertilityRate: india.fertilityRate,
      homicideRate: india.homicideRate,
      lifeExpectancy: india.lifeExpectancy,
      immigrantRate: india.immigrantRate,
      hdi: india.hdi,
      obesityRate: india.obesityRate,
      PwrIndx: india.PwrIndx,
      militaryExpenditure: india.militaryExpenditure,
      armedForcesPersonnel: india.armedForcesPersonnel,
      nukesTotal: india.nukesTotal,
      aircraftCarriersTotal: india.aircraftCarriersTotal,
      navyShipsTotal: india.navyShipsTotal,
      totalAircraft: india.totalAircraft,
      tanksTotal: india.tanksTotal,
      iq: india.iq,
      maleHeight: india.maleHeight,
      femaleHeight: india.femaleHeight,
      novel: india.novel,
      democracy: india.democracy,
      summerGold: india.summerGold,
      summerTotal: india.summerTotal,
      winterGold: india.winterGold,
      winterTotal: india.winterTotal,
      themeColor: india.themeColor,
      hivPrevalence: india.hivPrevalence,
      alzheimersCaseRate: india.alzheimersCaseRate,
      cancerRate: india.cancerRate,
      opiateUsage: india.opiateUsage,
      covidVaccinationRate: india.covidVaccinationRate,
      specialistDoctorPay: india.specialistDoctorPay,
      hospitalBeds: india.hospitalBeds,
      alcoholConsumption: india.alcoholConsumption,
      smokersPercent: india.smokersPercent,
      firearmOwnership: india.firearmOwnership,
      tertiaryEducation: india.tertiaryEducation,
      sexRatio: india.sexRatio,
      malePatternBaldness: india.malePatternBaldness,
      internetPenetration: india.internetPenetration,
      internetSpeed: india.internetSpeed,
      internetUsers: india.internetUsers,
      facebookUsers: india.facebookUsers,
      instagramUsers: india.instagramUsers,
      youtubeUsers: india.youtubeUsers,
      medianAge: india.medianAge,
      ageAtFirstMarriage: india.ageAtFirstMarriage,
      avgAgeFirstBirth: india.avgAgeFirstBirth,
      hinduPop: india.hinduPop,
      sikhPop: india.sikhPop,
      jewishPop: india.jewishPop,
      muslimPop: india.muslimPop,
      christianPop: india.christianPop,
      buddhistPop: india.buddhistPop,
      popeCount: india.popeCount,
      cardinalCount: india.cardinalCount,
      ww1Casualties: india.ww1Casualties,
      ww2Casualties: india.ww2Casualties,
    );
  }

  final Set<String> validContinents = {
    'Asia',
    'Europe',
    'Africa',
    'North America',
    'South America',
    'Oceania',
    'Antarctica'
  };
  countries.removeWhere((country) {
    if (country.continent != null &&
        !validContinents.contains(country.continent)) {
      return true;
    }
    final itemsToRemove = {
      'Indian Ocean Ter.',
      'Siachen Glacier',
      'Antarctica',
      'N. Cyprus',
      'Northern Cyprus'
    };
    return itemsToRemove.contains(country.name);
  });
  countries.removeWhere((country) => country.name == "Ashmore and Cartier Is.");
  return countries;
}

class CountryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Country> _rawCountries = [];
  Map<String, VisitDetails> _visitDetails = {};
  bool _includeTerritories = true;
  bool _useDefaultRankingBarColor = false;
  String? _homeCountryIsoA3;

  List<Country>? _mergedCountriesCache;

  static const Map<String, String> _territoryToSovereignMap = {
    'FRO': 'DNK',
    'GRL': 'DNK',
    'ABW': 'NLD',
    'CUW': 'NLD',
    'SXM': 'NLD',
    'BES': 'NLD',
    'NCL': 'FRA',
    'PYF': 'FRA',
    'BLM': 'FRA',
    'MAF': 'FRA',
    'SPM': 'FRA',
    'WLF': 'FRA',
    'ATF': 'FRA',
    'REU': 'FRA',
    'GUF': 'FRA',
    'MTQ': 'FRA',
    'GLP': 'FRA',
    'MYT': 'FRA',
    'AIA': 'GBR',
    'BMU': 'GBR',
    'IOT': 'GBR',
    'VGB': 'GBR',
    'CYM': 'GBR',
    'FLK': 'GBR',
    'GIB': 'GBR',
    'MSR': 'GBR',
    'PCN': 'GBR',
    'SHN': 'GBR',
    'TCA': 'GBR',
    'GGY': 'GBR',
    'IMN': 'GBR',
    'JEY': 'GBR',
    'ASM': 'USA',
    'GUM': 'USA',
    'MNP': 'USA',
    'PRI': 'USA',
    'VIR': 'USA',
    'UMI': 'USA',
    'COK': 'NZL',
    'NIU': 'NZL',
    'TKL': 'NZL',
    'HKG': 'CHN',
    'MAC': 'CHN',
    'ALA': 'FIN',
    'SJM': 'NOR',
    'BVT': 'NOR',
    'CCK': 'AUS',
    'CXR': 'AUS',
    'HMD': 'AUS',
    'NFK': 'AUS',
  };

  static final Map<String, Color> _continentColors = {
    'Europe': Colors.yellow.shade700,
    'Asia': Colors.pink.shade300,
    'Africa': Colors.brown.shade400,
    'North America': Colors.blue.shade400,
    'South America': Colors.green.shade400,
    'Oceania': Colors.purple.shade400,
    'Antarctica': Colors.lightBlue.shade100,
  };
  static final Map<String, Color> _subregionColors = {
    'Western Asia': Colors.red.shade400,
    'Central Asia': Colors.orange.shade600,
    'Southern Asia': Colors.amber.shade600,
    'Eastern Asia': Colors.yellow.shade600,
    'South-Eastern Asia': Colors.lime.shade600,
    'Northern Europe': Colors.green.shade400,
    'Western Europe': Colors.teal.shade400,
    'Eastern Europe': Colors.cyan.shade500,
    'Southern Europe': Colors.lightBlue.shade400,
    'Central Europe': Colors.blue.shade800,
    'Northern Africa': Colors.indigo.shade300,
    'Western Africa': Colors.purple.shade300,
    'Middle Africa': Colors.pink.shade300,
    'Eastern Africa': Colors.red.shade300,
    'Southern Africa': Colors.orange.shade300,
    'Northern America': const Color(0xFF3DDAD7),
    'Central America': Colors.teal.shade700,
    'Caribbean': Colors.lightGreen.shade700,
    'South America': Colors.green.shade800,
    'Australia and New Zealand': Colors.deepPurple.shade400,
    'Melanesia': Colors.indigo.shade400,
    'Micronesia': Colors.blue.shade800,
    'Polynesia': Colors.cyan.shade800,
  };

  Map<String, Color> get continentColors => _continentColors;
  Map<String, Color> get subregionColors => _subregionColors;

  Map<String, String> get territoryToSovereignMap => _territoryToSovereignMap;

  Map<String, String> get isoA2ToIsoA3Map {
    final map = <String, String>{};
    for (var country in _rawCountries) {
      if (country.isoA2.isNotEmpty &&
          country.isoA2 != 'N/A' &&
          country.isoA3.isNotEmpty &&
          country.isoA3 != 'N/A') {
        map[country.isoA2.toUpperCase()] = country.isoA3.toUpperCase();
      }
    }
    return map;
  }

  bool get isLoading => _isLoading;

  List<Country> get allCountries {
    if (_includeTerritories) {
      return _rawCountries;
    } else {
      _mergedCountriesCache ??= _mergeTerritoriesIntoSovereigns();
      return _mergedCountriesCache!;
    }
  }

  List<Country> get filteredCountries => allCountries;

  Set<String> get visitedCountries => _visitDetails.keys
      .where((name) => _visitDetails[name]?.isVisited ?? false)
      .toSet();
  Set<String> get wishlistedCountries => _visitDetails.keys
      .where((name) => _visitDetails[name]?.isWishlisted ?? false)
      .toSet();
  Map<String, VisitDetails> get visitDetails => _visitDetails;

  Map<String, String> get countryNameToIsoMap =>
      {for (var c in _rawCountries) c.name: c.isoA3};

  Map<String, String> get isoA2ToCountryNameMap {
    final map = <String, String>{};
    for (var country in _rawCountries) {
      if (country.isoA2.isNotEmpty && country.isoA2 != 'N/A') {
        map[country.isoA2.toUpperCase()] = country.name;
      }
    }
    return map;
  }

  Map<String, String> get isoToCountryNameMap {
    final map = <String, String>{};
    for (var country in _rawCountries) {
      if (country.isoA3.isNotEmpty && country.isoA3 != 'N/A') {
        map[country.isoA3.toUpperCase()] = country.name;
      }
    }
    return map;
  }

  bool get includeTerritories => _includeTerritories;
  bool get useDefaultRankingBarColor => _useDefaultRankingBarColor;
  String? get homeCountryIsoA3 => _homeCountryIsoA3;

  CountryProvider() {
    _initializeData();
  }

  VisitDetails? getVisitDetails(String countryName) {
    return _visitDetails[countryName];
  }

  List<Country> _mergeTerritoriesIntoSovereigns() {
    Map<String, Country> sovereignMap = {};
    List<Country> territoriesToMerge = [];
    List<Country> others = [];

    for (var country in _rawCountries) {
      if (country.isoA3 == 'IND' && country.name == 'India') {
        sovereignMap[country.isoA3] = country;
      } else if (_territoryToSovereignMap.containsKey(country.isoA3)) {
        territoriesToMerge.add(country);
      } else if (_territoryToSovereignMap.containsValue(country.isoA3)) {
        sovereignMap[country.isoA3] = country;
      } else {
        others.add(country);
      }
    }

    for (var territory in territoriesToMerge) {
      String sovereignIso = _territoryToSovereignMap[territory.isoA3]!;

      if (sovereignMap.containsKey(sovereignIso)) {
        Country sovereign = sovereignMap[sovereignIso]!;
        sovereignMap[sovereignIso] = _combineCountries(sovereign, territory);
      } else {
        others.add(territory);
      }
    }

    List<Country> result = [...sovereignMap.values, ...others];
    return result;
  }

  Country _combineCountries(Country sovereign, Country territory) {
    final combinedPolygons =
    List<List<List<LatLng>>>.from(sovereign.polygonsData)
      ..addAll(territory.polygonsData);

    return Country(
      name: sovereign.name,
      isoA2: sovereign.isoA2,
      isoA3: sovereign.isoA3,
      continent: sovereign.continent,
      subregion: sovereign.subregion,
      populationEst: sovereign.populationEst + territory.populationEst,
      area: sovereign.area + territory.area,
      polygonsData: combinedPolygons,
      gdpMd: sovereign.gdpMd + territory.gdpMd,
      avgTemp: sovereign.avgTemp,
      avgPrecipitation: sovereign.avgPrecipitation,
      islandCount: sovereign.islandCount + territory.islandCount,
      coastlineLength: sovereign.coastlineLength + territory.coastlineLength,
      lakeCount: sovereign.lakeCount + territory.lakeCount,
      elevationHighest:
      sovereign.elevationHighest > territory.elevationHighest
          ? sovereign.elevationHighest
          : territory.elevationHighest,
      elevationAverage: sovereign.elevationAverage,
      centroidLat: sovereign.centroidLat,
      northLat: sovereign.northLat,
      southLat: sovereign.southLat,
      capitalLat: sovereign.capitalLat,
      climateZone: sovereign.climateZone,
      isTerritory: sovereign.isTerritory,
      countryPopularity: sovereign.countryPopularity,
      fertilityRate: sovereign.fertilityRate,
      homicideRate: sovereign.homicideRate,
      lifeExpectancy: sovereign.lifeExpectancy,
      immigrantRate: sovereign.immigrantRate,
      hdi: sovereign.hdi,
      obesityRate: sovereign.obesityRate,
      PwrIndx: sovereign.PwrIndx,
      militaryExpenditure: sovereign.militaryExpenditure,
      armedForcesPersonnel:
      (sovereign.armedForcesPersonnel ?? 0) +
          (territory.armedForcesPersonnel ?? 0),
      nukesTotal: sovereign.nukesTotal,
      aircraftCarriersTotal: sovereign.aircraftCarriersTotal,
      navyShipsTotal: sovereign.navyShipsTotal,
      totalAircraft: sovereign.totalAircraft,
      tanksTotal: sovereign.tanksTotal,
      iq: sovereign.iq,
      maleHeight: sovereign.maleHeight,
      femaleHeight: sovereign.femaleHeight,
      novel: sovereign.novel,
      democracy: sovereign.democracy,
      summerGold: (sovereign.summerGold ?? 0) + (territory.summerGold ?? 0),
      summerTotal: (sovereign.summerTotal ?? 0) + (territory.summerTotal ?? 0),
      winterGold: (sovereign.winterGold ?? 0) + (territory.winterGold ?? 0),
      winterTotal: (sovereign.winterTotal ?? 0) + (territory.winterTotal ?? 0),
      themeColor: sovereign.themeColor,
      hivPrevalence: sovereign.hivPrevalence,
      alzheimersCaseRate: sovereign.alzheimersCaseRate,
      cancerRate: sovereign.cancerRate,
      opiateUsage: sovereign.opiateUsage,
      covidVaccinationRate: sovereign.covidVaccinationRate,
      specialistDoctorPay: sovereign.specialistDoctorPay,
      hospitalBeds: sovereign.hospitalBeds,
      alcoholConsumption: sovereign.alcoholConsumption,
      smokersPercent: sovereign.smokersPercent,
      firearmOwnership: sovereign.firearmOwnership,
      tertiaryEducation: sovereign.tertiaryEducation,
      sexRatio: sovereign.sexRatio,
      malePatternBaldness: sovereign.malePatternBaldness,
      internetPenetration: sovereign.internetPenetration,
      internetSpeed: sovereign.internetSpeed,
      internetUsers: sovereign.internetUsers,
      facebookUsers: sovereign.facebookUsers,
      instagramUsers: sovereign.instagramUsers,
      youtubeUsers: sovereign.youtubeUsers,
      medianAge: sovereign.medianAge,
      ageAtFirstMarriage: sovereign.ageAtFirstMarriage,
      avgAgeFirstBirth: sovereign.avgAgeFirstBirth,
      hinduPop: (sovereign.hinduPop ?? 0) + (territory.hinduPop ?? 0),
      sikhPop: (sovereign.sikhPop ?? 0) + (territory.sikhPop ?? 0),
      jewishPop: (sovereign.jewishPop ?? 0) + (territory.jewishPop ?? 0),
      muslimPop: (sovereign.muslimPop ?? 0) + (territory.muslimPop ?? 0),
      christianPop:
      (sovereign.christianPop ?? 0) + (territory.christianPop ?? 0),
      buddhistPop: (sovereign.buddhistPop ?? 0) + (territory.buddhistPop ?? 0),
      popeCount: (sovereign.popeCount ?? 0) + (territory.popeCount ?? 0),
      cardinalCount:
      (sovereign.cardinalCount ?? 0) + (territory.cardinalCount ?? 0),
      ww1Casualties:
      (sovereign.ww1Casualties ?? 0) + (territory.ww1Casualties ?? 0),
      ww2Casualties:
      (sovereign.ww2Casualties ?? 0) + (territory.ww2Casualties ?? 0),
    );
  }

  Future<void> _initializeData() async {
    try {
      if (kDebugMode) {
        debugPrint('🌍 CountryProvider _initializeData START');
      }

      final colorJsonStr =
      await rootBundle.loadString('assets/country_color.json');
      final geoJsonStr = await rootBundle.loadString('assets/custom.geo.json');
      final areaJsonStr = await rootBundle.loadString('assets/area_data.json');
      final climateJsonStr =
      await rootBundle.loadString('assets/climate_data.json');
      final geoDataStr =
      await rootBundle.loadString('assets/geography_data.json');
      final latDataStr =
      await rootBundle.loadString('assets/latitude_data.json');
      final populationJsonStr = await rootBundle
          .loadString('assets/updated_country_populations.json');
      final fertilityJsonStr =
      await rootBundle.loadString('assets/fertility_rate.json');
      final homicideJsonStr =
      await rootBundle.loadString('assets/homicide_rate.json');
      final lifeExpectancyJsonStr =
      await rootBundle.loadString('assets/life_expectancy.json');
      final immigrantJsonStr =
      await rootBundle.loadString('assets/immigration_rate.json');
      final hdiJsonStr = await rootBundle.loadString('assets/hdi_data.json');
      final obesityJsonStr =
      await rootBundle.loadString('assets/obesity_rate.json');
      final powerIndexJsonStr =
      await rootBundle.loadString('assets/power_index.json');
      final militaryExpenditureJsonStr =
      await rootBundle.loadString('assets/military_expenditure.json');
      final armedForcesJsonStr =
      await rootBundle.loadString('assets/armed_forces.json');
      final nukesJsonStr = await rootBundle.loadString('assets/nukes.json');
      final aircraftCarriersJsonStr =
      await rootBundle.loadString('assets/aircraft_carries.json');
      final navyShipsJsonStr =
      await rootBundle.loadString('assets/navy_ships.json');
      final aircraftsJsonStr =
      await rootBundle.loadString('assets/aircrafts.json');
      final tanksJsonStr = await rootBundle.loadString('assets/tanks.json');
      final iqJsonStr = await rootBundle.loadString('assets/iq.json');
      final heightJsonStr = await rootBundle.loadString('assets/height.json');
      final novelJsonStr = await rootBundle.loadString('assets/novel.json');
      final democracyJsonStr =
      await rootBundle.loadString('assets/democracy.json');
      final olympicsJsonStr =
      await rootBundle.loadString('assets/olympics.json');
      final healthJsonStr = await rootBundle.loadString('assets/health.json');
      final baldJsonStr = await rootBundle.loadString('assets/bald.json');
      final technologyJsonStr =
      await rootBundle.loadString('assets/technology.json');
      final averageAgeJsonStr =
      await rootBundle.loadString('assets/average_age.json');
      final religionPopJsonStr =
      await rootBundle.loadString('assets/religion_population.json');
      final casualtiesJsonStr =
      await rootBundle.loadString('assets/casualties.json');
      final popularityJsonStr =
      await rootBundle.loadString('assets/country_popularity.json');

      _rawCountries = await compute(_parseAndProcessCountries, {
        'jsons': {
          'geoJsonMain': geoJsonStr,
          'areaJson': areaJsonStr,
          'climateJson': climateJsonStr,
          'geographyJson': geoDataStr,
          'latitudeJson': latDataStr,
          'populationJson': populationJsonStr,
          'fertilityJson': fertilityJsonStr,
          'homicideJson': homicideJsonStr,
          'lifeExpectancyJson': lifeExpectancyJsonStr,
          'immigrantJson': immigrantJsonStr,
          'hdiJson': hdiJsonStr,
          'obesityJson': obesityJsonStr,
          'powerIndexJson': powerIndexJsonStr,
          'militaryExpenditureJson': militaryExpenditureJsonStr,
          'armedForcesJson': armedForcesJsonStr,
          'nukesJson': nukesJsonStr,
          'aircraftCarriersJson': aircraftCarriersJsonStr,
          'navyShipsJson': navyShipsJsonStr,
          'aircraftsJson': aircraftsJsonStr,
          'tanksJson': tanksJsonStr,
          'iqJson': iqJsonStr,
          'heightJson': heightJsonStr,
          'novelJson': novelJsonStr,
          'democracyJson': democracyJsonStr,
          'olympicsJson': olympicsJsonStr,
          'colorJson': colorJsonStr,
          'healthJson': healthJsonStr,
          'baldJson': baldJsonStr,
          'technologyJson': technologyJsonStr,
          'averageAgeJson': averageAgeJsonStr,
          'religionPopJson': religionPopJsonStr,
          'casualtiesJson': casualtiesJsonStr,
          'popularityJson': popularityJsonStr,
        },
      });

      await _loadSettings();
      await _loadVisitDetails();
      await _loadHomeCountry();

    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('🚨🚨🚨 CountryProvider Initialization Error: $e');
        debugPrint('Stack Trace: $s');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    _includeTerritories = prefs.getBool('includeTerritories') ?? true;
    _useDefaultRankingBarColor =
        prefs.getBool('useDefaultRankingBarColor') ?? false;

    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data.containsKey('includeTerritories')) {
              _includeTerritories =
                  data['includeTerritories'] as bool? ?? _includeTerritories;
              await prefs.setBool('includeTerritories', _includeTerritories);
            }
            if (data.containsKey('useDefaultRankingBarColor')) {
              _useDefaultRankingBarColor =
                  data['useDefaultRankingBarColor'] as bool? ??
                      _useDefaultRankingBarColor;
              await prefs.setBool(
                  'useDefaultRankingBarColor', _useDefaultRankingBarColor);
            }
          }
        } else {
          await _saveSettings();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ Failed to load server settings: $e");
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'includeTerritories': _includeTerritories,
          'useDefaultRankingBarColor': _useDefaultRankingBarColor,
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ Failed to save server settings: $e");
        }
      }
    }
  }

  Future<void> loadSettings() async {
    await _loadSettings();
  }

  Future<void> loadRankingBarColorSetting() async {
    await _loadSettings();
    notifyListeners();
  }

  Future<void> setUseDefaultRankingBarColor(bool value) async {
    _useDefaultRankingBarColor = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useDefaultRankingBarColor', value);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleIncludeTerritories() async {
    _includeTerritories = !_includeTerritories;
    _mergedCountriesCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('includeTerritories', _includeTerritories);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> _loadVisitDetails() async {
    final user = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    String? localJson = prefs.getString('visit_details_v2');

    if (localJson != null) {
      final Map<String, dynamic> decoded = json.decode(localJson);
      _visitDetails = decoded.map(
              (k, v) => MapEntry(k, VisitDetails.fromJson(v as Map<String, dynamic>)));
    }

    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('country_visits_v2')) {
          final String serverJson = doc.data()!['country_visits_v2'] as String;
          final Map<String, dynamic> decoded = json.decode(serverJson);
          _visitDetails = decoded.map((k, v) =>
              MapEntry(k, VisitDetails.fromJson(v as Map<String, dynamic>)));
          await prefs.setString('visit_details_v2', serverJson);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ Failed to load server visit details: $e");
        }
      }
    }
  }

  Future<void> _saveVisitDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encodedMap =
    _visitDetails.map((k, v) => MapEntry(k, v.toJson()));
    final String jsonString = json.encode(encodedMap);
    await prefs.setString('visit_details_v2', jsonString);

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'country_visits_v2': jsonString,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ Failed to save server visit details: $e");
        }
      }
    }
  }

  Future<void> _loadHomeCountry() async {
    final user = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    _homeCountryIsoA3 = prefs.getString('homeCountryIsoA3');

    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('homeCountryIsoA3')) {
          _homeCountryIsoA3 = doc.data()!['homeCountryIsoA3'] as String?;
          if (_homeCountryIsoA3 != null) {
            await prefs.setString('homeCountryIsoA3', _homeCountryIsoA3!);
          } else {
            await prefs.remove('homeCountryIsoA3');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ Failed to load server home country: $e");
        }
      }
    }
  }

  Future<void> _saveHomeCountry() async {
    final prefs = await SharedPreferences.getInstance();
    if (_homeCountryIsoA3 == null) {
      await prefs.remove('homeCountryIsoA3');
    } else {
      await prefs.setString('homeCountryIsoA3', _homeCountryIsoA3!);
    }

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'homeCountryIsoA3': _homeCountryIsoA3,
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ Failed to save server home country: $e");
        }
      }
    }
  }

  void setHomeCountry(String countryName, String countryIsoA3) {
    _homeCountryIsoA3 = countryIsoA3;

    final details = _visitDetails.putIfAbsent(
        countryName, () => VisitDetails(hasLived: true, isVisited: true));
    details.hasLived = true;
    details.isVisited = true;

    if (details.visitDateRanges.isEmpty) {
      details.visitDateRanges.add(DateRange());
      details.visitCount = 1;
    }

    _saveHomeCountry();
    _saveVisitDetails();
    notifyListeners();
  }

  void clearHomeCountry() {
    _homeCountryIsoA3 = null;
    _saveHomeCountry();
    notifyListeners();
  }

  void updateVisitDetailsForCountry(String countryName, VisitDetails? details) {
    if (details == null) {
      _visitDetails.remove(countryName);
    } else {
      _visitDetails[countryName] = details;
    }
    _saveVisitDetails();
    notifyListeners();
  }

  void toggleLivedStatus(String countryName) {
    final details = _visitDetails.putIfAbsent(
        countryName, () => VisitDetails(hasLived: true, isVisited: true));
    details.hasLived = !details.hasLived;
    details.isVisited = true;

    if (details.hasLived && details.visitDateRanges.isEmpty) {
      details.visitDateRanges.add(DateRange());
      details.visitCount = 1;
    }

    if (!details.hasLived &&
        _homeCountryIsoA3 == countryNameToIsoMap[countryName]) {
      clearHomeCountry();
    }

    if (!details.hasLived &&
        !details.isWishlisted &&
        !details.isVisited &&
        details.rating == 0.0) {
      _visitDetails.remove(countryName);
    }

    _saveVisitDetails();
    notifyListeners();
  }

  void setVisitCount(String countryName, int count) {
    if (_visitDetails.containsKey(countryName)) {
      _visitDetails[countryName]!.visitCount = count > 0 ? count : 1;
      _saveVisitDetails();
      notifyListeners();
    }
  }

  void addDateRange(String countryName) {
    final details = _visitDetails.putIfAbsent(
        countryName, () => VisitDetails(isVisited: true));
    details.isVisited = true;
    details.visitDateRanges.add(DateRange());
    details.visitCount = details.visitDateRanges.length;
    _saveVisitDetails();
    notifyListeners();
  }

  void saveDateRange(String countryName, int index, DateRange range) {
    if (_visitDetails.containsKey(countryName)) {
      _visitDetails[countryName]!.visitDateRanges[index] = range;
      _visitDetails[countryName]!.visitCount =
          _visitDetails[countryName]!.visitDateRanges.length;
      _saveVisitDetails();
      notifyListeners();
    }
  }

  void removeDateRange(String countryName, int index) {
    if (_visitDetails.containsKey(countryName)) {
      _visitDetails[countryName]!.visitDateRanges.removeAt(index);
      _visitDetails[countryName]!.visitCount =
          _visitDetails[countryName]!.visitDateRanges.length;

      if (_visitDetails[countryName]!.visitDateRanges.isEmpty) {
        _visitDetails[countryName]!.isVisited = false;
        if (!_visitDetails[countryName]!.hasLived &&
            !_visitDetails[countryName]!.isWishlisted &&
            _visitDetails[countryName]!.rating == 0.0) {
          _visitDetails.remove(countryName);
        }
      }

      _saveVisitDetails();
    }
    notifyListeners();
  }

  void setCountryRating(String countryName, double rating) {
    final details = _visitDetails.putIfAbsent(countryName, () => VisitDetails());
    details.rating = rating;
    if (rating > 0.0) {
      details.isVisited = true;
    }
    if (rating == 0.0 &&
        !details.hasLived &&
        !details.isWishlisted &&
        details.visitDateRanges.isEmpty) {
      _visitDetails.remove(countryName);
    }
    _saveVisitDetails();
    notifyListeners();
  }

  void toggleCountryWishlistStatus(String countryName) {
    if (_visitDetails.containsKey(countryName)) {
      final details = _visitDetails[countryName]!;
      details.isWishlisted = !details.isWishlisted;

      if (!details.isWishlisted &&
          !details.hasLived &&
          !details.isVisited &&
          details.rating == 0.0) {
        _visitDetails.remove(countryName);
      }
    } else {
      _visitDetails[countryName] =
          VisitDetails(isWishlisted: true, isVisited: false);
    }
    _saveVisitDetails();
    notifyListeners();
  }

  @Deprecated(
      'Use setVisitedStatus instead for bulk updates from selection screen.')
  String? toggleVisitedStatus(String countryName) {
    final details = _visitDetails[countryName];

    if (details != null && details.visitDateRanges.isNotEmpty) {
      return 'Are you sure you want to remove all ${details.visitDateRanges.length} visit records? (Rating, Lived status, etc. will be preserved.)';
    } else if (details != null) {
      if (!details.isWishlisted &&
          !details.hasLived &&
          details.rating == 0.0) {
        _visitDetails.remove(countryName);
      } else {
        details.isVisited = false;
      }
    } else {
      _visitDetails[countryName] =
          VisitDetails(visitCount: 1, visitDateRanges: [DateRange()]);
    }

    _saveVisitDetails();
    notifyListeners();
    return null;
  }

  void setVisitedStatus(String countryName, bool isVisited) {
    if (isVisited) {
      if (!_visitDetails.containsKey(countryName)) {
        _visitDetails[countryName] = VisitDetails(
            visitCount: 1, visitDateRanges: [DateRange()], isVisited: true);
      } else {
        final details = _visitDetails[countryName]!;
        if (details.visitDateRanges.isEmpty) {
          details.visitDateRanges.add(DateRange());
          details.visitCount = 1;
        }
        details.isVisited = true;
      }
    } else {
      if (_visitDetails.containsKey(countryName)) {
        final details = _visitDetails[countryName]!;
        details.isVisited = false;
        details.visitDateRanges.clear();
        details.visitCount = 0;

        if (!details.isWishlisted &&
            !details.hasLived &&
            details.rating == 0.0 &&
            homeCountryIsoA3 != countryNameToIsoMap[countryName]) {
          _visitDetails.remove(countryName);
        }
      }
    }
    _saveVisitDetails();
    notifyListeners();
  }

  void clearVisitHistory(String countryName) {
    if (_visitDetails.containsKey(countryName)) {
      final details = _visitDetails[countryName]!;
      details.visitDateRanges.clear();
      details.visitCount = 0;
      details.isVisited = false;

      if (!details.isWishlisted &&
          !details.hasLived &&
          homeCountryIsoA3 != countryNameToIsoMap[countryName] &&
          details.rating == 0.0) {
        _visitDetails.remove(countryName);
      }

      _saveVisitDetails();
      notifyListeners();
    }
  }

  void addVisitWithDetails(
      String countryName, {
        DateTime? arrival,
        DateTime? departure,
        int? userDefinedDuration,
      }) {
    final details = _visitDetails.putIfAbsent(
      countryName,
          () => VisitDetails(isVisited: true, visitCount: 0),
    );

    final newRange = DateRange(
      arrival: arrival,
      departure: departure,
      userDefinedDuration: userDefinedDuration,
      isDurationUnknown:
      userDefinedDuration == null && (arrival == null || departure == null),
    );

    details.visitDateRanges.add(newRange);
    details.visitCount = details.visitDateRanges.length;
    details.isVisited = true;

    _saveVisitDetails();
    notifyListeners();
  }

  void updateUserMetrics(
      String countryName, {
        double? rating,
        double? affordability,
        double? safety,
        double? foodQuality,
        double? transport,
        double? englishProficiency,
        double? cleanliness,
        double? attractionDensity,
        double? vibrancy,
        double? accessibility,
      }) {
    final details = _visitDetails.putIfAbsent(countryName, () => VisitDetails());

    if (rating != null) details.rating = rating;
    if (affordability != null) details.affordability = affordability;
    if (safety != null) details.safety = safety;
    if (foodQuality != null) details.foodQuality = foodQuality;
    if (transport != null) details.transport = transport;
    if (englishProficiency != null) details.englishProficiency = englishProficiency;
    if (cleanliness != null) details.cleanliness = cleanliness;
    if (attractionDensity != null) details.attractionDensity = attractionDensity;
    if (vibrancy != null) details.vibrancy = vibrancy;
    if (accessibility != null) details.accessibility = accessibility;

    _saveVisitDetails();
    notifyListeners();
  }

  void debugPrintSortedVisitCounts() {
    final sortedEntries = _visitDetails.entries
        .where((entry) => entry.value.visitCount > 0)
        .toList()
      ..sort((a, b) => b.value.visitCount.compareTo(a.value.visitCount));

    debugPrint('--- Countries Sorted by Visit Count ---');
    for (var entry in sortedEntries) {
      debugPrint('Country: ${entry.key}, Count: ${entry.value.visitCount}');
    }
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _loadSettings();
    await _loadVisitDetails();
    await _loadHomeCountry();
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveSettings();
    await _saveVisitDetails();
    await _saveHomeCountry();
  }

}