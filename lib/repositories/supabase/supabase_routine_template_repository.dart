import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dtos/appsync/routine_template_dto.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseRoutineTemplateRepository {
  final logger = getLogger(className: "SupabaseRoutineTemplateRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineTemplateDto> _templates = [];

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(_templates);

  Future<void> loadTemplates() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in, cannot load templates');
        return;
      }

      final response = await _client
          .from('routine_templates')
          .select()
          .eq('owner', userId)
          .order('created_at', ascending: false);

      _templates = (response as List<dynamic>)
          .map((item) => _convertMapToRoutineTemplateDto(item))
          .toList();

      logger.i('Loaded ${_templates.length} routine templates');
    } catch (e) {
      logger.e('Error loading routine templates: $e');
      rethrow;
    }
  }

  Future<RoutineTemplateDto> saveTemplate(
      {required RoutineTemplateDto templateDto}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toUtc();

      final insertData = {
        'owner': userId,
        'data': jsonEncode(templateDto.toJson()),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Only include id if it's not empty (let Supabase auto-generate otherwise)
      if (templateDto.id.isNotEmpty) {
        insertData['id'] = templateDto.id;
      }

      final response = await _client
          .from('routine_templates')
          .insert(insertData)
          .select()
          .single();

      final generatedId = response['id'] as String;

      Posthog().capture(
        eventName: PostHogAnalyticsEvent.createRoutineTemplate.displayName,
        properties: Map<String, Object>.from(templateDto.toJson()),
      );

      logger.i('Saved template: ${templateDto.name}');

      final updatedWithId = templateDto.copyWith(id: generatedId);
      return updatedWithId;
    } catch (e) {
      logger.e('Error saving template: $e');
      rethrow;
    }
  }

  Future<void> updateTemplate({required RoutineTemplateDto template}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toUtc();

      await _client
          .from('routine_templates')
          .update({
            'data': jsonEncode(template.toJson()),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', template.id)
          .eq('owner', userId);

      logger.i('Updated template: ${template.name}');
    } catch (e) {
      logger.e('Error updating template: $e');
      rethrow;
    }
  }

  Future<void> removeTemplate({required RoutineTemplateDto template}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('routine_templates')
          .delete()
          .eq('id', template.id)
          .eq('owner', userId);

      logger.i('Removed template: ${template.name}');
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
    final dataJson = jsonDecode(item['data'] as String) as Map<String, dynamic>;

    // Add metadata from Supabase
    dataJson['id'] = item['id'];
    dataJson['owner'] = item['owner'];
    dataJson['createdAt'] = item['created_at'];
    dataJson['updatedAt'] = item['updated_at'];

    return RoutineTemplateDto.fromJson(json: dataJson);
  }
}
