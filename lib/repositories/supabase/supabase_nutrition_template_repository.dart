import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/nutrition/nutrition_template_dto.dart';

import '../../logger.dart';

class SupabaseNutritionTemplateRepository {
  final logger = getLogger(className: 'SupabaseNutritionTemplateRepository');
  final SupabaseClient _client = Supabase.instance.client;

  List<NutritionTemplateDto> _templates = [];

  UnmodifiableListView<NutritionTemplateDto> get templates =>
      UnmodifiableListView(_templates);

  Future<void> loadTemplates({String? userIdOverride}) async {
    try {
      final userId = userIdOverride ?? _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      final response = await _client
          .from('nutrition_templates')
          .select()
          .eq('client_id', userId)
          .order('updated_at', ascending: false);

      _templates = (response as List<dynamic>)
          .map((item) =>
              NutritionTemplateDto.fromJson(json: item as Map<String, dynamic>))
          .toList();

      logger.i('Loaded ${_templates.length} nutrition templates from Supabase');
    } catch (e) {
      logger.e('Error loading nutrition templates: $e');
      rethrow;
    }
  }
}
