import 'package:tracker_app/shared_prefs.dart';

const defaultPlanId = "DEFAULT_PLAN_ID";

class RoutinePlanDto {
  final String id;
  final String name;
  final String notes;
  final String owner;
  final DateTime createdAt;
  final DateTime updatedAt;

  static final defaultPlan = RoutinePlanDto(
      id: defaultPlanId,
      name: "Your workout plans",
      notes:
          "This is your default plan. If you'd like to organize your workouts into different plans, simply create a new one.",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      owner: SharedPrefs().userId);

  RoutinePlanDto({
    required this.id,
    required this.name,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'name': name,
      'notes': notes,
      'owner': owner,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RoutinePlanDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";
    final owner = json["owner"] ?? "";
    final createdAt = json["createdAt"] != null ? DateTime.parse(json["createdAt"]) : DateTime.now();
    final updatedAt = json["updatedAt"] != null ? DateTime.parse(json["updatedAt"]) : DateTime.now();

    return RoutinePlanDto(
      id: id,
      name: name,
      notes: notes,
      owner: owner,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  RoutinePlanDto copyWith({
    String? id,
    String? name,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? owner,
  }) {
    return RoutinePlanDto(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      owner: owner ?? this.owner,
    );
  }

  @override
  String toString() {
    return 'RoutinePlanDto{id: $id, name: $name, notes: $notes, owner: $owner, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
