import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/logger.dart';
import 'package:tracker_app/models/local/sync_queue_item.dart';

class SyncService extends ChangeNotifier {
  final logger = getLogger(className: "SyncService");
  final Isar isar;
  final SupabaseClient supabase;

  bool _isSyncing = false;
  int _pendingCount = 0;
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncService({required this.isar, required this.supabase}) {
    _init();
  }

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  bool get hasPendingChanges => _pendingCount > 0;

  void _init() {
    // Update pending count
    _updatePendingCount();

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result.isNotEmpty && result.first != ConnectivityResult.none) {
        logger.i('Connectivity restored, triggering sync');
        sync();
      }
    });

    // Periodic sync every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      sync();
    });
  }

  Future<void> _updatePendingCount() async {
    _pendingCount = await isar.syncQueueItems.count();
    notifyListeners();
  }

  /// Add an item to the sync queue
  Future<void> queueSync({
    required String entityType,
    required String entityId,
    required String operation,
    required String jsonData,
  }) async {
    try {
      final item = SyncQueueItem.create(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        jsonData: jsonData,
      );

      await isar.writeTxn(() async {
        await isar.syncQueueItems.put(item);
      });

      await _updatePendingCount();
      logger.i('Queued $operation for $entityType:$entityId');

      // Trigger sync immediately (non-blocking)
      sync();
    } catch (e) {
      logger.e('Error queueing sync: $e');
    }
  }

  /// Check if device has internet connection
  Future<bool> hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.isNotEmpty && 
             connectivityResult.first != ConnectivityResult.none;
    } catch (e) {
      logger.w('Error checking connectivity: $e');
      return false;
    }
  }

  /// Main sync method - processes the queue
  Future<void> sync() async {
    if (_isSyncing) {
      logger.d('Sync already in progress, skipping');
      return;
    }

    if (!await hasInternet()) {
      logger.d('No internet connection, skipping sync');
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final queue = await isar.syncQueueItems
          .where()
          .sortByCreatedAt()
          .findAll();

      logger.i('Processing ${queue.length} items in sync queue');

      for (final item in queue) {
        try {
          await _processQueueItem(item);

          // Success: Remove from queue
          await isar.writeTxn(() async {
            await isar.syncQueueItems.delete(item.id);
          });

          logger.i('Synced ${item.operation} for ${item.entityType}:${item.entityId}');
        } catch (e) {
          // Failure: Increment retry count
          item.retryCount++;
          item.lastError = e.toString();

          await isar.writeTxn(() async {
            await isar.syncQueueItems.put(item);
          });

          logger.e('Failed to sync ${item.entityType}:${item.entityId}: $e');

          // If too many retries, log but continue
          if (item.retryCount > 10) {
            logger.e('Item ${item.id} exceeded max retries');
          }
        }
      }

      await _updatePendingCount();
    } catch (e) {
      logger.e('Error during sync: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Process a single queue item
  Future<void> _processQueueItem(SyncQueueItem item) async {
    final data = jsonDecode(item.jsonData) as Map<String, dynamic>;

    switch (item.entityType) {
      case 'exercise':
        await _syncExercise(item.operation, item.entityId, data);
        break;
      case 'log':
        await _syncLog(item.operation, item.entityId, data);
        break;
      case 'template':
        await _syncTemplate(item.operation, item.entityId, data);
        break;
      case 'plan':
        await _syncPlan(item.operation, item.entityId, data);
        break;
      default:
        logger.w('Unknown entity type: ${item.entityType}');
    }
  }

  /// Sync operations for each entity type
  Future<void> _syncExercise(String operation, String id, Map<String, dynamic> data) async {
    switch (operation) {
      case 'create':
        // Remove id field - let Supabase generate it
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('exercises').insert(dataWithoutId);
        break;
      case 'update':
        // Remove id field from updates
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('exercises').update(dataWithoutId).eq('id', id);
        break;
      case 'delete':
        await supabase.from('exercises').delete().eq('id', id);
        break;
    }
  }

  Future<void> _syncLog(String operation, String id, Map<String, dynamic> data) async {
    switch (operation) {
      case 'create':
        // Remove id field - let Supabase generate it
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('routine_logs').insert(dataWithoutId);
        break;
      case 'update':
        // Remove id field from updates
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('routine_logs').update(dataWithoutId).eq('id', id);
        break;
      case 'delete':
        await supabase.from('routine_logs').delete().eq('id', id);
        break;
    }
  }

  Future<void> _syncTemplate(String operation, String id, Map<String, dynamic> data) async {
    switch (operation) {
      case 'create':
        // Remove id field - let Supabase generate it
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('routine_templates').insert(dataWithoutId);
        break;
      case 'update':
        // Remove id field from updates
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('routine_templates').update(dataWithoutId).eq('id', id);
        break;
      case 'delete':
        await supabase.from('routine_templates').delete().eq('id', id);
        break;
    }
  }

  Future<void> _syncPlan(String operation, String id, Map<String, dynamic> data) async {
    switch (operation) {
      case 'create':
        // Remove id field - let Supabase generate it
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('routine_plans').insert(dataWithoutId);
        break;
      case 'update':
        // Remove id field from updates
        final dataWithoutId = Map<String, dynamic>.from(data)..remove('id');
        await supabase.from('routine_plans').update(dataWithoutId).eq('id', id);
        break;
      case 'delete':
        await supabase.from('routine_plans').delete().eq('id', id);
        break;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

