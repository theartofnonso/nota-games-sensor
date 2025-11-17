import 'dart:async';

import 'package:collection/collection.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/dtos/appsync/routine_template_dto.dart';
import 'package:uuid/uuid.dart';

import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseRoutineTemplateRepository {
  final logger = getLogger(className: "SupabaseRoutineTemplateRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineTemplateDto> _templates = [];

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(_templates);

  /// Load templates from Supabase
  Future<void> loadTemplates() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      final response = await _client
          .from('routine_templates')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: true);

      _templates = (response as List<dynamic>).map((item) {
        final data = Map<String, dynamic>.from(item);
        return RoutineTemplateDto.fromJson(json: data);
      }).toList();

      logger.i('Loaded ${_templates.length} templates from Supabase');
    } catch (e) {
      logger.e('Error loading templates: $e');
      rethrow;
    }
  }

  /// Save a new template
  Future<RoutineTemplateDto> saveTemplate(RoutineTemplateDto template) async {
    try {
      // Generate ID if empty
      final id = template.id.isEmpty ? const Uuid().v4() : template.id;
      final templateWithId = template.copyWith(id: id);

      // Insert into Supabase
      await _client.from('routine_templates').insert(templateWithId.toJson());

      // Add to in-memory list
      _templates.add(templateWithId);

      logger.i('Saved template: ${templateWithId.id}');

      // Analytics
      await Posthog().capture(
        eventName: PostHogAnalyticsEvent.createRoutineTemplate.displayName,
      );

      return templateWithId;
    } catch (e) {
      logger.e('Error saving template: $e');
      rethrow;
    }
  }

  /// Update an existing template
  Future<void> updateTemplate(RoutineTemplateDto template) async {
    try {
      // Update in Supabase
      await _client
          .from('routine_templates')
          .update(template.toJson())
          .eq('id', template.id);

      // Update in-memory list
      _templates = _templates
          .map((item) => item.id == template.id ? template : item)
          .toList();

      logger.i('Updated template: ${template.id}');
    } catch (e) {
      logger.e('Error updating template: $e');
      rethrow;
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(RoutineTemplateDto template) async {
    try {
      // Delete from Supabase
      await _client.from('routine_templates').delete().eq('id', template.id);

      // Remove from in-memory list
      _templates.removeWhere((item) => item.id == template.id);

      logger.i('Deleted template: ${template.id}');
    } catch (e) {
      logger.e('Error deleting template: $e');
      rethrow;
    }
  }

  /// Helper: Find template by ID
  RoutineTemplateDto? whereTemplateById(String id) {
    return _templates.firstWhereOrNull((template) => template.id == id);
  }

  /// Helper: Find templates by plan ID
  List<RoutineTemplateDto> whereTemplatesByPlanId(String planId) {
    return _templates.where((template) => template.planId == planId).toList();
  }
}
