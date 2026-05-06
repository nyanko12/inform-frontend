import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiService _api;
  bool _initialized = false;

  FcmService(this._api);

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      try {
        await _api.updateFcmToken(token);
      } catch (_) {}
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await _api.updateFcmToken(newToken);
      } catch (_) {}
    });
  }
}
