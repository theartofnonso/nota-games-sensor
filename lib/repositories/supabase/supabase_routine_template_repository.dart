import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:isar/isar.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/models/local/local_routine_template.dart';
import 'package:tracker_app/services/sync_service.dart';
import 'package:uuid/uuid.dart';

import '../../dtos/appsync/routine_template_dto.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseRoutineTemplateRepository {
  final logger = getLogger(className: "SupabaseRoutineTemplateRepository");
  final SupabaseClient _client = Supabase.instance.client;
  final Isar isar;
  final SyncService syncService;

  List<RoutineTemplateDto> _templates = [];

  SupabaseRoutineTemplateRepository({
    required this.isar,
    required this.syncService,
  });

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(_templates);

  /// Load templates - OFFLINE FIRST
  Future<void> loadTemplates() async {
    try {
      await _loadFromLocal();
      _syncFromSupabase();
    } catch (e) {
      logger.e('Error loading routine templates: $e');
      rethrow;
    }
  }

  Future<void> _loadFromLocal() async {
    final localTemplates = await isar.localRoutineTemplates.where().findAll();

    _templates = localTemplates.map((local) {
      return RoutineTemplateDto.fromJson(json: jsonDecode(local.jsonData));
    }).toList();

    logger.i('Loaded ${_templates.length} templates from local storage');
  }

  Future<void> _syncFromSupabase() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in, skipping Supabase sync');
        return;
      }

      if (!await syncService.hasInternet()) {
        logger.d('No internet, skipping Supabase sync');
        return;
      }

      final response = await _client
          .from('routine_templates')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: false);

      final supabaseTemplates = (response as List<dynamic>)
          .map((item) => _convertMapToRoutineTemplateDto(item))
          .toList();

      await _mergeWithLocal(supabaseTemplates);

      // Reload in-memory list after sync
      await _loadFromLocal();

      logger.i('Synced ${supabaseTemplates.length} templates from Supabase');
    } catch (e) {
      logger.e('Error syncing from Supabase: $e');
    }
  }

  Future<void> _mergeWithLocal(
      List<RoutineTemplateDto> supabaseTemplates) async {
    await isar.writeTxn(() async {
      for (final template in supabaseTemplates) {
        final existing = await isar.localRoutineTemplates
            .filter()
            .templateIdEqualTo(template.id)
            .findFirst();

        if (existing == null) {
          // New item - create it
          final local = LocalRoutineTemplate()
            ..templateId = template.id
            ..jsonData = jsonEncode(template.toJson())
            ..name = template.name
            ..planId = template.planId
            ..lastModifiedLocal = DateTime.now()
            ..needsSync = false
            ..createdAt = DateTime.now();

          await isar.localRoutineTemplates.put(local);
        } else if (!existing.needsSync) {
          // Existing item with no local changes - update from Supabase
          existing
            ..jsonData = jsonEncode(template.toJson())
            ..name = template.name
            ..planId = template.planId
            ..lastModifiedLocal = DateTime.now()
            ..needsSync = false;

          await isar.localRoutineTemplates.put(existing);
        }
        // If existing.needsSync = true, keep local version (will sync later)
      }
    });

    await _loadFromLocal();
  }

  /// Save template - OFFLINE FIRST
  Future<RoutineTemplateDto> saveTemplate(
      {required RoutineTemplateDto templateDto}) async {
    try {
      final id = templateDto.id.isEmpty ? const Uuid().v4() : templateDto.id;
      final templateWithId = templateDto.copyWith(id: id);

      final local = LocalRoutineTemplate()
        ..templateId = id
        ..jsonData = jsonEncode(templateWithId.toJson())
        ..name = templateWithId.name
        ..planId = templateWithId.planId
        ..lastModifiedLocal = DateTime.now()
        ..needsSync = true
        ..createdAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.localRoutineTemplates.put(local);
      });

      _templates.add(templateWithId);

      await syncService.queueSync(
        entityType: 'template',
        entityId: id,
        operation: 'create',
        jsonData: jsonEncode(templateWithId.toJson()),
      );

      Posthog().capture(
        eventName: PostHogAnalyticsEvent.createRoutineTemplate.displayName,
        properties: Map<String, Object>.from(templateWithId.toJson()),
      );

      logger.i('Saved template locally: ${templateWithId.name}');
      return templateWithId;
    } catch (e) {
      logger.e('Error saving template: $e');
      rethrow;
    }
  }

  /// Update template - OFFLINE FIRST
  Future<void> updateTemplate({required RoutineTemplateDto template}) async {
    try {
      final local = await isar.localRoutineTemplates
          .filter()
          .templateIdEqualTo(template.id)
          .findFirst();

      if (local != null) {
        local
          ..jsonData = jsonEncode(template.toJson())
          ..name = template.name
          ..planId = template.planId
          ..lastModifiedLocal = DateTime.now()
          ..needsSync = true;

        await isar.writeTxn(() async {
          await isar.localRoutineTemplates.put(local);
        });
      }

      final index = _templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        _templates[index] = template;
      }

      await syncService.queueSync(
        entityType: 'template',
        entityId: template.id,
        operation: 'update',
        jsonData: jsonEncode(template.toJson()),
      );

      logger.i('Updated template locally: ${template.name}');
    } catch (e) {
      logger.e('Error updating template: $e');
      rethrow;
    }
  }

  /// Remove template - OFFLINE FIRST
  Future<void> removeTemplate({required RoutineTemplateDto template}) async {
    try {
      final local = await isar.localRoutineTemplates
          .filter()
          .templateIdEqualTo(template.id)
          .findFirst();

      if (local != null) {
        await isar.writeTxn(() async {
          await isar.localRoutineTemplates.delete(local.id);
        });
      }

      _templates.removeWhere((t) => t.id == template.id);

      await syncService.queueSync(
        entityType: 'template',
        entityId: template.id,
        operation: 'delete',
        jsonData: jsonEncode(template.toJson()),
      );

      logger.i('Removed template locally: ${template.name}');
    } catch (e) {
      logger.e('Error removing template: $e');
      rethrow;
    }
  }

  /// Helper methods

  RoutineTemplateDto? templateWhere({required String id}) {
    return _templates.firstWhereOrNull((dto) => dto.id == id);
  }

  RoutineTemplateDto? templateWherePlanId({required String id}) {
    return _templates.firstWhereOrNull((dto) => dto.planId == id);
  }

  void clear() {
    _templates.clear();
  }

  /// Helper method to convert Supabase map to RoutineTemplateDto
  RoutineTemplateDto _convertMapToRoutineTemplateDto(
      Map<String, dynamic> item) {
    return RoutineTemplateDto.fromJson(json: Map<String, dynamic>.from(item));
  }
}
