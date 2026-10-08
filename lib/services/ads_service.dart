// Ads service (FREE plan only): banner + interstitial via google_mobile_ads.
// Uses Google's official TEST ad unit IDs by default — swap AdIds in
// utils/constants.dart with your real AdMob IDs before publishing.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/constants.dart';

abstract final class AdsService {
  static InterstitialAd? _interstitial;
  static int _actionCounter = 0;

  /// Loads (or reloads) an interstitial ad in the background.
  static Future<void> preloadInterstitial() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) => _interstitial = ad,
          onAdFailedToLoad: (LoadAdError error) => _interstitial = null,
        ),
      );
    } catch (_) {
      _interstitial = null;
    }
  }

  /// Shows an interstitial every N heavy actions (exports, OCR...).
  static Future<void> maybeShowInterstitial({int every = 3}) async {
    _actionCounter++;
    if (_actionCounter % every != 0) return;
    final InterstitialAd? ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    try {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          preloadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError e) {
          ad.dispose();
          preloadInterstitial();
        },
      );
      await ad.show();
    } catch (_) {
      ad.dispose();
    }
  }

  /// Creates the anchored bottom banner widget (or an empty box on failure).
  static Widget bannerAdWidget() {
    if (kIsWeb || !Platform.isAndroid) return const SizedBox.shrink();
    return const BannerAdWidgetStub();
  }
}

/// Banner widget that manages its own [BannerAd] lifecycle.
/// (Kept separate so screens can embed it with zero setup.)
class BannerAdWidgetStub extends StatefulWidget {
  const BannerAdWidgetStub({super.key});

  @override
  State<BannerAdWidgetStub> createState() => _BannerAdWidgetStubState();
}

class _BannerAdWidgetStubState extends State<BannerAdWidgetStub> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    try {
      _banner = BannerAd(
        adUnitId: AdIds.banner,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) => ad.dispose(),
        ),
      )..load();
    } catch (_) {
      _banner = null;
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _banner;
    if (ad == null || !_loaded) {
      return const SizedBox(width: 0, height: 0);
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
