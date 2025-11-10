import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tracker_app/logger.dart';
import 'package:tracker_app/models/local/local_exercise.dart';
import 'package:tracker_app/models/local/local_routine_log.dart';
import 'package:tracker_app/models/local/local_routine_plan.dart';
import 'package:tracker_app/models/local/local_routine_template.dart';
import 'package:tracker_app/models/local/sync_queue_item.dart';

class IsarService {
  static final logger = getLogger(className: "IsarService");
  static Isar? _isar;

  static Future<Isar> initialize() async {
    if (_isar != null) return _isar!;

    try {
      final dir = await getApplicationDocumentsDirectory();
      
      _isar = await Isar.open(
        [
          LocalExerciseSchema,
          LocalRoutineLogSchema,
          LocalRoutineTemplateSchema,
          LocalRoutinePlanSchema,
          SyncQueueItemSchema,
        ],
        directory: dir.path,
        inspector: true, // Enable Isar Inspector for debugging
      );

      logger.i('Isar database initialized at: ${dir.path}');
      return _isar!;
    } catch (e) {
      logger.e('Error initializing Isar: $e');
      rethrow;
    }
  }

  static Isar get instance {
    if (_isar == null) {
      throw Exception('Isar not initialized. Call IsarService.initialize() first.');
    }
    return _isar!;
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
    logger.i('Isar database closed');
  }
}

