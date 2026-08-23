// lib/models/badge_model.dart

enum AchievementCategory {
  Country,
  City,
  Flight,
  Landmarks,
}

enum AchievementDifficulty {
  Rookie,
  Explorer,
  Nomad,
  Adventurer,
  Globetrotter,
  Worldmaster,
  Legend,
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final AchievementDifficulty difficulty;
  final int points; // Points awarded for this achievement
  final String imagePath;
  final AchievementCategory category;
  bool isUnlocked;

  // [추가] 이 뱃지를 실제로 획득(claim)하려면 프리미엄 구독이 필요한지 여부.
  // 조건 자체는 구독 여부와 무관하게 계산되고, 실제 isUnlocked 전환만 막는다.
  final bool requiresSubscription;

  // [추가] 조건(targetCount/targetIsoCodes 등)을 실제로 다 채웠는지 여부.
  // requiresSubscription이 true인데 구독이 안 되어 있으면 isUnlocked는 false로
  // 유지되지만, 이 필드는 true가 되어 "완료했지만 잠긴" UI 상태를 구분할 수 있게 해준다.
  // Firestore에 저장하지 않는 런타임 전용 플래그.
  bool conditionsMet;

  // Total count required for the achievement (e.g., 10 countries visited)
  final int? targetCount;
  // Specific ISO codes required for the achievement (e.g., list of World Cup winners)
  final Set<String>? targetIsoCodes;

  // Population-based achievement field
  final int? targetPopulationLimit;

  // Area-based achievement field (in km²)
  final int? targetAreaLimit;

  // GDP-based achievement field (in USD)
  final double? targetGdpLimit;

  // New requirement fields for beginner achievements
  final bool requiresHome;
  final bool requiresRating;
  final bool requiresCulturalLandmark;
  final bool requiresNaturalLandmark;
  final bool requiresAirportRating;
  final bool requiresAirportHub;
  final bool requiresAirlineRating;
  final bool requiresBusinessClass;
  final bool requiresFirstClass;

  // Landmark and UNESCO count requirements
  final int? requiresLandmarkCount;
  final int? requiresUnescoCount;
  final bool requiresCulturalUnescoSite;
  final bool requiresNaturalUnescoSite;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.points,
    required this.imagePath,
    required this.category,
    this.isUnlocked = false,
    this.requiresSubscription = false,
    this.conditionsMet = false,
    this.targetCount,
    this.targetIsoCodes,
    this.targetPopulationLimit,
    this.targetAreaLimit,
    this.targetGdpLimit,
    this.requiresHome = false,
    this.requiresRating = false,
    this.requiresCulturalLandmark = false,
    this.requiresNaturalLandmark = false,
    this.requiresAirportRating = false,
    this.requiresAirportHub = false,
    this.requiresAirlineRating = false,
    this.requiresBusinessClass = false,
    this.requiresFirstClass = false,
    this.requiresLandmarkCount,
    this.requiresUnescoCount,
    this.requiresCulturalUnescoSite = false,
    this.requiresNaturalUnescoSite = false,
  });
}