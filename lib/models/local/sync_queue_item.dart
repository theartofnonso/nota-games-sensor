import 'package:isar/isar.dart';

part 'sync_queue_item.g.dart';

@collection
class SyncQueueItem {
  Id id = Isar.autoIncrement;

  @Index()
  late String entityType; // 'exercise', 'log', 'template', 'plan'

  @Index()
  late String entityId; // The actual ID of the entity

  late String operation; // 'create', 'update', 'delete'

  late String jsonData; // Serialized DTO as JSON string

  @Index()
  late DateTime createdAt;

  late int retryCount;

  String? lastError;

  // Constructor
  SyncQueueItem();

  // Helper to create from parameters
  static SyncQueueItem create({
    required String entityType,
    required String entityId,
    required String operation,
    required String jsonData,
  }) {
    final item = SyncQueueItem()
      ..entityType = entityType
      ..entityId = entityId
      ..operation = operation
      ..jsonData = jsonData
      ..createdAt = DateTime.now()
      ..retryCount = 0;
    return item;
  }
}
