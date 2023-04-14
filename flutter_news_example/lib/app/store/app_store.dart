import 'dart:async';

import 'package:in_app_purchase_repository/in_app_purchase_repository.dart';
import 'package:mobx/mobx.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'app_status.dart';

// name: AppStore
// Include generated file
part 'app_store.g.dart';

// This is the class used by rest of your codebase
class AppStore = AppStoreBase with _$AppStore;

// The store-class
abstract class AppStoreBase with Store {
  AppStoreBase({
    required UserRepository userRepository,
    required NotificationsRepository notificationsRepository,
    required User user,
  })  : _userRepository = userRepository,
        _notificationsRepository = notificationsRepository {
    if (user == User.anonymous) {
      _unauthenticated();
    } else {
      _authenticated(user);
    }

    _userSubscription = _userRepository.user.listen(_userChanged);
  }

  /// The number of app opens after which the login overlay is shown
  /// for an unauthenticated user.
  static const _appOpenedCountForLoginOverlay = 5;

  final UserRepository _userRepository;
  final NotificationsRepository _notificationsRepository;

  late StreamSubscription<User> _userSubscription;

  @readonly
  late AppStatus _status;
  @readonly
  late User _user;
  @readonly
  bool _showLoginOverlay = false;

  @computed
  bool get isUserSubscribed => _user.subscriptionPlan != SubscriptionPlan.none;

  void _userChanged(User user) => changeUser(user);

  @action
  void changeUser(User user) {
    switch (_status) {
      case AppStatus.onboardingRequired:
      case AppStatus.authenticated:
      case AppStatus.unauthenticated:
        if (user != User.anonymous && user.isNewUser) {
          _onboardingRequired(user);
        } else if (user == User.anonymous) {
          _unauthenticated();
        } else {
          _authenticated(user);
        }
    }
  }

  @action
  void completeOnboarding() {
    if (_status == AppStatus.onboardingRequired) {
      if (_user == User.anonymous) {
        _unauthenticated();
      } else {
        _authenticated(_user);
      }
    }
  }

  @action
  Future<void> openApp() async {
    if (_user.isAnonymous) {
      final appOpenedCount = await _userRepository.fetchAppOpenedCount();

      if (appOpenedCount == _appOpenedCountForLoginOverlay - 1) {
        _showLoginOverlay = true;
      }

      if (appOpenedCount < _appOpenedCountForLoginOverlay + 1) {
        await _userRepository.incrementAppOpenedCount();
      }
    }
  }

  void dispose() {
    _userSubscription.cancel();
  }

  void _unauthenticated() {
    _status = AppStatus.unauthenticated;
    _user = User.anonymous;
    _showLoginOverlay = false;
  }

  void _onboardingRequired(User user) {
    _status = AppStatus.unauthenticated;
    _user = user;
    _showLoginOverlay = false;
  }

  void _authenticated(User user) {
    _status = AppStatus.authenticated;
    _user = user;
    _showLoginOverlay = false;
  }

  void logout() {
    // We are disabling notifications when a user logs out because
    // the user should not receive any notifications when logged out.
    unawaited(_notificationsRepository.toggleNotifications(enable: false));

    unawaited(_userRepository.logOut());
  }
}
