import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class SocialNotificationService {
  static bool _started = false;
  static Future<void> _queue = Future.value();
  static String? _token;
  static void start(
    GlobalKey<NavigatorState> navigator,
    void Function(BuildContext) openRequests,
  ) {
    if (_started) return;
    _started = true;
    Future<void> sync() async {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token == null) return;
        if (_token != null && _token != token)
          await FirebaseFunctions.instance
              .httpsCallable('socialRegisterPushToken')
              .call({'token': _token, 'unbind': true});
        _token = token;
        await FirebaseFunctions.instance
            .httpsCallable('socialRegisterPushToken')
            .call({'token': token});
      } catch (e) {
        debugPrint('Social push registration unavailable: ${e.runtimeType}');
      }
    }

    void schedule() {
      _queue = _queue.then((_) => sync());
    }

    FirebaseAuth.instance.authStateChanges().listen((_) => schedule());
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => schedule());
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] != 'social_friend_request') return;
      final context = navigator.currentContext;
      if (context == null || FirebaseAuth.instance.currentUser == null) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(tr('New friend request')),
          action: SnackBarAction(
            label: tr('View'),
            onPressed: () => openRequests(context),
          ),
        ),
      );
    });
  }
}
