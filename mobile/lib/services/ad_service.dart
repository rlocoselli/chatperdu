import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config.dart';

class AdService {
  InterstitialAd? _interstitial;
  bool _started = false;
  String get bannerId =>
      Platform.isIOS ? AppConfig.iosBanner : AppConfig.androidBanner;
  String get interstitialId => Platform.isIOS
      ? AppConfig.iosInterstitial
      : AppConfig.androidInterstitial;

  Future<void> requestConsentAndStart() async {
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
      ConsentForm.loadAndShowConsentFormIfRequired((_) async {
        if (await ConsentInformation.instance.canRequestAds()) _start();
      });
    }, (_) async {
      if (await ConsentInformation.instance.canRequestAds()) _start();
    });
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    await MobileAds.instance.initialize();
    loadInterstitial();
  }

  void loadInterstitial() => InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (ad) {
        _interstitial = ad;
        ad.fullScreenContentCallback =
            FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitial();
        }, onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          loadInterstitial();
        });
      }, onAdFailedToLoad: (_) {
        _interstitial = null;
      }));
  void showAtNaturalTransition() {
    final ad = _interstitial;
    _interstitial = null;
    ad?.show();
  }

  Future<void> showPrivacyOptions() =>
      ConsentForm.showPrivacyOptionsForm((_) {});
}
