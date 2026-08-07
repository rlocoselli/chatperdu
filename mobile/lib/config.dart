class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL',
      defaultValue: 'http://10.0.2.2:5000/api');
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL',
      defaultValue: 'https://example.fr/confidentialite');
  static const productionAds =
      bool.fromEnvironment('PRODUCTION_ADS', defaultValue: false);
  static const androidBanner = String.fromEnvironment('ADMOB_ANDROID_BANNER',
      defaultValue: 'ca-app-pub-3940256099942544/6300978111');
  static const iosBanner = String.fromEnvironment('ADMOB_IOS_BANNER',
      defaultValue: 'ca-app-pub-3940256099942544/2934735716');
  static const androidInterstitial = String.fromEnvironment(
      'ADMOB_ANDROID_INTERSTITIAL',
      defaultValue: 'ca-app-pub-3940256099942544/1033173712');
  static const iosInterstitial = String.fromEnvironment(
      'ADMOB_IOS_INTERSTITIAL',
      defaultValue: 'ca-app-pub-3940256099942544/4411468910');
}
