/// Saved workout sessions must reference a routine template (`workout_sessions.template_id`).
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// True when [templateId] is a non-empty UUID suitable for `template_id`.
bool hasValidWorkoutSessionTemplateId(String templateId) =>
    _uuidV4.hasMatch(templateId.trim());
