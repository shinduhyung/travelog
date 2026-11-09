// Pure Dart implementation shared by the app and the offline parity verifier.
import 'dart:math';
import 'persona_scorer.dart';

class PersonaCityEvidence {
  final String name;
  final int visits;
  final double rating;
  final bool hasLived, isHome;
  const PersonaCityEvidence(this.name, {this.visits = 0, this.rating = 0,
    this.hasLived = false, this.isHome = false});
}

class PersonaLandmarkEvidence {
  final String name, source;
  final double rating;
  final List<String> attributes;
  final String? heritageType;
  const PersonaLandmarkEvidence(this.name, {this.source = 'landmark', this.rating = 0,
    this.attributes = const [], this.heritageType});
}

class PersonaPlaceFeatures {
  final Map<String,double> axes;
  final Map<String,int> evidence;
  const PersonaPlaceFeatures(this.axes, this.evidence);
}

class PersonaPlaceCatalog {
  final Map<String,dynamic> data;
  PersonaPlaceCatalog(this.data) {
    if (data['schema_version'] != 1) throw const FormatException('Unsupported place profile schema');
  }

  /// Applies to both preference evidence and candidate compatibility results.
  bool isEligibleLandmark(String name, List<String> attributes) {
    final policy = data['eligibility_policy'] as Map<String, dynamic>?;
    if (policy == null) return true; // Legacy offline fixtures have no policy.
    String key(String value) => value.toLowerCase().trim().split(RegExp(r'\s+')).join(' ');
    final tags = attributes.map((t) => (data['tag_aliases'] as Map)[t] as String? ?? t).toSet();
    if (tags.any((t) => (policy['excluded_attributes'] as List).contains(t))) return false;
    if ((policy['excluded_catalog_names'] as List).any((n) => key(n as String) == key(name))) return false;
    for (final tag in ['Lake', 'Island']) {
      if (tags.contains(tag) && !(policy['${tag.toLowerCase()}_allowlist'] as List).any((n) => key(n as String) == key(name))) return false;
    }
    return true;
  }

  String normalize(String name) {
    final folds = data['fold_characters'] as Map<String,dynamic>;
    final text = StringBuffer();
    for (final rune in name.runes) {
      if (rune >= 0x300 && rune <= 0x36f) continue;
      final char = String.fromCharCode(rune);
      text.write(folds[char] ?? char.toLowerCase());
    }
    final normalized = text.toString().trim().split(RegExp(r'\s+')).join(' ');
    return (data['name_aliases'] as Map<String,dynamic>)[normalized] as String? ?? normalized;
  }

  static Map<String,double> _weights(List<MapEntry<String,double>> ratings) {
    final positive = ratings.where((e)=>e.value.isFinite && e.value>0).map((e)=>e.value).toList();
    final mean = positive.isEmpty ? 0.0 : positive.reduce((a,b)=>a+b)/positive.length;
    final variance = positive.isEmpty ? 0.0 : positive.fold<double>(0,(s,v)=>s+(v-mean)*(v-mean))/positive.length;
    final sd = sqrt(variance);
    return {for (final e in ratings) e.key: sd>0 && e.value.isFinite && e.value>0
      ? (1+(e.value-mean)/(2*sd)).clamp(.25,2).toDouble() : 1.0};
  }

  static void _add(Map<String,List<List<double>>> values, String key, double score, double weight) {
    values.putIfAbsent(key,()=>[]).add([score,weight]);
  }

  static double _mean(List<List<double>> items) {
    final denominator = items.fold<double>(0,(s,v)=>s+v[1]);
    return items.fold<double>(0,(s,v)=>s+v[0]*v[1])/denominator;
  }

  Map<String,dynamic>? _resolve(PersonaLandmarkEvidence place) {
    if (!isEligibleLandmark(place.name, place.attributes)) {
      return {'excluded': true, 'groups': <String>[]};
    }
    final tags = place.attributes.map((t)=>(data['tag_aliases'] as Map<String,dynamic>)[t] as String? ?? t).toSet();
    final food = (data['food_tags'] as List).cast<String>();
    final lodging = (data['lodging_tags'] as List).cast<String>();
    if (tags.any((t)=>food.contains(t)||lodging.contains(t))) {
      return {'excluded':true,'groups':<String>[]};
    }
    final lookup = (data['landmark_lookup'] as Map<String,dynamic>)[place.source] as Map<String,dynamic>?;
    final found = lookup?[normalize(place.name)];
    if (found is Map<String,dynamic>) return found;
    // New places can reuse an existing category without another AI call.
    final groups = <String>{};
    if (place.source == 'unesco' && place.heritageType != null) {
      final group = 'unesco_${place.heritageType!.toLowerCase()}';
      if ((data['category_axes'] as Map).containsKey(group)) groups.add(group);
    } else if (place.source == 'landmark') {
      for (final tag in tags) {
        groups.addAll(((data['tag_groups'] as Map)[tag] as List? ?? []).cast<String>());
      }
      if (groups.contains('art_museum')) groups.remove('museum');
    }
    return groups.isEmpty ? null : {'excluded':false,'groups':groups.toList()..sort()};
  }

  PersonaPlaceFeatures extract(List<PersonaCityEvidence> cities, List<PersonaLandmarkEvidence> landmarks) {
    final audit = <String,int>{};
    void count(String key) => audit[key]=(audit[key]??0)+1;
    final cityValues = <String,List<List<double>>>{};
    final eligible = cities.where((c)=>c.visits>0 && !c.hasLived && !c.isHome).toList();
    final weights = _weights([for(final c in eligible) MapEntry(c.name,c.rating)]);
    for (final city in eligible) {
      final candidates = (data['city_lookup'] as Map)[normalize(city.name)] as List? ?? [];
      if (candidates.length != 1) {count('city_unmatched_or_ambiguous'); continue;}
      final scores = (data['city_axes'] as Map)[candidates.single] as Map<String,dynamic>? ?? {};
      if (scores.isNotEmpty) count('cities_used');
      final weight = weights[city.name]!*min(3,sqrt(city.visits));
      for (final e in scores.entries) { _add(cityValues,e.key,(e.value as num).toDouble(),weight); }
    }
    final seen = <String>{};
    final visits = <MapEntry<PersonaLandmarkEvidence,List<String>>>[];
    // Same source priority as the audit: landmarks before UNESCO; stable order within each source.
    final ordered = [...landmarks.where((p)=>p.source=='landmark'), ...landmarks.where((p)=>p.source=='unesco')];
    for (final place in ordered) {
      if (!seen.add(normalize(place.name))) continue;
      final row = _resolve(place);
      if (row == null) {count('landmark_unmatched'); continue;}
      if (row['ambiguous'] == true) {count('landmark_ambiguous'); continue;}
      if (row['excluded'] == true) {count('landmark_excluded'); continue;}
      count('landmark_matched');
      final groups = (row['groups'] as List).cast<String>();
      if (groups.isNotEmpty) visits.add(MapEntry(place,groups));
    }
    final landmarkWeights = _weights([for(final v in visits) MapEntry(normalize(v.key.name),v.key.rating)]);
    final groupValues = <String,List<List<double>>>{};
    for (final visit in visits) {
      for (final group in visit.value) {
        final scores = (data['category_axes'] as Map)[group] as Map<String,dynamic>? ?? {};
        for (final e in scores.entries) {
          _add(groupValues,'$group|${e.key}',(e.value as num).toDouble(),
              landmarkWeights[normalize(visit.key.name)]!/visit.value.length);
        }
      }
    }
    final landmarkValues = <String,List<List<double>>>{};
    for (final e in groupValues.entries) {
      final weight = min(2.0,e.value.fold<double>(0,(s,v)=>s+v[1])/e.value.length);
      _add(landmarkValues,e.key.split('|')[1],_mean(e.value),weight);
    }
    return PersonaPlaceFeatures({for(final e in cityValues.entries)e.key:_mean(e.value),
      for(final e in landmarkValues.entries)e.key:_mean(e.value)},audit);
  }
}

class PersonaDistributionBalance {
  final Map<String,dynamic> data;
  PersonaDistributionBalance(this.data) {
    if (data['schema_version'] != 1) throw const FormatException('Unsupported balance profile schema');
  }
  static int _bound(List<dynamic> values, double x, bool upper) {
    var low=0, high=values.length;
    while(low<high) {
      final middle=(low+high)~/2;
      if ((values[middle] as num)<x || (upper && (values[middle] as num)==x)) {low=middle+1;} else {high=middle;}
    }
    return low;
  }
  static Map<String,double> _softmax(Map<String,double> logits) {
    final maximum=logits.values.reduce(max);
    final weights=logits.map((k,v)=>MapEntry(k,exp(v-maximum)));
    final total=weights.values.reduce((a,b)=>a+b);
    return weights.map((k,v)=>MapEntry(k,v/total));
  }
  Map<String,double> apply(Map<String,double> original) {
    final types=(data['types'] as List).cast<String>();
    if(original.length!=types.length || types.any((k)=>!original.containsKey(k)) ||
        original.values.any((v)=>!v.isFinite || v<0) || (original.values.fold<double>(0,(a,b)=>a+b)-1).abs()>1e-8) {
      throw const FormatException('Scores do not match the balance profile');
    }
    final maximum=original.values.reduce(max), minimum=original.values.reduce(min);
    if(maximum-minimum<1e-12 || maximum >= (data['preserve_top_share'] as num)) return Map.from(original);
    final strength=(data['percentile_strength'] as num).toDouble();
    final logits=<String,double>{};
    for(final type in types) {
      final value=log(max(original[type]!,1e-12));
      final reference=(data['reference_log_scores'] as Map)[type] as List;
      if((reference.last as num)-(reference.first as num)<1e-12) {logits[type]=value; continue;}
      final tolerance=(data['cdf_tolerance'] as num? ?? 1e-12).toDouble();
      final percentile=(_bound(reference,value-tolerance,false)+_bound(reference,value+tolerance,true)+1)/(2*(reference.length+1));
      logits[type]=(1-strength)*value+strength*log(percentile/(1-percentile));
    }
    final moderate=_softmax(logits);
    return _softmax({for(final type in types)type:log(max(moderate[type]!,1e-12))+(data['offsets'][type] as num)});
  }
}

class PersonaRuntimeResult {
  final Map<String,double> features;
  final PersonaPlaceFeatures places;
  final PersonaScoreResult raw, result;
  final bool balanceApplied;
  const PersonaRuntimeResult(this.features,this.places,this.raw,this.result,this.balanceApplied);
}

class PersonaRuntimeModel {
  final PersonaPlaceCatalog places;
  final PersonaDistributionBalance balance;
  PersonaRuntimeModel(Map<String,dynamic> placeData, Map<String,dynamic> balanceData)
      : places=PersonaPlaceCatalog(placeData), balance=PersonaDistributionBalance(balanceData);

  PersonaRuntimeResult score(List<dynamic> prototypes, Map<String,double> base,
      List<PersonaCityEvidence> cities, List<PersonaLandmarkEvidence> landmarks) {
    final placeFeatures=places.extract(cities,landmarks);
    final features={...base,...placeFeatures.axes};
    final raw=PersonaScorer.score(prototypes,features);
    const dna=['solo_social','nature_culture','relaxed_intensive','planned_spontaneous',
      'budget_luxury','transit_drive','documenter_minimalist','morning_night'];
    // The fitted reference consists of respondents with travel evidence.
    final eligible=raw.hasSignal && dna.every(base.containsKey) && features.keys.any((k)=>!dna.contains(k));
    if(!eligible) return PersonaRuntimeResult(features,placeFeatures,raw,raw,false);
    final adjusted=balance.apply({for(final s in raw.scores)s.id:s.score});
    final scores=[for(final s in raw.scores)PersonaScore(s.id,s.label,adjusted[s.id]!)]
      ..sort((a,b){final c=b.score.compareTo(a.score);return c==0?a.id.compareTo(b.id):c;});
    final result=PersonaScoreResult(scores,scores.first.score-scores[1].score,raw.coverage,hasSignal:raw.hasSignal);
    return PersonaRuntimeResult(features,placeFeatures,raw,result,true);
  }
}
