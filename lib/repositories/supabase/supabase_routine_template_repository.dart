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

      final response = await _client
          .from('routine_templates')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: true);

      final rawItems = response as List<dynamic>;
      final parsed = <RoutineTemplateDto>[];
      int failed = 0;

      for (final item in rawItems) {
        try {
          final data = Map<String, dynamic>.from(item);
          parsed.add(RoutineTemplateDto.fromJson(json: data));
        } catch (e, stack) {
          failed += 1;
          logger.w(
              'Skipped invalid routine template payload. Error: $e\nPayload: $item\n$stack');
        }
      }

      _templates = parsed;

      logger.i(
          'Loaded ${_templates.length} templates from Supabase (skipped $failed invalid rows)');
    } catch (e) {
      logger.e('Error loading templates: $e');
      rethrow;
    }
  }
}
