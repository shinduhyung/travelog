// lib/widgets/firebase_badge_image.dart
//
// 뱃지 이미지를 Firebase Storage에서 받아오는 공용 위젯.
// achievement.imagePath에 들어있는 기존 로컬 asset 경로
// (예: 'assets/top_landmarks_badge/landmark_eiffel_tower.png')를
// 그대로 받아서 'assets/' 접두어만 떼고 Storage 경로로 변환한다.
//
// [설계]
// - Firebase Storage가 기본이자 유일한 소스. 새로 추가한 뱃지 이미지 폴더들
//   (top_landmarks_badge, new_country_badges, badge_airports, badge_airlines,
//   new_city_badges)은 pubspec.yaml에서 제외돼서 로컬 asset 자체가 앱에 없다.
//   그래서 이 뱃지들은 사실상 Firebase에서만 받아온다 — 실패하면 로컬로 조용히
//   숨겨지지 않고 아래 에러 상태가 그대로 드러나서, Firebase 연동이 실제로
//   되고 있는지 눈으로 바로 확인할 수 있다.
// - assets/badges/ (기존에 있던 뱃지들)는 아직 로컬 번들에 남아있고 아직
//   Firebase에 안 올라간 것들도 있어서, 그 폴더 대상으로만 로컬 폴백이 의미가
//   있다 — 그래서 폴백 자체는 지우지 않고 유지한다(존재하지 않는 파일이면
//   폴백도 자연히 실패해서 에러 상태로 이어짐).
// - 한 번 받아온 이미지는 CachedNetworkImage(내부적으로 flutter_cache_manager)가
//   기기 디스크에 캐싱해서, 이후에는 Firebase를 다시 안 부르고 로컬 캐시에서
//   바로 뜬다 — 다른 네트워크 이미지랑 동일한 동작.
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// [추가] 뱃지 전용 디스크 캐시 매니저.
// CachedNetworkImage가 아무 설정 없이 쓰는 기본 캐시 매니저는
// maxNrOfCacheObjects가 200으로 낮아서, 뱃지 이미지가 523개나 되면
// 앱의 다른 네트워크 이미지들이랑 캐시 슬롯을 다투다가 오래된 뱃지가
// 밀려나 재다운로드되는 일이 생긴다. 뱃지 전용 매니저를 따로 둬서
// 이 경합 자체를 없앤다. 뱃지 이미지는 한번 올리면 안 바뀌는 종류라
// 보관 기간(stalePeriod)도 길게 잡았다.
class _BadgeImageCacheManager {
  static const key = 'badgeImageDiskCache';
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 180),
      maxNrOfCacheObjects: 700, // 현재 523개 + 여유분
    ),
  );
}

/// getDownloadURL() 호출은 네트워크 요청이라 매 rebuild마다 다시 부르면
/// 비용이 크다. 앱 세션 동안 메모리에 캐싱해서 같은 경로는 한 번만 요청한다.
class _BadgeImageUrlCache {
  static final Map<String, String> _resolved = {};
  static final Map<String, Future<String>> _inFlight = {};

  static Future<String> getUrl(String storagePath) {
    final cached = _resolved[storagePath];
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlight[storagePath];
    if (inFlight != null) return inFlight;

    final future = FirebaseStorage.instance
        .ref(storagePath)
        .getDownloadURL()
        .then((url) {
      _resolved[storagePath] = url;
      _inFlight.remove(storagePath);
      return url;
    }).catchError((Object e) {
      _inFlight.remove(storagePath);
      throw e;
    });

    _inFlight[storagePath] = future;
    return future;
  }
}

class FirebaseBadgeImage extends StatelessWidget {
  /// 기존 Achievement.imagePath 값 그대로 넘기면 됨
  /// (예: 'assets/top_landmarks_badge/landmark_eiffel_tower.png')
  final String imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;

  const FirebaseBadgeImage({
    Key? key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  // Storage 상의 경로: 'assets/' 접두어를 떼고 'badge_images/' 밑에 그대로 미러링.
  // 예: assets/top_landmarks_badge/x.png -> badge_images/top_landmarks_badge/x.png
  String get _storagePath {
    final rel =
    imagePath.startsWith('assets/') ? imagePath.substring(7) : imagePath;
    return 'badge_images/$rel';
  }

  // 로딩 중 표시 — 로컬 asset을 미리 보여주지 않는다 (제거된 폴더는 애초에
  // 로컬에 없기도 하고, 있어도 "일단 로컬 → 나중에 Firebase로 교체"하는
  // 깜빡임 없이 깔끔하게 로딩 상태만 보여주기 위함).
  Widget _loadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      ),
    );
  }

  // 최종 실패 상태 — 로컬 폴백(assets/badges/처럼 아직 로컬에 남아있는 것들
  // 대상)까지 시도해보고, 그마저 없으면 명확한 에러 표시로 끝난다. 조용히
  // 아무것도 안 뜨는 상태가 절대 되지 않도록.
  Widget _errorFallback() {
    return Image.asset(
      imagePath,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.red[50],
          width: width,
          height: height,
          child: const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 22),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _BadgeImageUrlCache.getUrl(_storagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loadingPlaceholder();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _errorFallback();
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          cacheManager: _BadgeImageCacheManager.instance,
          fit: fit,
          width: width,
          height: height,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => _loadingPlaceholder(),
          errorWidget: (context, url, error) => _errorFallback(),
        );
      },
    );
  }
}