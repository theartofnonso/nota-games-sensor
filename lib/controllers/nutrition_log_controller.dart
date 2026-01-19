import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';
import 'package:trainware/offline_first/nutrition_log_offline_repository.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_nutrition_log_repository.dart';

class NutritionLogController extends ChangeNotifier {
  static const double defaultProteinTarget = 0;
  static const double defaultCarbsTarget = 0;
  static const double defaultFatsTarget = 0;
  static const double defaultCalorieTarget = 2060;

  bool isLoading = false;
  String errorMessage = '';

  final logger = getLogger(className: 'NutritionLogController');

  late OfflineNutritionLogRepository _offlineRepository;

  NutritionLogController({
    SupabaseNutritionLogRepository? repository,
  }) {
    _offlineRepository = OfflineNutritionLogRepository(
      remoteRepository: repository ?? SupabaseNutritionLogRepository(),
    );
  }

  UnmodifiableListView<NutritionLogDto> get logs =>
      UnmodifiableListView(_offlineRepository.offlineLogs);

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      await _offlineRepository.loadFromCache();
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

    await _offlineRepository.syncNow();
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
