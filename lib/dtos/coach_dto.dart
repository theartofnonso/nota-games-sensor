/// Client model for coach list/detail: built from `coaches` plus optional
/// nested `coach_profiles` (see [SupabaseCoachesRepository]).
class CoachDto {
  final String id;
  final String name;
  final String? profileImageUrl;
  final String? profileVideoUrl;
  final String? description;
  final String? email;
  final int? yearsExperience;
  final String? qualifications;
  final String? specialties;
  final String? interestsHobbies;

  const CoachDto({
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.profileVideoUrl,
    this.description,
    this.email,
    this.yearsExperience,
    this.qualifications,
    this.specialties,
    this.interestsHobbies,
  });

  factory CoachDto.fromJson(Map<String, dynamic> json) {
    return CoachDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      profileVideoUrl: json['profile_video_url'] as String?,
      description: json['description'] as String?,
      email: json['email'] as String?,
      yearsExperience: (json['years_experience'] as num?)?.toInt(),
      qualifications: json['qualifications'] as String?,
      specialties: json['specialties'] as String?,
      interestsHobbies: json['interests_hobbies'] as String?,
    );
  }
}
