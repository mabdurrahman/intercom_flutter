library intercom_flutter;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum IntercomVisibility { gone, visible }

typedef void MessageHandler(Map<String, dynamic> message);

class Intercom {
  static const MethodChannel _channel =
      const MethodChannel('maido.io/intercom');
  static MessageHandler _messageHandler;
  static const EventChannel _unreadChannel =
      const EventChannel('maido.io/intercom/unread');

  /// This is useful since end application don't need to store the token by itself.
  /// It will be send through message handler so application can use it in any way it wants.
  static String _iosDeviceToken;

  static Future<void> initialize(
    String appId, {
    String androidApiKey,
    String iosApiKey,
    MessageHandler onMessage,
  }) async {
    // Backward compatibility, show new feature in debug mode.
    if (onMessage == null && !kReleaseMode) {
      _messageHandler = (data) => print("[INTERCOM_FLUTTER] On message: $data");
    } else {
      _messageHandler = onMessage;
    }
    _channel.setMethodCallHandler(_handleMethod);
    await _channel.invokeMethod('initialize', {
      'appId': appId,
      'androidApiKey': androidApiKey,
      'iosApiKey': iosApiKey,
    });
  }

  /// Handle messages from native library.
  static Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'iosDeviceToken':
        String token = call.arguments;
        _iosDeviceToken = token;
        if (_messageHandler != null) {
          _messageHandler({"method": "iosDeviceToken", "token": token,});
        }
        return null;
      default:
        throw UnsupportedError('Unrecognized JSON message');
    }
  }

  static Stream<dynamic> getUnreadStream() {
    return _unreadChannel.receiveBroadcastStream();
  }

  /// This method allows you to set a fixed bottom padding for in app messages and the launcher.
  ///
  /// It is useful if your app has a tab bar or similar UI at the bottom of your window.
  /// [padding] is the size of the bottom padding in points.
  static Future<void> setBottomPadding(int padding) async {
    await _channel.invokeMethod('setBottomPadding', {'bottomPadding': padding});
  }

  static Future<void> setUserHash(String userHash) async {
    await _channel.invokeMethod('setUserHash', {'userHash': userHash});
  }

  static Future<void> registerIdentifiedUser({String userId, String email}) {
    if (userId?.isNotEmpty ?? false) {
      if (email?.isNotEmpty ?? false) {
        throw ArgumentError(
            'The parameter `email` must be null if `userId` is provided.');
      }
      return _channel.invokeMethod('registerIdentifiedUserWithUserId', {
        'userId': userId,
      });
    } else if (email?.isNotEmpty ?? false) {
      return _channel.invokeMethod('registerIdentifiedUserWithEmail', {
        'email': email,
      });
    } else {
      throw ArgumentError(
          'An identification method must be provided as a parameter, either `userId` or `email`.');
    }
  }

  static Future<void> registerUnidentifiedUser() async {
    await _channel.invokeMethod('registerUnidentifiedUser');
  }

  /// Updates the attributes of the current Intercom user.
  ///
  /// The [language] param should be an an ISO 639-1 two-letter code such as `en` for English or `fr` for French.
  /// You’ll need to use a four-letter code for Chinese like `zh-CN`.
  /// check this link https://www.intercom.com/help/en/articles/180-localize-intercom-to-work-with-multiple-languages.
  ///
  /// See also:
  ///  * [Localize Intercom to work with multiple languages](https://www.intercom.com/help/en/articles/180-localize-intercom-to-work-with-multiple-languages)
  static Future<void> updateUser({
    String email,
    String name,
    String phone,
    String company,
    String companyId,
    String userId,
    int signedUpAt,
    String language,
    Map<String, dynamic> customAttributes,
  }) async {
    await _channel.invokeMethod('updateUser', <String, dynamic>{
      'email': email,
      'name': name,
      'phone': phone,
      'company': company,
      'companyId': companyId,
      'userId': userId,
      'signedUpAt': signedUpAt,
      'language': language,
      'customAttributes': customAttributes,
    });
  }

  static Future<void> logout() async {
    await _channel.invokeMethod('logout');
  }

  static Future<void> setLauncherVisibility(
      IntercomVisibility visibility) async {
    String visibilityString =
        visibility == IntercomVisibility.visible ? 'VISIBLE' : 'GONE';
    await _channel.invokeMethod('setLauncherVisibility', {
      'visibility': visibilityString,
    });
  }

  static Future<int> unreadConversationCount() async {
    final result = await _channel.invokeMethod<int>('unreadConversationCount');
    return result ?? 0;
  }

  static Future<void> setInAppMessagesVisibility(
      IntercomVisibility visibility) async {
    String visibilityString =
        visibility == IntercomVisibility.visible ? 'VISIBLE' : 'GONE';
    await _channel.invokeMethod('setInAppMessagesVisibility', {
      'visibility': visibilityString,
    });
  }

  static Future<void> displayMessenger() async {
    await _channel.invokeMethod('displayMessenger');
  }

  static Future<void> hideMessenger() async {
    await _channel.invokeMethod('hideMessenger');
  }

  static Future<void> displayHelpCenter() async {
    await _channel.invokeMethod('displayHelpCenter');
  }

  static Future<void> logEvent(String name,
      [Map<String, dynamic> metaData]) async {
    await _channel
        .invokeMethod('logEvent', {'name': name, 'metaData': metaData});
  }

  static Future<void> sendTokenToIntercom(String token) async {
    assert(token.isNotEmpty);
    print("Start sending token to Intercom");
    await _channel.invokeMethod('sendTokenToIntercom', {'token': token});
  }

  /// Send stored iOS 'deviceToken' to Intercom.
  /// This is equivalent to use [sendTokenToIntercom] with iOS token as an argument.
  static Future<void> registerIosTokenToIntercom() async {
    if (_iosDeviceToken != null) {
      await sendTokenToIntercom(_iosDeviceToken);
    } else {
      throw ErrorDescription(
          "No iOS device token was generated. You have called this method before iOS generate device token or your iOS project configuration is not set up properly.");
    }
  }

  /// Get iOS 'deviceToken' stored in the plugin. You can use this method
  /// instead of listening for token using 'onMessage' method from plugin configuration.
  /// Returns null if token is not available.
  static Future<String> getIosToken() async {
    final result = await Future.value(_iosDeviceToken);
    return result;
  }

  static Future<void> handlePushMessage() async {
    await _channel.invokeMethod('handlePushMessage');
  }

  static Future<void> displayMessageComposer(String message) async {
    await _channel.invokeMethod('displayMessageComposer', {'message': message});
  }

  static Future<bool> isIntercomPush(Map<String, dynamic> message) async {
    if (!message.values.every((item) => item is String)) {
      return false;
    }
    final result = await _channel
        .invokeMethod<bool>('isIntercomPush', {'message': message});
    return result ?? false;
  }

  static Future<void> handlePush(Map<String, dynamic> message) async {
    if (!message.values.every((item) => item is String)) {
      throw new ArgumentError(
          'Intercom push messages can only have string values');
    }

    return await _channel
        .invokeMethod<void>('handlePush', {'message': message});
  }

  /// Show native iOS popup for user that requests notifications permissions.
  /// If user denies he we won't receive any notifications.
  /// If users denies, calling this multiple times won't work. He needs to enter
  /// settings, find your application and turn notifications by himself.
  /// Return true if permissions are granted.
  static Future<bool> requestIosNotificationPermissions() async {
    final result = await _channel.invokeMethod('requestNotificationPermissions');
    return result ?? false;
  }

  static Future<void> displayArticle(String articleId) async {
    await _channel.invokeMethod('displayArticle', {'articleId': articleId});
  }

  static Future<void> displayCarousel(String carouselId) async {
    await _channel.invokeMethod('displayCarousel', {'carouselId': carouselId});
  }
}
