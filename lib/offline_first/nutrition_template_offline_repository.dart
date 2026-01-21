import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/nutrition/nutrition_template_dto.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_nutrition_template_repository.dart';
import 'nutrition_template_local_entry.dart';
import 'nutrition_template_local_store.dart';

class OfflineNutritionTemplateRepository {
  OfflineNutritionTemplateRepository({
    NutritionTemplateLocalStore? localStore,
    SupabaseNutritionTemplateRepository? remoteRepository,
    SupabaseClient? client,
  })  : _localStore = localStore ?? NutritionTemplateLocalStore(),
        _remoteRepository =
            remoteRepository ?? SupabaseNutritionTemplateRepository(),
        _client = client ?? Supabase.instance.client;

  final NutritionTemplateLocalStore _localStore;
  final SupabaseNutritionTemplateRepository _remoteRepository;
  final SupabaseClient _client;
  final _logger = getLogger(className: 'OfflineNutritionTemplateRepository');

  List<NutritionTemplateLocalEntry> _entries = const [];

  List<NutritionTemplateDto> get offlineTemplates =>
      _entries.where((e) => !e.isDeleted).map((e) => e.template).toList();

  Future<void> loadFromCache() async {
    _entries = await _localStore.loadAll();
  }

  Future<void> clearCache() async {
    _entries = const [];
    await _localStore.deleteAll();
  }

  Future<void> syncNow() async {
    _logger.i('Starting nutrition template sync');

    _entries = await _localStore.loadAll();
    await _pullRemoteChanges();
    await _localStore.saveAll(_entries);
  }

  Future<void> _pullRemoteChanges() async {
    try {
      await _remoteRepository.loadTemplates();
      final remoteTemplates = _remoteRepository.templates;

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.w('Skipping nutrition template pull: no authenticated user');
        return;
      }

      final rawRows = await _client
          .from('nutrition_templates')
          .select('id, updated_at')
          .eq('client_id', userId);

      final updatedAtById = <String, DateTime>{};
      for (final row in rawRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final updatedAtStr = map['updated_at'] as String;
        updatedAtById[id] = DateTime.parse(updatedAtStr);
      }

      final byId = {for (final e in _entries) e.template.id: e};
      final remoteIds = <String>{};

      for (final remote in remoteTemplates) {
        remoteIds.add(remote.id);
        final remoteUpdatedAt =
            updatedAtById[remote.id] ?? DateTime.now().toUtc();
        final local = byId[remote.id];

        if (local == null) {
          byId[remote.id] = NutritionTemplateLocalEntry(
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

      byId.removeWhere((_, entry) => entry.isDeleted && !entry.needsSync);
      byId.removeWhere((id, entry) =>
          !remoteIds.contains(id) && !entry.needsSync && !entry.isDeleted);

      _entries = byId.values.toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to pull remote nutrition templates: $e\n$stackTrace');
    }
  }
}
