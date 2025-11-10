import 'package:isar/isar.dart';

part 'local_routine_template.g.dart';

@collection
class LocalRoutineTemplate {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String templateId; // UUID from DTO

  late String jsonData; // Serialized RoutineTemplateDto

  @Index()
  late String name; // For searching

  @Index()
  late String planId; // For filtering by plan

  late DateTime lastModifiedLocal;

  late bool needsSync;

  String? syncError;

  late DateTime createdAt;

  // Constructor
  LocalRoutineTemplate();
}
