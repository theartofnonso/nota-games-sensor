import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_template_dto.dart';

import '../../logger.dart';

class SupabaseRoutineTemplateRepository {
  final logger = getLogger(className: "SupabaseRoutineTemplateRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineTemplateDto> _templates = [];

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(_templates);

  /// Load templates from Supabase (read-only; writes go through offline layer).
  Future<void> loadTemplates() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      // Load templates where user is owner OR where user is the client (system-created templates)
      // This query matches the RLS policy: auth.uid() = owner OR auth.uid() = "clientId"
      // RLS will also enforce this, but the explicit filter makes intent clear and may improve performance
      final response = await _client
          .from('routine_templates')
          .select()
          .or('owner.eq.$userId,clientId.eq.$userId')
          .order('createdAt', ascending: true);

      final rawItems = response as List;
      _templates = rawItems
          .map((item) => RoutineTemplateDto.fromJson(
              json: Map<String, dynamic>.from(item)))
          .toList();

      logger.i('Loaded ${_templates.length} templates from Supabase');
    } catch (e) {
      logger.e('Error loading templates: $e');
      rethrow;
    }
  }
}
