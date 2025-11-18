import 'package:trainware/enums/muscle_group_enums.dart';

extension MuscleGroupExtension on MuscleGroup {
  String illustration() {
    return switch (this) {
      MuscleGroup.abductors => "abductors",
      MuscleGroup.adductors => "adductors",
      MuscleGroup.abs => "abs",
      MuscleGroup.back => "back",
      MuscleGroup.rearShoulders => "rearShoulders",
      MuscleGroup.biceps => "biceps",
      MuscleGroup.calves => "calves",
      MuscleGroup.chest => "chest",
      MuscleGroup.forearms => "forearms",
      MuscleGroup.frontShoulders => "frontShoulders",
      MuscleGroup.glutes => "glutes",
      MuscleGroup.hamstrings => "hamstrings",
      MuscleGroup.lats => "lats",
      MuscleGroup.neck => "neck",
      MuscleGroup.traps => "traps",
      MuscleGroup.triceps => "triceps",
      MuscleGroup.quadriceps => "quadriceps",
      MuscleGroup.fullBody => "fullbody",
    };
  }
}
