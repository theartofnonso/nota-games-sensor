import 'package:flutter/material.dart';

import '../dtos/appsync/exercise_dto.dart';

/// AI chat message: either from the coach (user) or the AI.
class AiChatMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final ExerciseDto? attachedExercise;

  AiChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.attachedExercise,
  });
}

/// Persists AI chat messages per client for the app lifetime.
/// Messages survive closing the chat sheet; cleared when app is killed.
class CoachAiChatController extends ChangeNotifier {
  final Map<String, List<AiChatMessage>> _messagesByClientId = {};
  final Map<String, bool> _loadingByClientId = {};

  List<AiChatMessage> messagesFor(String clientId) {
    return List.unmodifiable(_messagesByClientId[clientId] ?? []);
  }

  bool isLoadingFor(String clientId) {
    return _loadingByClientId[clientId] ?? false;
  }

  void addUserMessage({
    required String clientId,
    required String text,
    ExerciseDto? attachedExercise,
  }) {
    _messagesByClientId.putIfAbsent(clientId, () => []);
    _messagesByClientId[clientId]!.add(AiChatMessage(
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
      attachedExercise: attachedExercise,
    ));
    _loadingByClientId[clientId] = true;
    notifyListeners();
  }

  void addAiResponse({required String clientId, required String text}) {
    _messagesByClientId.putIfAbsent(clientId, () => []);
    _messagesByClientId[clientId]!.add(AiChatMessage(
      isUser: false,
      text: text,
      timestamp: DateTime.now(),
    ));
    _loadingByClientId[clientId] = false;
    notifyListeners();
  }

  void setLoading(String clientId, bool loading) {
    _loadingByClientId[clientId] = loading;
    notifyListeners();
  }

  void clearForClient(String clientId) {
    _messagesByClientId.remove(clientId);
    _loadingByClientId.remove(clientId);
    notifyListeners();
  }
}
