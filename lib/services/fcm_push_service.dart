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
