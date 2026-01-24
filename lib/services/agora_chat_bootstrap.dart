import 'package:agora_chat_sdk/agora_chat_sdk.dart';

import '../config/chat_config.dart';

class AgoraChatBootstrap {
  static bool _initialized = false;
  static Future<void>? _initializing;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_initializing != null) {
      await _initializing;
      return;
    }
    _initializing = _init();
    await _initializing;
  }

  static Future<void> _init() async {
    if (ChatConfig.agoraAppKey.isEmpty) {
      throw Exception('Agora app key is not configured.');
    }
    final options = ChatOptions(
      appKey: ChatConfig.agoraAppKey,
      autoLogin: false,
    );
    await ChatClient.getInstance.init(options);
    _initialized = true;
  }
}
