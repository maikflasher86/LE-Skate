import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Displays an anchored AdMob banner ad at the bottom of the screen.
///
/// Uses Google's official test ad unit IDs in debug builds and the real
/// "LE Skate Banner" ad unit in release builds. Renders nothing while the
/// ad is loading, on unsupported platforms (web/desktop), or if loading
/// fails.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // TODO: Extract these ids
  static const _androidTestAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidAdUnitId = 'ca-app-pub-9626161531869858/1298204562';
  static const _iosAdUnitId = 'ca-app-pub-9626161531869858/1298204562';

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String? get _adUnitId {
    if (!_isSupportedPlatform) return null;
    if (kDebugMode) {
      return Platform.isAndroid ? _androidTestAdUnitId : _iosTestAdUnitId;
    }
    return Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final adUnitId = _adUnitId;
    if (adUnitId == null) return;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('AdMob Banner konnte nicht geladen werden: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    if (!_isLoaded || bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: bannerAd.size.width.toDouble(),
      height: bannerAd.size.height.toDouble(),
      child: AdWidget(ad: bannerAd),
    );
  }
}
