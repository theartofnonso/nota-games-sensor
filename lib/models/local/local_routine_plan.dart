import 'package:isar/isar.dart';

part 'local_routine_plan.g.dart';

@collection
class LocalRoutinePlan {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String planId; // UUID from DTO

  late String jsonData; // Serialized RoutinePlanDto

  @Index()
  late String name; // For searching

  late DateTime lastModifiedLocal;

  late bool needsSync;

  String? syncError;

  late DateTime createdAt;

  // Constructor
  LocalRoutinePlan();
}

