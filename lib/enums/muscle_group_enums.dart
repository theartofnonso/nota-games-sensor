import 'package:collection/collection.dart';

enum MuscleGroup {
  neck(
    displayName: "Neck",
    description: "Neck muscles help stabilize the head and support posture.",
  ),
  abs(
    displayName: "Abs",
    description:
        "Abdominal muscles are essential for core stability, balance, and supporting almost all compound lifts.",
  ),
  forearms(
    displayName: "Forearms",
    description:
        "Forearms help with grip strength, wrist stability, and support for lifting and pulling movements.",
  ),
  biceps(
    displayName: "Biceps",
    description:
        "Biceps are responsible for elbow flexion, assisting in pulling movements and lifting.",
  ),
  triceps(
    displayName: "Triceps",
    description:
        "Triceps are the primary muscles for elbow extension, playing a key role in pushing movements.",
  ),
  lats(
    displayName: "Lats",
    description:
        "Latissimus dorsi muscles are crucial for pulling movements such as pull-ups and rows, contributing to a V-taper physique.",
  ),
  traps(
    displayName: "Traps",
    description:
        "Trapezius muscles stabilize the shoulder blades and assist in lifting, shrugging, and pulling movements.",
  ),
  back(
    displayName: "Back",
    description:
        "The back muscles support posture, pulling movements, and core stability.",
  ),
  chest(
    displayName: "Chest",
    description:
        "The chest muscles are key for pushing movements like presses and push-ups, and contribute to upper-body strength.",
  ),
  frontShoulders(
    displayName: "Front Shoulders",
    description:
        "Shoulders (deltoids) enable arm rotation and are involved in pushing and lifting movements.",
  ),
  rearShoulders(
    displayName: "Rear Shoulders",
    description:
        "Shoulders (deltoids) enable arm rotation and are involved in pushing and lifting movements.",
  ),
  abductors(
    displayName: "Abductors",
    description:
        "Abductors move the legs away from the body's midline, essential for lateral movements.",
  ),
  adductors(
    displayName: "Adductors",
    description:
        "Adductors bring the legs toward the body's midline, supporting stability in squats and lunges.",
  ),
  glutes(
    displayName: "Glutes",
    description:
        "Glutes are powerful muscles for hip extension, key in squats, deadlifts, and explosive movements.",
  ),
  hamstrings(
    displayName: "Hamstrings",
    description:
        "Hamstrings handle knee flexion and hip extension, aiding in running, jumping, and lower-body lifts.",
  ),
  quadriceps(
    displayName: "Quadriceps",
    description:
        "Quadriceps are key for knee extension, vital for squats, lunges, and running.",
  ),
  calves(
    displayName: "Calves",
    description:
        "Calves enable ankle flexion, essential for running, jumping, and lower-body stability.",
  ),
  fullBody(
    displayName: "Full Body",
    description:
        "Engages multiple muscle groups to provide a comprehensive and balanced workout.",
  );

  /// Constructor for the enum's associated values
  const MuscleGroup({
    required this.displayName,
    required this.description,
  });

  /// A more user-friendly name than the enum's default `name` property
  final String displayName;

  /// Description of the muscle group's primary role
  final String description;

  /// Returns a sorted list of all MuscleGroups by [displayName].
  static List<MuscleGroup> get sortedValues {
    // `values` is built-in on every enum. We sort them here by displayName.
    return values.sorted((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// Finds a MuscleGroup by its [displayName] (case-insensitive).
  /// Defaults to [MuscleGroup.fullBody] if no match is found.
  static MuscleGroup fromString(String string) {
    return values.firstWhere(
      (group) => group.displayName.toLowerCase() == string.toLowerCase(),
      orElse: () => MuscleGroup.fullBody,
    );
  }

  static const upper = <MuscleGroup>{
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.lats,
    MuscleGroup.frontShoulders,
    MuscleGroup.rearShoulders,
    MuscleGroup.biceps,
    MuscleGroup.triceps,
    MuscleGroup.traps,
    MuscleGroup.abs,
  };

  static const lower = <MuscleGroup>{
    MuscleGroup.quadriceps,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes,
    MuscleGroup.calves,
    MuscleGroup.adductors,
    MuscleGroup.abductors,
  };

  /// Returns the user-friendly [displayName] instead of the enum's default `name`.
  @override
  String toString() => displayName;
}
