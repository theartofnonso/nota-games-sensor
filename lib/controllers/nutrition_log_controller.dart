import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';
import 'package:trainware/dtos/nutrition/nutrition_template_dto.dart';

import '../logger.dart';
import '../app_flavor.dart';
import '../repositories/supabase/supabase_nutrition_log_repository.dart';
import '../utils/app_privileges.dart';
import '../repositories/supabase/supabase_nutrition_template_repository.dart';
import 'access_controller.dart';

class NutritionLogController extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';
  final logger = getLogger(className: 'NutritionLogController');

  late SupabaseNutritionLogRepository _remoteRepository;
  late SupabaseNutritionTemplateRepository _remoteTemplateRepository;

  List<NutritionLogDto> _overrideLogs = const [];
  NutritionTemplateDto? _overrideTemplate;
  final ClientOverrideController accessController;

  NutritionLogController({
    SupabaseNutritionLogRepository? repository,
    SupabaseNutritionTemplateRepository? templateRepository,
    required this.accessController,
  }) {
    _remoteRepository = repository ?? SupabaseNutritionLogRepository();
    _remoteTemplateRepository =
        templateRepository ?? SupabaseNutritionTemplateRepository();
  }

  UnmodifiableListView<NutritionLogDto> get logs {
    if (accessController.hasSelectedClient) {
      return UnmodifiableListView(_overrideLogs);
    }
    if (AppConfig.isCoach) {
      return UnmodifiableListView(const []);
    }
    return UnmodifiableListView(_remoteRepository.logs);
  }

  NutritionTemplateDto? get nutritionTemplate {
    if (accessController.hasSelectedClient) {
      return _overrideTemplate;
    }
    final templates = AppConfig.isCoach
        ? const <NutritionTemplateDto>[]
        : _remoteTemplateRepository.templates;
    if (templates.isEmpty) {
      return null;
    }
    return templates.first;
  }

  double get proteinTarget =>
      nutritionTemplate?.protein ?? NutritionTemplateDto.defaultProteinG;
  double get carbsTarget =>
      nutritionTemplate?.carbs ?? NutritionTemplateDto.defaultCarbsG;
  double get fatsTarget =>
      nutritionTemplate?.fats ?? NutritionTemplateDto.defaultFatsG;
  double get calorieTarget =>
      nutritionTemplate?.kcalDerivedFromMacros ??
      NutritionTemplateDto.defaultKcalFromMacros;
  String? get activeUserId =>
      accessController.selectedClientId ??
      Supabase.instance.client.auth.currentUser?.id;
  bool get isCoach => AppConfig.isCoach;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      if (accessController.hasSelectedClient &&
          accessController.selectedClientId != null) {
        await _loadRemoteForClient(accessController.selectedClientId!);
      } else if (AppConfig.isCoach) {
        _overrideLogs = const [];
        _overrideTemplate = null;
      } else {
        await _remoteRepository.loadLogs();
        await _remoteTemplateRepository.loadTemplates();
      }
    } catch (e) {
      logger.e('Error initializing nutrition logs', error: e);
      errorMessage = 'Failed to load nutrition logs.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLog({required NutritionLogDto log}) async {
    try {
      if (accessController.hasSelectedClient) {
        await _remoteRepository.upsertLog(log);
        await _loadRemoteForClient(accessController.selectedClientId!);
        notifyListeners();
        return;
      }
      await _remoteRepository.upsertLog(log);
      await _remoteRepository.loadLogs();
      notifyListeners();
    } catch (e) {
      logger.e('Error saving nutrition log', error: e);
      errorMessage = 'Failed to save nutrition log.';
      notifyListeners();
    }
  }

  Future<void> removeLog({required String id}) async {
    try {
      if (accessController.hasSelectedClient) {
        await _remoteRepository.deleteLog(id);
        await _loadRemoteForClient(accessController.selectedClientId!);
        notifyListeners();
        return;
      }
      await _remoteRepository.deleteLog(id);
      await _remoteRepository.loadLogs();
      notifyListeners();
    } catch (e) {
      logger.e('Error removing nutrition log', error: e);
      errorMessage = 'Failed to delete nutrition log.';
      notifyListeners();
    }
  }

  Future<void> upsertTemplate({required NutritionTemplateDto template}) async {
    try {
      final clientId = accessController.selectedClientId ??
          (AppPrivileges.isSelfCoaching ? template.clientId : null);
      if (clientId == null || clientId.isEmpty) {
        errorMessage = 'Client context is required to save nutrition template.';
        notifyListeners();
        return;
      }
      await _remoteTemplateRepository.upsertTemplate(template: template);
      if (accessController.hasSelectedClient) {
        await _loadRemoteForClient(clientId);
      } else {
        await _remoteTemplateRepository.loadTemplates(userIdOverride: clientId);
        await _remoteRepository.loadLogs(userIdOverride: clientId);
      }
      notifyListeners();
    } catch (e) {
      logger.e('Error saving nutrition template', error: e);
      errorMessage = 'Failed to save nutrition template.';
      notifyListeners();
    }
  }

  Future<void> loadClientData({required String clientId}) async {
    accessController.setSelectedClient(clientId: clientId);
    isLoading = true;
    notifyListeners();
    try {
      await _loadRemoteForClient(clientId);
    } catch (e) {
      logger.e('Error loading client nutrition data', error: e);
      errorMessage = 'Failed to load client nutrition data.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSelectedClient() async {
    accessController.clearSelectedClient();
    _overrideLogs = const [];
    _overrideTemplate = null;
    await initialize();
  }

  Future<void> _loadRemoteForClient(String clientId) async {
    await _remoteRepository.loadLogs(userIdOverride: clientId);
    _overrideLogs = _remoteRepository.logs.toList();
    await _remoteTemplateRepository.loadTemplates(userIdOverride: clientId);
    _overrideTemplate = _remoteTemplateRepository.templates.isNotEmpty
        ? _remoteTemplateRepository.templates.first
        : null;
  }
}
