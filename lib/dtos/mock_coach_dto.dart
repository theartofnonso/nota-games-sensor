/// Mock coach DTO for the coach selection flow.
/// Matches coaches schema: id, name, profile_image_url, description.
class MockCoachDto {
  final String id;
  final String name;
  final String? profileImageUrl;
  final String? description;

  const MockCoachDto({
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.description,
  });
}
