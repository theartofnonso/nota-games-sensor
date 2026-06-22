import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/nota_games_config.dart';
import '../models/motion_sample.dart';
import '../models/player_session.dart';
import '../services/session_service.dart';

/// Samples the user accelerometer, batches raw data, and uploads via [SessionService].
///
/// Start / pause / stop are driven exclusively by [SessionManager] — not by UI.
class MotionService extends ChangeNotifier {
  MotionService({SessionService? sessionService})
      : _sessionService = sessionService ?? SessionService();

  final SessionService _sessionService;
  final Queue<MotionBatch> _uploadQueue = Queue<MotionBatch>();

  PlayerSession? _session;
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  Timer? _sampleTimer;
  Timer? _batchTimer;
  Timer? _retryTimer;

  bool _hasPendingSample = false;
  double _pendingX = 0;
  double _pendingY = 0;
  double _pendingZ = 0;
  String? _sensorError;

  bool _collecting = false;
  bool _uploading = false;

  final List<MotionSample> _currentBatch = [];
  int? _batchStartedAtMs;

  String? get sensorError => _sensorError;
  bool get isCollecting => _collecting;

  void configure(PlayerSession session) {
    _session = session;
  }

  Future<void> start() async {
    if (_collecting) return;
    _sensorError = null;

    try {
      await _tearDownSensor();

      _subscription = userAccelerometerEventStream().listen(
        (event) {
          _pendingX = event.x;
          _pendingY = event.y;
          _pendingZ = event.z;
          _hasPendingSample = true;
        },
        onError: (Object e) {
          _sensorError = 'Motion sensor unavailable: $e';
          pause();
        },
      );

      _sampleTimer = Timer.periodic(
        NotaGamesConfig.motionSampleInterval,
        (_) => _onSampleTick(),
      );
      _batchTimer = Timer.periodic(
        NotaGamesConfig.motionBatchInterval,
        (_) => _enqueueCurrentBatch(),
      );
      _retryTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _drainUploadQueue(),
      );

      _collecting = true;
      notifyListeners();
    } catch (e) {
      _sensorError = 'Could not start motion sensor: $e';
      await _tearDownSensor();
      notifyListeners();
    }
  }

  Future<void> pause() async {
    _enqueueCurrentBatch();
    await _tearDownSensor();
    _collecting = false;
    notifyListeners();
  }

  Future<void> stop() async {
    _enqueueCurrentBatch();
    await _tearDownSensor();
    _collecting = false;
    await _drainUploadQueue();
    notifyListeners();
  }

  Future<void> _tearDownSensor() async {
    await _subscription?.cancel();
    _subscription = null;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _hasPendingSample = false;
  }

  void _onSampleTick() {
    if (!_hasPendingSample || !_collecting) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _batchStartedAtMs ??= timestamp;

    _currentBatch.add(
      MotionSample(
        timestamp: timestamp,
        x: _pendingX,
        y: _pendingY,
        z: _pendingZ,
      ),
    );
  }

  void _enqueueCurrentBatch() {
    final session = _session;
    if (session == null || _currentBatch.isEmpty) {
      _currentBatch.clear();
      _batchStartedAtMs = null;
      return;
    }

    final batchStartedAt = _batchStartedAtMs ?? _currentBatch.first.timestamp;
    final batch = MotionBatch(
      playerId: session.playerId,
      playerName: session.playerName,
      batchStartedAt: batchStartedAt,
      batchEndedAt: DateTime.now().millisecondsSinceEpoch,
      sampleRateHz: NotaGamesConfig.motionSampleRateHz,
      samples: List<MotionSample>.from(_currentBatch),
    );

    _currentBatch.clear();
    _batchStartedAtMs = null;
    _uploadQueue.addLast(batch);
    _drainUploadQueue();
  }

  Future<void> _drainUploadQueue() async {
    if (_uploading || _uploadQueue.isEmpty) return;
    final session = _session;
    if (session == null) return;

    _uploading = true;
    try {
      while (_uploadQueue.isNotEmpty) {
        final batch = _uploadQueue.first;
        await _sessionService.uploadMotion(session.sessionId, batch);
        _uploadQueue.removeFirst();
      }
    } on SessionJoinForbiddenException {
      _uploadQueue.clear();
      rethrow;
    } finally {
      _uploading = false;
    }
  }

  @override
  void dispose() {
    _enqueueCurrentBatch();
    _subscription?.cancel();
    _sampleTimer?.cancel();
    _batchTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
