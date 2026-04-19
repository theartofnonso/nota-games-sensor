import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/repositories/supabase/supabase_routine_log_repository.dart';
import 'package:uuid/uuid.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../enums/exercise_type_enums.dart';
import '../logger.dart';
import '../repositories/supabase/supabase_routine_plan_repository.dart';
import '../repositories/supabase/supabase_routine_template_repository.dart';
import '../utils/app_privileges.dart';
import '../utils/notifications_utils.dart';
import '../utils/routine_session_template_utils.dart';
import '../utils/routine_utils.dart';
import 'access_controller.dart';
import '../app_flavor.dart';
import '../services/coach_instruction_video_service.dart';
import '../services/fcm_push_service.dart';

class SupabaseExerciseAndRoutineController extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';
  final logger = getLogger(className: "SupabaseExerciseAndRoutineController");

  /// Clears [errorMessage] after it has been shown in the UI. Without this,
  /// screens that surface errors from [build] via [addPostFrameCallback] would
  /// open the same bottom sheet again on every rebuild (e.g. returning from a
  /// nested route) while the message stays non-empty.
  void clearErrorMessageAfterDisplay() {
    if (errorMessage.isEmpty) return;
    errorMessage = '';
    notifyListeners();
  }

  late SupabaseRoutineTemplateRepository _templateRepository;
  late SupabaseRoutinePlanRepository _planRepository;
  late SupabaseRoutineLogRepository _logRepository;
  List<ExerciseDto> _exercises = const [];
  List<RoutineTemplateDto> _overrideTemplates = const [];
  List<RoutinePlanDto> _overridePlans = const [];
  List<RoutineLogDto> _overrideLogs = const [];
  final ClientOverrideController accessController;

  SupabaseExerciseAndRoutineController({
    required SupabaseRoutineTemplateRepository templateRepository,
    required SupabaseRoutinePlanRepository planRepository,
    required SupabaseRoutineLogRepository logRepository,
    required this.accessController,
  }) {
    _templateRepository = templateRepository;
    _planRepository = planRepository;
    _logRepository = logRepository;
  }

  UnmodifiableListView<ExerciseDto> get exercises =>
      UnmodifiableListView(_exercises);

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(
        accessController.hasSelectedClient
            ? _overrideTemplates
            : (AppConfig.isCoach
                ? const []
                : _templateRepository.templates),
      );

  UnmodifiableListView<RoutinePlanDto> get plans => UnmodifiableListView(
        accessController.hasSelectedClient
            ? _overridePlans
            : (AppConfig.isCoach
                ? const []
                : _planRepository.plans),
      );

  UnmodifiableListView<RoutineLogDto> get logs => UnmodifiableListView(
        accessController.hasSelectedClient
            ? _overrideLogs
            : (AppConfig.isCoach
                ? const []
                : _logRepository.logs),
      );

  /// Direct view of logs loaded from Supabase (used internally by the
  /// offline sync engine and for debugging; prefer [logs] in the UI).
  UnmodifiableListView<RoutineLogDto> get remoteLogs => _logRepository.logs;
  bool get isCoach => AppConfig.isCoach;
  String? get activeUserId =>
      accessController.selectedClientId ??
      Supabase.instance.client.auth.currentUser?.id;

  UnmodifiableMapView<String, List<ExerciseLogDto>>
      get exerciseLogsByExerciseId =>
          UnmodifiableMapView(groupExerciseLogsByExerciseId(routineLogs: logs));

  /// Exercises that appear in logs, ordered by most recent use (newest first).
  /// Used by the exercise library to show a "From your logs" section.
  List<ExerciseDto> get exercisesFromLogsOrderedByRecency {
    final byId = <String, ({ExerciseDto exercise, DateTime lastUsed})>{};
    for (final log in logs) {
      for (final exLog in log.exerciseLogs) {
        final ex = exLog.exercise;
        final existing = byId[ex.id];
        if (existing == null || log.startTime.isAfter(existing.lastUsed)) {
          byId[ex.id] = (exercise: ex, lastUsed: log.startTime);
        }
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return list.map((e) => e.exercise).toList();
  }

  bool _blockIfClientMode() {
    if (!accessController.hasSelectedClient) {
      return false;
    }
    errorMessage = "Client mode is read-only.";
    notifyListeners();
    return true;
  }

  /// Initialization
  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      await loadUserData();
    } catch (e) {
      logger.e("Error initializing controller", error: e);
      errorMessage = "Failed to initialize. Please restart the app.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserData() async {
    try {
      await loadExerciseCatalog();
      if (accessController.hasSelectedClient &&
          accessController.selectedClientId != null) {
        await _loadRemoteForClient(accessController.selectedClientId!);
        notifyListeners();
        return;
      }
      if (AppConfig.isCoach) {
        _overrideTemplates = const [];
        _overridePlans = const [];
        _overrideLogs = const [];
        notifyListeners();
        return;
      }
      await _templateRepository.loadTemplates();
      await _planRepository.loadPlans();
      await _logRepository.loadLogs();

      // Schedule training + nutrition nudges from historic log data (client only)
      if (logs.isNotEmpty) {
        await schedulePreferredTrainingReminders(logs: logs);
        await scheduleTrainingNutritionNudges(logs: logs);
      } else {
        await cancelTrainingNutritionNudges();
      }

      notifyListeners();
    } catch (e) {
      logger.e("Error loading user data", error: e);
      rethrow;
    }
  }

  /// Loads the canonical exercise catalog from Supabase `exercises`.
  /// This is the source used by the exercise library and relational reads.
  Future<void> loadExerciseCatalog({bool force = false}) async {
    if (!force && _exercises.isNotEmpty) return;
    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select('id,name,type')
          .order('name', ascending: true);
      final rows = response as List<dynamic>;
      final loaded = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((json) {
            final parsedType = ExerciseType.fromString(
              json['type'] as String? ?? 'NO',
            );
            return ExerciseDto(
              id: json['id'] as String? ?? '',
              name: json['name'] as String? ?? '',
              type: parsedType,
              notes: '',
              isSystem: true,
            );
          })
          .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
          .toList();
      _exercises = loaded;
    } catch (e) {
      logger.w('Failed to load exercise catalog from Supabase: $e');
    }
  }

  /// Plans

  Future<RoutinePlanDto?> savePlan({required RoutinePlanDto planDto}) async {
    if (accessController.hasSelectedClient) {
      isLoading = true;
      RoutinePlanDto? result;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return null;
        }
        final id = planDto.id.isEmpty ? const Uuid().v4() : planDto.id;
        final planWithId = planDto.copyWith(
          id: id,
          clientId: accessController.selectedClientId,
        );
        final json = planWithId.toJson();
        json['owner'] = userId;
        await Supabase.instance.client.from('routine_plans').upsert(json);
        await _loadRemoteForClient(accessController.selectedClientId!);
        result = planWithId;
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error saving client plan", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return result;
    }
    isLoading = true;
    RoutinePlanDto? result;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        errorMessage = "Please sign in to continue.";
        notifyListeners();
        return null;
      }
      final id = planDto.id.isEmpty ? const Uuid().v4() : planDto.id;
      final planWithId = planDto.copyWith(id: id);
      final json = planWithId.toJson();
      json['owner'] = userId;
      await Supabase.instance.client.from('routine_plans').upsert(json);
      await _planRepository.loadPlans();
      result = planWithId;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return result;
  }

  Future<void> updatePlan({required RoutinePlanDto plan}) async {
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode &&
        !AppPrivileges.isProWithCoach &&
        plan.isSystemPlan) {
      errorMessage = "System plans cannot be edited.";
      logger.w("Attempted to update system plan: ${plan.id}");
      notifyListeners();
      return;
    }
    if (isClientMode) {
      isLoading = true;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return;
        }
        final updatedPlan =
            plan.copyWith(clientId: accessController.selectedClientId);
        final json = updatedPlan.toJson();
        json['owner'] = userId;
        await Supabase.instance.client.from('routine_plans').upsert(json);
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error updating client plan", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

    isLoading = true;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        errorMessage = "Please sign in to continue.";
        notifyListeners();
        return;
      }
      final json = plan.toJson();
      json['owner'] = userId;
      await Supabase.instance.client.from('routine_plans').upsert(json);
      await _planRepository.loadPlans();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> deletePlan({required RoutinePlanDto plan}) async {
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode &&
        !AppPrivileges.isProWithCoach && plan.isSystemPlan) {
      errorMessage = "System plans cannot be deleted.";
      logger.w("Attempted to delete system plan: ${plan.id}");
      notifyListeners();
      return;
    }

    if (isClientMode) {
      isLoading = true;
      try {
        await Supabase.instance.client
            .from('routine_plans')
            .delete()
            .eq('id', plan.id);
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error deleting client plan", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

    isLoading = true;
    try {
      await Supabase.instance.client
          .from('routine_plans')
          .delete()
          .eq('id', plan.id);
      await _planRepository.loadPlans();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error deleting plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Templates

  Future<RoutineTemplateDto?> saveTemplate({
    required RoutineTemplateDto templateDto,
  }) async {
    if (accessController.hasSelectedClient) {
      isLoading = true;
      RoutineTemplateDto? result;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return null;
        }
        final id = templateDto.id.isEmpty ? const Uuid().v4() : templateDto.id;
        var planOrder = templateDto.planOrderIndex;
        if (templateDto.id.isEmpty && planOrder == null) {
          final samePlan = _templatesForPlanOrderIndexing()
              .where((t) => t.planId == templateDto.planId);
          final ints =
              samePlan.map((t) => t.planOrderIndex).whereType<int>().toList();
          final maxIdx =
              ints.isEmpty ? -1 : ints.reduce((a, b) => a > b ? a : b);
          planOrder = maxIdx + 1;
        }
        final templateWithId = templateDto.copyWith(
          id: id,
          clientId: accessController.selectedClientId,
          planOrderIndex: planOrder,
        );
        await _templateRepository.upsertTemplate(
          template: templateWithId,
          ownerId: userId,
        );
        await _loadRemoteForClient(accessController.selectedClientId!);
        result = templateWithId;
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error saving client template", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return result;
    }
    // Check if template belongs to a system plan (coach-led clients can add)
    final plan = planWhere(id: templateDto.planId);
    if (!AppPrivileges.isProWithCoach && (plan?.isSystemPlan ?? false)) {
      errorMessage = "Cannot add workouts to system plans.";
      logger.w(
          "Attempted to save template to system plan: ${templateDto.planId}");
      notifyListeners();
      return null;
    }

    isLoading = true;
    RoutineTemplateDto? result;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        errorMessage = "Please sign in to continue.";
        notifyListeners();
        return null;
      }
      final id = templateDto.id.isEmpty ? const Uuid().v4() : templateDto.id;
      var planOrder = templateDto.planOrderIndex;
      if (templateDto.id.isEmpty && planOrder == null) {
        final samePlan = _templatesForPlanOrderIndexing()
            .where((t) => t.planId == templateDto.planId);
        final ints =
            samePlan.map((t) => t.planOrderIndex).whereType<int>().toList();
        final maxIdx =
            ints.isEmpty ? -1 : ints.reduce((a, b) => a > b ? a : b);
        planOrder = maxIdx + 1;
      }
      final templateWithId =
          templateDto.copyWith(id: id, planOrderIndex: planOrder);
      await _templateRepository.upsertTemplate(
        template: templateWithId,
        ownerId: userId,
      );
      await _templateRepository.loadTemplates();
      result = templateWithId;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return result;
  }

  Future<void> updateTemplate({
    required RoutineTemplateDto template,
  }) async {
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode &&
        !AppPrivileges.isProWithCoach) {
      final plan = planWhere(id: template.planId);
      if (plan?.isSystemPlan ?? false) {
        errorMessage = "Templates from system plans cannot be edited.";
        logger
            .w("Attempted to update template from system plan: ${template.id}");
        notifyListeners();
        return;
      }
    }

    if (isClientMode) {
      isLoading = true;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return;
        }
        final updatedTemplate =
            template.copyWith(clientId: accessController.selectedClientId);
        await _templateRepository.upsertTemplate(
          template: updatedTemplate,
          ownerId: userId,
        );
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error updating client template", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      errorMessage = "Please sign in to continue.";
      notifyListeners();
      return;
    }
    if (AppPrivileges.isProWithCoach && !template.isOwnedBy(userId)) {
      errorMessage = "You cannot edit workouts assigned by your coach.";
      notifyListeners();
      return;
    }

    isLoading = true;
    try {
      await _templateRepository.upsertTemplate(
        template: template,
        ownerId: userId,
      );
      await _templateRepository.loadTemplates();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> deleteTemplate({
    required RoutineTemplateDto template,
  }) async {
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode &&
        !AppPrivileges.isProWithCoach) {
      final plan = planWhere(id: template.planId);
      if (plan?.isSystemPlan ?? false) {
        errorMessage = "Templates from system plans cannot be deleted.";
        logger
            .w("Attempted to delete template from system plan: ${template.id}");
        notifyListeners();
        return;
      }
    }

    if (!isClientMode) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null &&
          AppPrivileges.isProWithCoach &&
          !template.isOwnedBy(userId)) {
        errorMessage =
            "You cannot delete workouts assigned by your coach.";
        notifyListeners();
        return;
      }
    }

    if (isClientMode) {
      isLoading = true;
      try {
        await Supabase.instance.client
            .from('routine_templates')
            .delete()
            .eq('id', template.id);
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error deleting client template", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

    isLoading = true;
    try {
      await Supabase.instance.client
          .from('routine_templates')
          .delete()
          .eq('id', template.id);
      await _templateRepository.loadTemplates();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error deleting template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Logs

  /// Save a routine log to Supabase. For clients, clears SharedPrefs draft
  /// only after successful save (caller must call exerciseLogController.onClear).
  Future<RoutineLogDto?> saveLog({required RoutineLogDto logDto}) async {
    if (_blockIfClientMode()) return null;
    if (!hasValidWorkoutSessionTemplateId(logDto.templateId)) {
      errorMessage =
          'This workout must be started from a plan. Go back and open a workout template.';
      notifyListeners();
      return null;
    }
    isLoading = true;
    try {
      final id = logDto.id.isEmpty ? const Uuid().v4() : logDto.id;

      final logWithId = logDto.copyWith(id: id);
      final updatedLog = logWithId.copyWith(
        exerciseLogs: logWithId.exerciseLogs
            .map((exerciseLog) => exerciseLog.copyWith(routineLogId: id))
            .toList(),
      );

      await _logRepository.upsertLog(updatedLog);
      await _logRepository.loadLogs();

      if (AppConfig.isClient) {
        final clientId = Supabase.instance.client.auth.currentUser?.id;
        if (clientId != null && clientId.isNotEmpty) {
          unawaited(sendFcmNotification(
            userId: clientId,
            logId: updatedLog.id,
          ));
        }
      }

      if (logs.isNotEmpty) {
        await schedulePreferredTrainingReminders(logs: logs);
        await scheduleTrainingNutritionNudges(logs: logs);
      } else {
        await cancelTrainingNutritionNudges();
      }
      return updatedLog;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving log", error: e);
      return null;
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Update a routine log in Supabase.
  Future<bool> updateLog({required RoutineLogDto log}) async {
    if (_blockIfClientMode()) return false;
    if (!hasValidWorkoutSessionTemplateId(log.templateId)) {
      errorMessage =
          'This workout must be linked to a template. It cannot be updated in this state.';
      notifyListeners();
      return false;
    }
    isLoading = true;
    bool success = false;
    try {
      await _logRepository.upsertLog(log);
      await _logRepository.loadLogs();
      success = true;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating log", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return success;
  }

  /// Coach-only: update the coach note for a client's session. Writes directly
  /// to Supabase (no offline layer). Refreshes client data and triggers a push
  /// to the client.
  Future<bool> updateCoachNote({
    required String logId,
    required String? note,
  }) async {
    if (!AppConfig.isCoach || !accessController.hasSelectedClient) {
      return false;
    }
    final clientId = accessController.selectedClientId!;
    isLoading = true;
    bool success = false;
    try {
      await _logRepository.updateCoachNote(logId: logId, note: note);
      await _loadRemoteForClient(clientId);
      unawaited(sendFcmNotificationCoachFeedback(
          clientUserId: clientId, logId: logId));
      success = true;
    } catch (e, stackTrace) {
      errorMessage = "Failed to save feedback. Please try again.";
      logger.e("Error updating coach note: $e", error: e, stackTrace: stackTrace);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return success;
  }

  /// Resolves the live `template_exercises.id` (handles stale ids after template upsert).
  Future<String?> resolveCoachTemplateExerciseRowId({
    required String templateId,
    required String candidateTemplateExerciseId,
    required String exerciseId,
    int? templateExerciseOrderIndex,
  }) {
    return _templateRepository.resolveTemplateExerciseRowId(
      templateId: templateId,
      candidateTemplateExerciseId: candidateTemplateExerciseId,
      exerciseId: exerciseId,
      orderIndex: templateExerciseOrderIndex,
    );
  }

  /// Coach-only: attach, replace, or remove instructional video on a template exercise
  /// (template editor). Refreshes the selected client's templates.
  ///
  /// [templateId], [exerciseId], and [templateExerciseOrderIndex] let the server find the
  /// correct row after a template re-save (ids are recreated on each upsert).
  Future<bool> updateCoachTemplateExerciseInstructionVideo({
    required String templateExerciseId,
    String? newStoragePath,
    required String templateId,
    required String exerciseId,
    int? templateExerciseOrderIndex,
  }) async {
    if (!AppConfig.isCoach || !accessController.hasSelectedClient) {
      return false;
    }
    final clientId = accessController.selectedClientId!;
    isLoading = true;
    errorMessage = '';
    var ok = false;
    try {
      final video = CoachInstructionVideoService();
      final next = newStoragePath?.trim();
      final prevFromDb = await _templateRepository.updateCoachInstructionVideoPath(
        templateExerciseId: templateExerciseId,
        storagePath: (next != null && next.isNotEmpty) ? next : null,
        templateId: templateId,
        exerciseId: exerciseId,
        orderIndex: templateExerciseOrderIndex,
      );
      if (prevFromDb != null &&
          prevFromDb.isNotEmpty &&
          (next == null || next.isEmpty || next != prevFromDb)) {
        await video.deleteVideoAtPath(prevFromDb);
      }
      await _loadRemoteForClient(clientId);
      errorMessage = '';
      ok = true;
    } catch (e, stackTrace) {
      errorMessage = 'Could not update coaching video. Try again.';
      logger.e('updateCoachTemplateExerciseInstructionVideo: $e',
          error: e, stackTrace: stackTrace);
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return ok;
  }

  /// Delete a routine log from Supabase.
  Future<void> deleteLog({required RoutineLogDto log}) async {
    if (_blockIfClientMode()) return;
    isLoading = true;
    try {
      await _logRepository.deleteLog(log.id);
      await _logRepository.loadLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error deleting log", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Query Helpers - Exercises

  ExerciseDto? exerciseWhere({required String id}) {
    return exercises.firstWhereOrNull((exercise) => exercise.id == id);
  }

  ExerciseDto? exerciseWhereByName({required String name}) {
    return exercises.firstWhereOrNull(
      (exercise) => exercise.name.toLowerCase() == name.toLowerCase(),
    );
  }

  /// Query Helpers - Plans

  RoutinePlanDto? planWhere({required String id}) {
    return plans.firstWhereOrNull((plan) => plan.id == id);
  }

  /// Query Helpers - Templates

  RoutineTemplateDto? templateWhere({required String id}) {
    return templates.firstWhereOrNull((template) => template.id == id);
  }

  List<RoutineTemplateDto> whereTemplatesForPlan({required String planId}) {
    final list =
        templates.where((template) => template.planId == planId).toList();
    list.sort((a, b) {
      final ao = a.planOrderIndex;
      final bo = b.planOrderIndex;
      if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
      if (ao != null && bo == null) return -1;
      if (ao == null && bo != null) return 1;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  List<RoutineTemplateDto> _templatesForPlanOrderIndexing() {
    if (accessController.hasSelectedClient) {
      return List<RoutineTemplateDto>.from(_overrideTemplates);
    }
    return List<RoutineTemplateDto>.from(_templateRepository.templates);
  }

  RoutineTemplateDto? _templateForReorderValidation(String id) {
    return _templatesForPlanOrderIndexing()
        .firstWhereOrNull((template) => template.id == id);
  }

  /// Persists coach-defined order of workouts (templates) within a plan.
  Future<void> reorderWorkoutsInPlan({
    required String planId,
    required List<String> orderedTemplateIds,
  }) async {
    if (orderedTemplateIds.isEmpty) return;

    final plan = planWhere(id: planId);
    if (!AppPrivileges.isProWithCoach && (plan?.isSystemPlan ?? false)) {
      errorMessage = 'Cannot reorder workouts in this plan.';
      logger.w('reorderWorkoutsInPlan blocked for system plan $planId');
      notifyListeners();
      return;
    }

    final seen = <String>{};
    for (final id in orderedTemplateIds) {
      if (!seen.add(id)) {
        errorMessage = 'Invalid workout order.';
        notifyListeners();
        return;
      }
      final t = _templateForReorderValidation(id);
      if (t == null || t.planId != planId) {
        errorMessage = 'Invalid workout order.';
        notifyListeners();
        return;
      }
    }

    if (accessController.hasSelectedClient) {
      isLoading = true;
      try {
        await _templateRepository.updateTemplatesPlanOrder(
          templateIdsInOrder: orderedTemplateIds,
        );
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = 'Oops! Something went wrong. Please try again later.';
        logger.e('Error reordering plan workouts (client mode)', error: e);
      } finally {
        isLoading = false;
        errorMessage = '';
        notifyListeners();
      }
      return;
    }

    isLoading = true;
    try {
      await _templateRepository.updateTemplatesPlanOrder(
        templateIdsInOrder: orderedTemplateIds,
      );
      await _templateRepository.loadTemplates();
    } catch (e) {
      errorMessage = 'Oops! Something went wrong. Please try again later.';
      logger.e('Error reordering plan workouts', error: e);
    } finally {
      isLoading = false;
      errorMessage = '';
      notifyListeners();
    }
  }

  /// Query Helpers - Logs

  RoutineLogDto? logWhereId({required String id}) {
    return logs.firstWhereOrNull((log) => log.id == id);
  }

  List<RoutineLogDto> whereLogsForTemplate({required String templateId}) {
    return logs.where((log) => log.templateId == templateId).toList();
  }

  List<RoutineLogDto> whereLogsIsSameDay({required DateTime dateTime}) {
    return logs
        .where((log) => log.startTime.isSameDayMonthYear(dateTime))
        .toList();
  }

  List<DateTime> get allWorkoutDates {
    final uniqueDates = <String, DateTime>{};
    for (final log in logs) {
      final dateKey = log.startTime.toIso8601String().substring(0, 10);
      uniqueDates[dateKey] = log.startTime;
    }
    return uniqueDates.values.toList();
  }

  List<ExerciseLogDto> get allExerciseLogs {
    return logs.expand((log) => log.exerciseLogs).toList();
  }

  List<RoutineLogDto> get recentLogs {
    final sorted = List<RoutineLogDto>.from(logs)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.take(10).toList();
  }

  /// Exercise Log Helpers

  List<ExerciseLogDto> whereExerciseLogsForExercise({
    required ExerciseDto exercise,
  }) {
    final matches = <ExerciseLogDto>[];
    for (final routineLog in logs) {
      for (final exerciseLog in routineLog.exerciseLogs) {
        if (exerciseLog.exercise.id == exercise.id) {
          matches.add(exerciseLog);
        }
      }
    }
    return matches;
  }

  // Personal bests removed from project

  /// Workout Stats

  Map<String, dynamic> get workoutStats {
    final totalWorkouts = logs.length;
    final totalExercises = allExerciseLogs.length;
    final totalVolume = allExerciseLogs.fold<double>(
      0,
      (sum, log) =>
          sum +
          log.sets.fold<double>(
            0,
            (setSum, set) {
              // Only weight+reps sets contribute to volume.
              // We avoid importing specific set DTO types here to keep this
              // controller decoupled; volume is computed elsewhere as well.
              try {
                final weight = (set as dynamic).weight as num?;
                final reps = (set as dynamic).reps as num?;
                if (weight != null && reps != null) {
                  return setSum + (weight * reps);
                }
              } catch (_) {
                // Non-weighted sets or unexpected types are ignored in volume.
              }
              return setSum;
            },
          ),
    );

    final avgDuration = logs.isEmpty
        ? Duration.zero
        : Duration(
            seconds: logs
                    .map((log) =>
                        log.endTime.difference(log.startTime).inSeconds)
                    .reduce((a, b) => a + b) ~/
                totalWorkouts,
          );

    return {
      'totalWorkouts': totalWorkouts,
      'totalExercises': totalExercises,
      'totalVolume': totalVolume,
      'avgDuration': avgDuration,
    };
  }

  // Personal bests removed from project

  List<RoutineLogDto> whereLogsIsSameMonth({required DateTime dateTime}) {
    return logs.where((log) {
      return log.startTime.year == dateTime.year &&
          log.startTime.month == dateTime.month;
    }).toList();
  }

  List<RoutineLogDto> whereLogsWithTemplateId({required String templateId}) {
    return whereLogsForTemplate(templateId: templateId);
  }

  List<SetDto> whereRecentSetsForExercise({required ExerciseDto exercise}) {
    // No past sets if type is unknown.
    if (exercise.type == ExerciseType.none) return [];

    final targetType = exercise.type;
    final exerciseLogsWithTimestamps =
        <({ExerciseLogDto log, DateTime timestamp})>[];

    for (final routineLog in logs) {
      for (final exerciseLog in routineLog.exerciseLogs) {
        // Match by exercise id AND type to avoid mixing set shapes.
        if (exerciseLog.exercise.id == exercise.id &&
            exerciseLog.exercise.type == targetType) {
          exerciseLogsWithTimestamps
              .add((log: exerciseLog, timestamp: routineLog.startTime));
        }
      }
    }

    if (exerciseLogsWithTimestamps.isEmpty) return [];

    // Sort by timestamp (most recent first)
    exerciseLogsWithTimestamps
        .sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Get the most recent 3 exercise logs
    final recentLogs =
        exerciseLogsWithTimestamps.take(3).map((e) => e.log).toList();
    final allSets = <SetDto>[];
    for (final log in recentLogs) {
      allSets.addAll(log.sets);
    }
    return allSets;
  }

  /// Returns the most recent [limit] exercise logs for a given exercise,
  /// ordered from most recent to oldest.
  ///
  /// Only returns one exercise log per distinct session (routineLogId),
  /// even if the same exercise appears multiple times in a session.
  List<ExerciseLogDto> whereRecentExerciseLogsForExercise({
    required ExerciseDto exercise,
    int limit = 4,
  }) {
    final matches =
        <({ExerciseLogDto log, DateTime timestamp, String? routineLogId})>[];

    for (final routineLog in logs) {
      for (final exerciseLog in routineLog.exerciseLogs) {
        if (exerciseLog.exercise.id == exercise.id) {
          matches.add((
            log: exerciseLog,
            timestamp: routineLog.startTime,
            routineLogId: routineLog.id,
          ));
        }
      }
    }

    if (matches.isEmpty) return const [];

    matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Group by routineLogId to ensure we only return one exercise log per session
    final seenRoutineLogIds = <String?>{};
    final distinctMatches = <ExerciseLogDto>[];

    for (final match in matches) {
      if (!seenRoutineLogIds.contains(match.routineLogId)) {
        seenRoutineLogIds.add(match.routineLogId);
        distinctMatches.add(match.log);
        if (distinctMatches.length >= limit) break;
      }
    }

    return distinctMatches;
  }

  List<SetDto> wherePrevSetsForExercise({required ExerciseDto exercise}) {
    final exerciseLogs = whereExerciseLogsForExercise(exercise: exercise);
    if (exerciseLogs.isEmpty) return [];

    final allSets = <SetDto>[];
    for (final log in exerciseLogs) {
      allSets.addAll(log.sets);
    }
    return allSets;
  }

  /// Fetches the owner (client) user id for a routine log. Used when opening a
  /// log from a notification so the coach app can load that client's data first.
  Future<String?> fetchLogOwnerId(String logId) async {
    return _logRepository.getOwnerIdForLog(logId);
  }

  /// Refreshes routine logs from the cloud for the current user (client app).
  /// Used when opening a log from a notification.
  Future<void> refreshRoutineLogsFromCloudForCurrentUser() async {
    await _logRepository.loadLogs();
    notifyListeners();
  }

  Future<void> loadClientData({
    required String clientId,
    String? clientName,
  }) async {
    accessController.setSelectedClient(
      clientId: clientId,
      clientName: clientName,
    );
    isLoading = true;
    notifyListeners();
    try {
      await _loadRemoteForClient(clientId);
    } catch (e) {
      logger.e("Error loading client data", error: e);
      errorMessage = "Failed to load client data.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSelectedClient() async {
    accessController.clearSelectedClient();
    _overrideTemplates = const [];
    _overridePlans = const [];
    _overrideLogs = const [];
    await initialize();
  }

  Future<void> _loadRemoteForClient(String clientId) async {
    final ownerId = Supabase.instance.client.auth.currentUser?.id;
    await _templateRepository.loadTemplates(
      ownerIdOverride: ownerId,
      clientIdOverride: clientId,
      requireOwnerAndClient: true,
    );
    _overrideTemplates = _templateRepository.templates.toList();
    await _planRepository.loadPlans(
      ownerIdOverride: ownerId,
      clientIdOverride: clientId,
      requireOwnerAndClient: true,
    );
    _overridePlans = _planRepository.plans.toList();
    await _logRepository.loadLogs(userIdOverride: clientId);
    _overrideLogs = _logRepository.logs.toList();
  }

  Future<void> removeLog({required RoutineLogDto log}) async {
    return deleteLog(log: log);
  }

  Future<void> removePlan({required RoutinePlanDto plan}) async {
    return deletePlan(plan: plan);
  }

  Future<void> removeTemplate({required RoutineTemplateDto template}) async {
    return deleteTemplate(template: template);
  }

  /// Clear all data (on logout)
  void clear() {
    isLoading = false;
    errorMessage = '';
    notifyListeners();
  }
}
