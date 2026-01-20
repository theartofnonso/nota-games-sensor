import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';
import 'package:trainware/dtos/nutrition/nutrition_template_dto.dart';
import 'package:trainware/offline_first/nutrition_log_offline_repository.dart';
import 'package:trainware/offline_first/nutrition_template_offline_repository.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_nutrition_log_repository.dart';
import '../repositories/supabase/supabase_nutrition_template_repository.dart';

class NutritionLogController extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';

  final logger = getLogger(className: 'NutritionLogController');

  late OfflineNutritionLogRepository _offlineRepository;
  late OfflineNutritionTemplateRepository _offlineTemplateRepository;

  NutritionLogController({
    SupabaseNutritionLogRepository? repository,
    SupabaseNutritionTemplateRepository? templateRepository,
  }) {
    _offlineRepository = OfflineNutritionLogRepository(
      remoteRepository: repository ?? SupabaseNutritionLogRepository(),
    );
    _offlineTemplateRepository = OfflineNutritionTemplateRepository(
      remoteRepository:
          templateRepository ?? SupabaseNutritionTemplateRepository(),
    );
  }

  UnmodifiableListView<NutritionLogDto> get logs =>
      UnmodifiableListView(_offlineRepository.offlineLogs);

  NutritionTemplateDto? get nutritionTemplate {
    final templates = _offlineTemplateRepository.offlineTemplates;
    if (templates.isEmpty) {
      return null;
    }
    return templates.first;
  }

  double get proteinTarget => nutritionTemplate?.protein ?? 0;
  double get carbsTarget => nutritionTemplate?.carbs ?? 0;
  double get fatsTarget => nutritionTemplate?.fats ?? 0;
  double get calorieTarget => nutritionTemplate?.calories ?? 0;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      await _offlineRepository.loadFromCache();
      await _offlineTemplateRepository.loadFromCache();
      await syncNutritionLogs();
    } catch (e) {
      logger.e('Error initializing nutrition logs', error: e);
      errorMessage = 'Failed to load nutrition logs.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncNutritionLogs() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.last == ConnectivityResult.none) {
      logger.w('Nutrition sync skipped: offline/no connectivity');
      return;
    }

    await Future.wait([
      _offlineRepository.syncNow(),
      _offlineTemplateRepository.syncNow(),
    ]);
    notifyListeners();
  }

  Future<void> addLog({required NutritionLogDto log}) async {
    try {
      await _offlineRepository.upsertLocal(log);
      notifyListeners();
      // ignore: discarded_futures
      syncNutritionLogs();
    } catch (e) {
      logger.e('Error saving nutrition log', error: e);
      errorMessage = 'Failed to save nutrition log.';
      notifyListeners();
    }
  }

  Future<void> removeLog({required String id}) async {
    try {
      await _offlineRepository.deleteLocal(id);
      notifyListeners();
      // ignore: discarded_futures
      syncNutritionLogs();
    } catch (e) {
      logger.e('Error removing nutrition log', error: e);
      errorMessage = 'Failed to delete nutrition log.';
      notifyListeners();
    }
  }
}
