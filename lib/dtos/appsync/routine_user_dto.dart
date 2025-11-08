import '../../enums/gender_enums.dart';

class RoutineUserDto {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String trainingHistory;
  final num weight;
  final num height;
  final DateTime dateOfBirth;
  final TRKRGender gender;
  final String owner;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoutineUserDto({
    required this.id,
    required this.name,
    required this.userId,
    required this.email,
    required this.weight,
    required this.height,
    required this.owner,
    required this.trainingHistory,
    required this.dateOfBirth,
    required this.gender,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoutineUserDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final userId = json["userId"] ?? "";
    final name = json["name"] ?? "";
    final email = json["email"] ?? "";
    final trainingHistory = json["trainingHistory"] ?? "";
    final weight = (json["weight"]) ?? 0.0;
    final height = (json["height"]) ?? 0;
    final dateOfBirthMillisecondsSinceEpoch = (json["dob"]) as int? ?? DateTime.now().millisecondsSinceEpoch;
    final dateOfBirth = DateTime.fromMillisecondsSinceEpoch(dateOfBirthMillisecondsSinceEpoch);
    final genderString = json["gender"] ?? "";
    final gender = TRKRGender.fromString(genderString);
    final owner = json["owner"] ?? "";
    final createdAt = json["createdAt"] != null ? DateTime.parse(json["createdAt"]) : DateTime.now();
    final updatedAt = json["updatedAt"] != null ? DateTime.parse(json["updatedAt"]) : DateTime.now();

    return RoutineUserDto(
      id: id,
      name: name,
      userId: userId,
      email: email,
      weight: weight,
      height: height,
      owner: owner,
      trainingHistory: trainingHistory,
      dateOfBirth: dateOfBirth,
      gender: gender,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'weight': weight,
      'height': height,
      'dob': dateOfBirth.millisecondsSinceEpoch,
      'gender': gender.display,
      'trainingHistory': trainingHistory,
      'owner': owner,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  RoutineUserDto copyWith({
    String? id,
    String? name,
    String? userId,
    String? email,
    String? trainingHistory,
    num? weight,
    num? height,
    String? owner,
    DateTime? dateOfBirth,
    TRKRGender? gender,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoutineUserDto(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      trainingHistory: trainingHistory ?? this.trainingHistory,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      owner: owner ?? this.owner,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'RoutineUserDto{id: $id, userId: $userId, name: $name, trainingHistory: $trainingHistory, email: $email, weight: $weight, height: $height, dateOfBirth: $dateOfBirth, gender: $gender, owner: $owner, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
