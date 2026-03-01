/// DTO matching [public.coaches] schema.
class CoachDto {
  final String id;
  final String name;
  final String? profileImageUrl;
  final String? profileVideoUrl;
  final String? description;
  final String? email;

  const CoachDto({
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.profileVideoUrl,
    this.description,
    this.email,
  });

  factory CoachDto.fromJson(Map<String, dynamic> json) {
    return CoachDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      profileVideoUrl: json['profile_video_url'] as String?,
      description: json['description'] as String?,
      email: json['email'] as String?,
    );
  }
}
