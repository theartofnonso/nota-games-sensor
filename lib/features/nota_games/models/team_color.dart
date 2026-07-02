import 'package:flutter/material.dart';

import 'package:gameware/colors.dart';

/// Placeholder until the controller sends [PlayerSession.teamColor].
const defaultTeamPulseColor = info;

/// Parses `#RRGGBB`, `RRGGBB`, or `#AARRGGBB` from the backend.
Color? parseTeamColor(Object? value) {
  if (value is! String) return null;

  var hex = value.trim();
  if (hex.isEmpty) return null;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;

  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;

  return Color(parsed);
}

Color? readTeamColorFromJson(Map<String, dynamic> json) {
  final direct = parseTeamColor(json['teamColor'] ?? json['team_color']);
  if (direct != null) return direct;

  final team = json['team'] ?? json['teams'];
  if (team is Map) {
    final record = Map<String, dynamic>.from(team);
    return parseTeamColor(record['color'] ?? record['teamColor'] ?? record['team_color']);
  }

  return null;
}
