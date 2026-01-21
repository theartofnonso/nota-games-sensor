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
  Future<void> loadTemplates({
    String? ownerIdOverride,
    String? clientIdOverride,
    bool requireOwnerAndClient = false,
  }) async {
    try {
      final authUserId = _client.auth.currentUser?.id;
      final ownerId = ownerIdOverride ?? authUserId;
      final clientId = clientIdOverride ?? authUserId;
      if (ownerId == null || clientId == null) {
        logger.w('No user logged in');
        return;
      }

      final query = _client.from('routine_templates').select();
      final response = requireOwnerAndClient
          ? await query
              .eq('owner', ownerId)
              .eq('clientId', clientId)
              .order('createdAt', ascending: true)
          : await query
              .or('owner.eq.$ownerId,clientId.eq.$clientId')
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
