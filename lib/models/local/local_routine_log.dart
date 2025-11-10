import 'package:isar/isar.dart';

part 'local_routine_log.g.dart';

@collection
class LocalRoutineLog {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String logId; // UUID from DTO

  late String jsonData; // Serialized RoutineLogDto

  @Index()
  late String name; // For searching

  @Index()
  late DateTime startTime; // For date range filtering

  @Index()
  late DateTime endTime;

  late DateTime lastModifiedLocal;

  late bool needsSync;

  String? syncError;

  late DateTime createdAt;

  // Constructor
  LocalRoutineLog();
}
