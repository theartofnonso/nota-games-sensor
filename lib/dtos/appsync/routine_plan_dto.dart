import 'dart:convert';

import 'package:tracker_app/shared_prefs.dart';

import '../../models/RoutinePlan.dart';

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
          "This is your default plan. If you’d like to organize your workouts into different plans, simply create a new one.",
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

  Map<String, Object> toJson() {
    return {
      "id": id,
      'name': name,
      'notes': notes,
    };
  }

  factory RoutinePlanDto.toDto(RoutinePlan plan) {
    return RoutinePlanDto.fromPlan(plan: plan);
  }

  factory RoutinePlanDto.fromPlan({required RoutinePlan plan}) {
    final json = jsonDecode(plan.data);
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";

    return RoutinePlanDto(
      id: plan.id,
      name: name,
      notes: notes,
      owner: plan.owner ?? "",
      createdAt: plan.createdAt.getDateTimeInUtc(),
      updatedAt: plan.updatedAt.getDateTimeInUtc(),
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
