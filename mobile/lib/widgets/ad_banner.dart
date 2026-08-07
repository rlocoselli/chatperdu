import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class AdBanner extends StatefulWidget {
  final AdService ads;
  const AdBanner({super.key, required this.ads});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? ad;
  @override
  void initState() {
    super.initState();
    ConsentInformation.instance.canRequestAds().then((ok) {
      if (!ok) return;
      BannerAd(
          size: AdSize.banner,
          adUnitId: widget.ads.bannerId,
          listener: BannerAdListener(onAdLoaded: (a) {
            if (mounted) setState(() => ad = a as BannerAd);
          }, onAdFailedToLoad: (a, _) {
            a.dispose();
          }),
          request: const AdRequest())
        ..load();
    });
  }

  @override
  void dispose() {
    ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ad == null
      ? const SizedBox.shrink()
      : SafeArea(
          top: false,
          child: SizedBox(
              width: ad!.size.width.toDouble(),
              height: ad!.size.height.toDouble(),
              child: AdWidget(ad: ad!)));
}
