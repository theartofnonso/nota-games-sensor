import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_template_dto.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_routine_template_repository.dart';
import 'routine_template_local_entry.dart';
import 'routine_template_local_store.dart';

/// Offline-first repository for [RoutineTemplateDto].
class OfflineRoutineTemplateRepository {
  OfflineRoutineTemplateRepository({
    RoutineTemplateLocalStore? localStore,
    SupabaseRoutineTemplateRepository? remoteRepository,
    SupabaseClient? client,
  })  : _localStore = localStore ?? RoutineTemplateLocalStore(),
        _remoteRepository =
            remoteRepository ?? SupabaseRoutineTemplateRepository(),
        _client = client ?? Supabase.instance.client;

  final RoutineTemplateLocalStore _localStore;
  final SupabaseRoutineTemplateRepository _remoteRepository;
  final SupabaseClient _client;
  final _logger = getLogger(className: 'OfflineRoutineTemplateRepository');

  List<RoutineTemplateLocalEntry> _entries = const [];

  List<RoutineTemplateDto> get offlineTemplates =>
      _entries.where((e) => !e.isDeleted).map((e) => e.template).toList();

  Future<void> loadFromCache() async {
    _entries = await _localStore.loadAll();
  }

  Future<void> syncNow() async {
    _logger.i('Starting routine template sync');

    _entries = await _localStore.loadAll();

    await _pushLocalChanges();
    await _pullRemoteChanges();

    await _localStore.saveAll(_entries);

    _logger.i(
        'Routine template sync completed. Local templates: ${offlineTemplates.length}');
  }

  Future<void> upsertLocal(RoutineTemplateDto template) async {
    final now = DateTime.now().toUtc();
    final index = _entries.indexWhere((e) => e.template.id == template.id);

    if (index == -1) {
      _entries = [
        ..._entries,
        RoutineTemplateLocalEntry(
          template: template,
          updatedAt: now,
          isDeleted: false,
          needsSync: true,
        ),
      ];
    } else {
      final existing = _entries[index];
      _entries = [
        ..._entries.sublist(0, index),
        existing.copyWith(
          template: template,
          updatedAt: now,
          isDeleted: false,
          needsSync: true,
          lastSyncFailed: false,
        ),
        ..._entries.sublist(index + 1),
      ];
    }

    await _localStore.saveAll(_entries);
  }

  Future<void> deleteLocal(String templateId) async {
    final index = _entries.indexWhere((e) => e.template.id == templateId);
    if (index == -1) return;

    final existing = _entries[index];
    final now = DateTime.now().toUtc();

    _entries = [
      ..._entries.sublist(0, index),
      existing.copyWith(
        updatedAt: now,
        isDeleted: true,
        needsSync: true,
      ),
      ..._entries.sublist(index + 1),
    ];

    await _localStore.saveAll(_entries);
  }

  Future<void> _pushLocalChanges() async {
    final pending = _entries.where((e) => e.needsSync).toList();
    if (pending.isEmpty) {
      _logger.i('No local routine template changes to push');
      return;
    }

    _logger.i('Pushing ${pending.length} local routine template changes');

    for (final entry in pending) {
      try {
        if (entry.isDeleted) {
          await _client
              .from('routine_templates')
              .delete()
              .eq('id', entry.template.id);
          _entries = _entries
              .where((e) => e.template.id != entry.template.id)
              .toList();
        } else {
          await _client
              .from('routine_templates')
              .upsert(entry.template.toJson());

          final index =
              _entries.indexWhere((e) => e.template.id == entry.template.id);
          if (index != -1) {
            final current = _entries[index];
            _entries = [
              ..._entries.sublist(0, index),
              current.copyWith(
                needsSync: false,
                lastSyncFailed: false,
              ),
              ..._entries.sublist(index + 1),
            ];
          }
        }
      } catch (e, stackTrace) {
        _logger.w(
          'Failed to push local routine template change for ${entry.template.id}: $e\n$stackTrace',
        );

        final index =
            _entries.indexWhere((e) => e.template.id == entry.template.id);
        if (index != -1) {
          final current = _entries[index];
          _entries = [
            ..._entries.sublist(0, index),
            current.copyWith(lastSyncFailed: true),
            ..._entries.sublist(index + 1),
          ];
        }
      }
    }
  }

  Future<void> _pullRemoteChanges() async {
    try {
      await _remoteRepository.loadTemplates();
      final remoteTemplates = _remoteRepository.templates;

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.w('Skipping routine template pull: no authenticated user');
        return;
      }

      final rawRows = await _client
          .from('routine_templates')
          .select('id, "updatedAt"')
          .or('owner.eq.$userId,clientId.eq.$userId');

      final updatedAtById = <String, DateTime>{};
      for (final row in rawRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final updatedAtStr = map['updatedAt'] as String;
        updatedAtById[id] = DateTime.parse(updatedAtStr);
      }

      final byId = {for (final e in _entries) e.template.id: e};

      // Track which remote IDs we've seen
      final remoteIds = <String>{};

      for (final remote in remoteTemplates) {
        remoteIds.add(remote.id);
        final remoteUpdatedAt =
            updatedAtById[remote.id] ?? DateTime.now().toUtc();
        final local = byId[remote.id];

        if (local == null) {
          byId[remote.id] = RoutineTemplateLocalEntry(
            template: remote,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
          );
          continue;
        }

        if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          byId[remote.id] = local.copyWith(
            template: remote,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
            lastSyncFailed: false,
          );
        }
      }

      // Remove entries that are marked deleted locally and have been successfully deleted from the server
      byId.removeWhere((_, entry) => entry.isDeleted && !entry.needsSync);

      // Remove local entries that no longer exist on the remote (unless they need sync)
      byId.removeWhere((id, entry) =>
          !remoteIds.contains(id) && !entry.needsSync && !entry.isDeleted);

      _entries = byId.values.toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to pull remote routine templates: $e\n$stackTrace');
    }
  }
}
