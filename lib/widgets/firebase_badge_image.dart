import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class _BadgeImageCacheManager {
  static const key = 'badgeImageDiskCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 180),
      maxNrOfCacheObjects: 700,
    ),
  );
}

class _BadgeImageUrlCache {
  static final Map<String, String> _resolved = {};
  static final Map<String, Future<String>> _inFlight = {};

  static Future<String> getUrl(String storagePath) {
    debugPrint('');
    debugPrint('🔥🔥🔥 [FBI URL] getUrl() CALLED');
    debugPrint('🔥 [FBI URL] storagePath="$storagePath"');

    final cached = _resolved[storagePath];
    if (cached != null) {
      debugPrint('🟠 [FBI URL] MEMORY CACHE HIT');
      debugPrint('🟠 [FBI URL] url="$cached"');
      return Future.value(cached);
    }

    final inFlight = _inFlight[storagePath];
    if (inFlight != null) {
      debugPrint('🟠 [FBI URL] IN-FLIGHT REQUEST REUSED');
      return inFlight;
    }

    debugPrint('🔵 [FBI URL] FirebaseStorage.getDownloadURL START');

    final future = FirebaseStorage.instance
        .ref(storagePath)
        .getDownloadURL()
        .then((url) {
      debugPrint('✅✅✅ [FBI URL] getDownloadURL SUCCESS');
      debugPrint('✅ [FBI URL] storagePath="$storagePath"');
      debugPrint('✅ [FBI URL] url="$url"');

      final uri = Uri.tryParse(url);
      debugPrint('✅ [FBI URL] uri=$uri');
      debugPrint('✅ [FBI URL] scheme=${uri?.scheme}');
      debugPrint('✅ [FBI URL] host=${uri?.host}');

      if (url.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
        debugPrint('🔴🔴🔴 [FBI URL] INVALID DOWNLOAD URL !!!');
        debugPrint('🔴 [FBI URL] url="$url"');
      }

      _resolved[storagePath] = url;
      _inFlight.remove(storagePath);
      return url;
    }).catchError((Object e, StackTrace st) {
      debugPrint('🔴🔴🔴 [FBI URL] getDownloadURL FAILED');
      debugPrint('🔴 [FBI URL] storagePath="$storagePath"');
      debugPrint('🔴 [FBI URL] error=$e');
      debugPrint('🔴 [FBI URL] stack=$st');
      _inFlight.remove(storagePath);
      throw e;
    });

    _inFlight[storagePath] = future;
    return future;
  }
}

class FirebaseBadgeImage extends StatelessWidget {
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

  String get _storagePath {
    final rel =
    imagePath.startsWith('assets/') ? imagePath.substring(7) : imagePath;
    return 'badge_images/$rel';
  }

  Widget _loadingPlaceholder() {
    debugPrint('⏳ [FBI] loading placeholder: "$imagePath" -> "$_storagePath"');
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _errorFallback() {
    debugPrint('⚠️ [FBI] Firebase failed. Trying local asset="$imagePath"');

    return Image.asset(
      imagePath,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('🔴🔴🔴 [FBI] LOCAL ASSET FAILED');
        debugPrint('🔴 [FBI] imagePath="$imagePath"');
        debugPrint('🔴 [FBI] error=$error');
        debugPrint('🔴 [FBI] stack=$stackTrace');

        return Container(
          width: width,
          height: height,
          color: Colors.red[50],
          child: const Center(
            child: Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('');
    debugPrint('####################################################');
    debugPrint('🔥🔥🔥 [FirebaseBadgeImage] BUILD CALLED');
    debugPrint('🔥 [FBI] raw imagePath="$imagePath"');
    debugPrint('🔥 [FBI] storagePath="$_storagePath"');
    debugPrint('🔥 [FBI] width=$width height=$height');

    if (imagePath.isEmpty) {
      debugPrint('🔴🔴🔴 [FBI] imagePath IS EMPTY');
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      debugPrint('🟠 [FBI] WARNING: imagePath is already a network URL');
    }

    debugPrint('####################################################');

    return FutureBuilder<String>(
      future: _BadgeImageUrlCache.getUrl(_storagePath),
      builder: (context, snapshot) {
        debugPrint(
          '🔵 [FBI FutureBuilder] '
              'path="$imagePath" '
              'state=${snapshot.connectionState} '
              'hasData=${snapshot.hasData} '
              'hasError=${snapshot.hasError}',
        );

        if (snapshot.connectionState != ConnectionState.done) {
          return _loadingPlaceholder();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint('🔴 [FBI FutureBuilder] URL RESOLVE FAILED');
          debugPrint('🔴 [FBI FutureBuilder] error=${snapshot.error}');
          return _errorFallback();
        }

        final url = snapshot.data!;
        final uri = Uri.tryParse(url);

        debugPrint('🟢 [FBI] RESOLVED URL="$url"');
        debugPrint('🟢 [FBI] scheme=${uri?.scheme} host=${uri?.host}');

        if (url.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
          debugPrint('🔴🔴🔴 [FBI] REFUSING INVALID URL');
          debugPrint('🔴 [FBI] url="$url"');
          return _errorFallback();
        }

        return CachedNetworkImage(
          imageUrl: url,
          cacheManager: _BadgeImageCacheManager.instance,
          fit: fit,
          width: width,
          height: height,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) {
            debugPrint('⏳ [FBI CachedNetworkImage] placeholder url="$url"');
            return _loadingPlaceholder();
          },
          imageBuilder: (context, imageProvider) {
            debugPrint('✅✅✅ [FBI CachedNetworkImage] IMAGE SUCCESS');
            debugPrint('✅ [FBI] imagePath="$imagePath"');
            debugPrint('✅ [FBI] storagePath="$_storagePath"');
            debugPrint('✅ [FBI] url="$url"');

            return Image(
              image: imageProvider,
              fit: fit,
              width: width,
              height: height,
            );
          },
          errorWidget: (context, url, error) {
            debugPrint('🔴🔴🔴 [FBI CachedNetworkImage] IMAGE FAILED');
            debugPrint('🔴 [FBI] imagePath="$imagePath"');
            debugPrint('🔴 [FBI] storagePath="$_storagePath"');
            debugPrint('🔴 [FBI] url="$url"');
            debugPrint('🔴 [FBI] error=$error');
            return _errorFallback();
          },
        );
      },
    );
  }
}
