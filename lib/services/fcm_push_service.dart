import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/notathletes_auth_headers.dart';

const String _fcmBaseUrl = 'https://fcm.notathletes.com';

/// Sends a push notification request to the backend. The backend resolves
/// coach from coach_clients, device tokens, and delivers with logId in FCM data.
Future<void> sendFcmNotification({
  required String userId,
  required String logId,
  String title = 'Session logged',
  String body = 'Your client just logged a workout',
}) async {
  try {
    final uri = Uri.parse(_fcmBaseUrl).resolve('/notify-workout-log');
    final payload = jsonEncode({
      'userId': userId,
      'logId': logId,
    });
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: payload,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      // ignore: avoid_print
      print('[FCM] Push failed: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    // ignore: avoid_print
    print('[FCM] Error sending push: $e');
  }
}

/// Requests the backend to initiate a video call. Backend generates channel name,
/// sends FCM push to callee, returns channelName. Use returned channel for joining.
///
/// Send [callerName] and [callerImageUrl] so the FCM `data` payload can show who is
/// calling and a full-bleed photo on the incoming screen (omit image when none).
Future<String?> sendIncomingCallNotification({
  required String calleeUserId,
  required String callerId,
  String? callerName,
  String? callerImageUrl,
}) async {
  try {
    final uri = Uri.parse(_fcmBaseUrl).resolve('/notify-incoming-call');
    final requestMap = <String, dynamic>{
      'calleeUserId': calleeUserId,
      'callerId': callerId,
    };
    final name = callerName?.trim();
    if (name != null && name.isNotEmpty) {
      requestMap['callerName'] = name;
    }
    final imageUrl = callerImageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      requestMap['callerImageUrl'] = imageUrl;
    }
    final payload = jsonEncode(requestMap);
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: payload,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      // ignore: avoid_print
      print('[FCM] Incoming call push failed: ${response.statusCode} ${response.body}');
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['channelName'] as String?;
    }
    return null;
  } catch (e) {
    // ignore: avoid_print
    print('[FCM] Error sending incoming call push: $e');
    return null;
  }
}

/// Notifies the given client that their coach has added or updated feedback
/// on a session. Backend should deliver to the client's device tokens with logId in FCM data.
Future<void> sendFcmNotificationCoachFeedback({
  required String clientUserId,
  required String logId,
}) async {
  try {
    final uri = Uri.parse(_fcmBaseUrl).resolve('/notify-coach-feedback');
    final payload = jsonEncode({
      'userId': clientUserId,
      'logId': logId,
    });
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: payload,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      // ignore: avoid_print
      print('[FCM] Coach feedback push failed: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    // ignore: avoid_print
    print('[FCM] Error sending coach feedback push: $e');
  }
}

