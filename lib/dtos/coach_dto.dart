/// Client model for coach list/detail: built from Not Athletes
/// `GET /coach-profiles` / `GET /coach-profiles/:id` JSON ([CoachDto.fromJson]).
///
/// [fromJson] avoids throwing on mixed API types (e.g. new fields as bool/list);
/// a thrown parse would drop the whole profile in [fetchCoachProfileFromNotathletesApi].
class CoachDto {
  final String id;
  final String name;
  final String? profileImageUrl;
  final String? profileVideoUrl;
  final String? description;
  final String? email;
  final int? yearsExperience;

  /// When the API sends `years_experience` (or `yearsExperience`) as a string.
  /// Pure numeric strings get `"<n> years of experience"` in [experienceDisplayLine];
  /// any other wording is shown verbatim.
  final String? yearsExperienceText;
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
    this.yearsExperienceText,
    this.qualifications,
    this.specialties,
    this.interestsHobbies,
  });

  static String _reqString(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? fallback : t;
    }
    if (v is num) return v.toString();
    return v.toString().trim().isEmpty ? fallback : v.toString().trim();
  }

  /// String fields only; maps/lists from the API are ignored (would break `as String?`).
  static String? _optString(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    if (v is num) return v.toString();
    if (v is bool) return null;
    if (v is Map || v is List) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  factory CoachDto.fromJson(Map<String, dynamic> json) {
    final yRaw = json['years_experience'] ?? json['yearsExperience'];
    int? yearsExperience;
    String? yearsExperienceText;
    if (yRaw != null) {
      if (yRaw is String) {
        final t = yRaw.trim();
        if (t.isNotEmpty) {
          yearsExperienceText = t;
          yearsExperience = int.tryParse(t);
        }
      } else if (yRaw is num) {
        yearsExperience = yRaw.toInt();
      }
    }

    // Not Athletes `GET /coach-profiles/:id` uses `full_name`, `profile_photo_url`,
    // `short_bio`, `intro_video_url` (see API). Supabase embeds often use `name` /
    // `profile_image_url` / `description` — support both.
    return CoachDto(
      id: _reqString(json['id']),
      name: _reqString(
        json['name'] ??
            json['full_name'] ??
            json['display_name'] ??
            json['displayName'],
      ),
      profileImageUrl: _optString(
        json['profile_image_url'] ??
            json['profileImageUrl'] ??
            json['profile_photo_url'] ??
            json['profilePhotoUrl'],
      ),
      profileVideoUrl: _optString(
        json['profile_video_url'] ??
            json['profileVideoUrl'] ??
            json['intro_video_url'] ??
            json['introVideoUrl'],
      ),
      description: _optString(
        json['description'] ?? json['short_bio'] ?? json['shortBio'],
      ),
      email: _optString(json['email']),
      yearsExperience: yearsExperience,
      yearsExperienceText: yearsExperienceText,
      qualifications: _optString(json['qualifications']),
      specialties: _optString(json['specialties']),
      interestsHobbies: _optString(
        json['interests_hobbies'] ?? json['interestsHobbies'],
      ),
    );
  }

  /// Experience for UI: numeric values become `"<n> years of experience"`.
  /// Non-numeric API strings are shown as returned (no extra “+” from the app).
  String? get experienceDisplayLine {
    final t = yearsExperienceText?.trim();
    if (t != null && t.isNotEmpty) {
      final parsed = int.tryParse(t);
      if (parsed != null && parsed > 0 && t == parsed.toString()) {
        return '$parsed years of experience';
      }
      return t;
    }
    final y = yearsExperience;
    if (y != null && y > 0) return '$y years of experience';
    return null;
  }
}
