import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isCoach = false;

  final logger = getLogger(className: 'NutritionLogController');

  late OfflineNutritionLogRepository _offlineRepository;
  late OfflineNutritionTemplateRepository _offlineTemplateRepository;
  late SupabaseNutritionLogRepository _remoteRepository;
  late SupabaseNutritionTemplateRepository _remoteTemplateRepository;

  String? _clientOverrideId;
  List<NutritionLogDto> _overrideLogs = const [];
  NutritionTemplateDto? _overrideTemplate;

  NutritionLogController({
    SupabaseNutritionLogRepository? repository,
    SupabaseNutritionTemplateRepository? templateRepository,
  }) {
    _remoteRepository = repository ?? SupabaseNutritionLogRepository();
    _remoteTemplateRepository =
        templateRepository ?? SupabaseNutritionTemplateRepository();
    _offlineRepository = OfflineNutritionLogRepository(
      remoteRepository: _remoteRepository,
    );
    _offlineTemplateRepository = OfflineNutritionTemplateRepository(
      remoteRepository: _remoteTemplateRepository,
    );
  }

  UnmodifiableListView<NutritionLogDto> get logs {
    if (_clientOverrideId != null) {
      return UnmodifiableListView(_overrideLogs);
    }
    if (_isCoach) {
      return UnmodifiableListView(const []);
    }
    return UnmodifiableListView(_offlineRepository.offlineLogs);
  }

  NutritionTemplateDto? get nutritionTemplate {
    if (_clientOverrideId != null) {
      return _overrideTemplate;
    }
    final templates = _isCoach
        ? const <NutritionTemplateDto>[]
        : _offlineTemplateRepository.offlineTemplates;
    if (templates.isEmpty) {
      return null;
    }
    return templates.first;
  }

  double get proteinTarget => nutritionTemplate?.protein ?? 0;
  double get carbsTarget => nutritionTemplate?.carbs ?? 0;
  double get fatsTarget => nutritionTemplate?.fats ?? 0;
  double get calorieTarget => nutritionTemplate?.calories ?? 0;
  String? get activeUserId =>
      _clientOverrideId ?? Supabase.instance.client.auth.currentUser?.id;
  bool get isClientMode => _clientOverrideId != null;
  bool get isCoach => _isCoach;

  void setCoachMode({required bool isCoach}) {
    if (_isCoach == isCoach) return;
    _isCoach = isCoach;
    if (_isCoach) {
      // ignore: discarded_futures
      _clearOfflineCaches();
    }
    notifyListeners();
  }

  Future<void> _clearOfflineCaches() async {
    await Future.wait([
      _offlineRepository.clearCache(),
      _offlineTemplateRepository.clearCache(),
    ]);
  }

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      if (_clientOverrideId != null) {
        await _loadRemoteForClient(_clientOverrideId!);
      } else if (_isCoach) {
        _overrideLogs = const [];
        _overrideTemplate = null;
      } else {
        await _offlineRepository.loadFromCache();
        await _offlineTemplateRepository.loadFromCache();
        await syncNutritionLogs();
      }
    } catch (e) {
      logger.e('Error initializing nutrition logs', error: e);
      errorMessage = 'Failed to load nutrition logs.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncNutritionLogs() async {
    if (_clientOverrideId != null || _isCoach) {
      return;
    }
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
      if (_clientOverrideId != null) {
        await _remoteRepository.upsertLog(log);
        await _loadRemoteForClient(_clientOverrideId!);
        notifyListeners();
        return;
      }
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
      if (_clientOverrideId != null) {
        await _remoteRepository.deleteLog(id);
        await _loadRemoteForClient(_clientOverrideId!);
        notifyListeners();
        return;
      }
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

  Future<void> loadClientData({required String clientId}) async {
    _clientOverrideId = clientId;
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

  Future<void> clearClientOverride() async {
    _clientOverrideId = null;
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
