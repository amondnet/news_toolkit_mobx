import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_news_example/analytics/analytics.dart';
import 'package:flutter_news_example/app/store/app_store.dart';
import 'package:mobx/mobx.dart';

class AuthenticatedUserListener extends StatelessWidget {
  const AuthenticatedUserListener({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ReactionBuilder(
      child: child,
      builder: (_) {
        return reaction((_) => context.read<AppStore>().status, (status) {
          if (status.isLoggedIn) {
            context.read<AnalyticsBloc>().add(
                  TrackAnalyticsEvent(
                    context.read<AppStore>().user.isNewUser
                        ? RegistrationEvent()
                        : LoginEvent(),
                  ),
                );
          }
        });
      },
    );
  }
}
