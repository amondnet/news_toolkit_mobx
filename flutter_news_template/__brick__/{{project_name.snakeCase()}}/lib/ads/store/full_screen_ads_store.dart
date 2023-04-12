import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:{{project_name.snakeCase()}}/ads/bloc/full_screen_ads_bloc.dart'
    show
        InterstitialAdLoader,
        RewardedAdLoader,
        FullScreenAdsConfig,
        FullScreenAdsStatus;
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:mobx/mobx.dart';
import 'package:news_blocks_ui/news_blocks_ui.dart';
import 'package:platform/platform.dart';
import 'package:retry/retry.dart';

part 'full_screen_ads_store.g.dart';

class FullScreenAdsStore = FullScreenAdsStoreBase with _$FullScreenAdsStore;

abstract class FullScreenAdsStoreBase with Store {
  FullScreenAdsStoreBase({
    required AdsRetryPolicy adsRetryPolicy,
    required InterstitialAdLoader interstitialAdLoader,
    required RewardedAdLoader rewardedAdLoader,
    required LocalPlatform localPlatform,
    FullScreenAdsConfig? fullScreenAdsConfig,
    this.interstitialAd,
    this.rewardedAd,
    this.earnedReward,
  })  : _adsRetryPolicy = adsRetryPolicy,
        _interstitialAdLoader = interstitialAdLoader,
        _rewardedAdLoader = rewardedAdLoader,
        _localPlatform = localPlatform,
        _fullScreenAdsConfig =
            fullScreenAdsConfig ?? const FullScreenAdsConfig(),
        status = FullScreenAdsStatus.initial;

  /// The retry policy for loading interstitial and rewarded ads.
  final AdsRetryPolicy _adsRetryPolicy;

  /// The config of interstitial and rewarded ads.
  final FullScreenAdsConfig _fullScreenAdsConfig;

  /// The loader of interstitial ads.
  final InterstitialAdLoader _interstitialAdLoader;

  /// The loader of rewarded ads.
  final RewardedAdLoader _rewardedAdLoader;

  /// The current platform.
  final LocalPlatform _localPlatform;

  ads.InterstitialAd? interstitialAd;
  ads.RewardedAd? rewardedAd;
  ads.RewardItem? earnedReward;

  @observable
  FullScreenAdsStatus status;

  @observable
  bool showingInterstitialAd = false;

  /// ShowInterstitialAdRequested
  @action
  Future<void> showInterstitialAd() async {
    try {
      showingInterstitialAd = true;
      interstitialAd?.fullScreenContentCallback = ads.FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) => ad.dispose(),
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          // addError(error);
        },
      );

      // Show currently available interstitial ad.
      await interstitialAd?.show();

      status = FullScreenAdsStatus.showingInterstitialAdSucceeded;
    } catch (e) {
      status = FullScreenAdsStatus.showingInterstitialAdFailed;

      // addError(error, stackTrace);
    }
  }

  Future<void> loadInterstitialAd() {
    return _adRetry(_loadInterstitialAd);
  }

  @action
  Future<void> _loadInterstitialAd() async {
    try {
      final ad = Completer<ads.InterstitialAd>();

      status = FullScreenAdsStatus.loadingInterstitialAd;

      await _interstitialAdLoader(
        adUnitId: _fullScreenAdsConfig.interstitialAdUnitId ??
            (_localPlatform.isAndroid
                ? FullScreenAdsConfig.androidTestInterstitialAdUnitId
                : FullScreenAdsConfig.iosTestInterstitialAdUnitId),
        request: const ads.AdRequest(),
        adLoadCallback: ads.InterstitialAdLoadCallback(
          onAdLoaded: ad.complete,
          onAdFailedToLoad: ad.completeError,
        ),
      );

      final adResult = await ad.future;

      status = FullScreenAdsStatus.loadingInterstitialAdSucceeded;
      interstitialAd = adResult;
    } catch (error, stackTrace) {
      status = FullScreenAdsStatus.loadingInterstitialAdFailed;

      // addError(error, stackTrace);
    }
  }

  Future<void> loadRewardedAd() async {
    return _adRetry(_loadRewardedAdRequested);
  }

  Future<T> _adRetry<T>(FutureOr<T> Function() fn) {
    final retry = RetryOptions(
      maxAttempts: _adsRetryPolicy.maxRetryCount,
      delayFactor: const Duration(seconds: 1),
    );
    return retry.retry(fn);
  }

  @action
  Future<void> _loadRewardedAdRequested() async {
    try {
      final ad = Completer<ads.RewardedAd>();

      status = FullScreenAdsStatus.loadingRewardedAd;

      await _rewardedAdLoader(
        adUnitId: _fullScreenAdsConfig.rewardedAdUnitId ??
            (_localPlatform.isAndroid
                ? FullScreenAdsConfig.androidTestRewardedAdUnitId
                : FullScreenAdsConfig.iosTestRewardedAdUnitId),
        request: const ads.AdRequest(),
        rewardedAdLoadCallback: ads.RewardedAdLoadCallback(
          onAdLoaded: ad.complete,
          onAdFailedToLoad: ad.completeError,
        ),
      );

      final adResult = await ad.future;

      rewardedAd = adResult;
      status = FullScreenAdsStatus.loadingRewardedAdSucceeded;
    } catch (error, stackTrace) {
      status = FullScreenAdsStatus.loadingRewardedAdFailed;

      // addError(error, stackTrace);
    }
  }

  Future<void> showRewardedAd() {
    return _adRetry(_showRewardedAd);
  }

  @action
  Future<void> _showRewardedAd() async {
    try {
      status = FullScreenAdsStatus.showingRewardedAd;

      rewardedAd?.fullScreenContentCallback = ads.FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) => ad.dispose(),
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          // addError(error);
        },
      );

      // Show currently available rewarded ad.
      await rewardedAd?.show(
        onUserEarnedReward: (ad, earnedReward) =>
            this.earnedReward = earnedReward,
      );

      status = FullScreenAdsStatus.showingRewardedAdSucceeded;

      // Load the next rewarded ad.
      unawaited(loadRewardedAd());
    } catch (error, stackTrace) {
      status = FullScreenAdsStatus.showingRewardedAdFailed;
      //addError(error, stackTrace);
    }
  }
}
