import 'package:flutter/material.dart';

import 'package:gameware/colors.dart';

/// Team assigned on join (`POST /sessions/:id/join` → `team`).
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;

  /// Hex colour string, e.g. `#EF4444`.
  final String color;

  static Team? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final color = json['color'] as String?;
    if (id == null || name == null || color == null) return null;
    return Team(id: id, name: name, color: color);
  }

  Color? get flutterColor => parseTeamColor(color);
}

/// Placeholder pulse colour when team is assigned but colour is invalid.
const defaultTeamPulseColor = info;

/// Parses `#RRGGBB`, `RRGGBB`, or `#AARRGGBB`.
Color? parseTeamColor(String? value) {
  if (value == null) return null;

  var hex = value.trim();
  if (hex.isEmpty) return null;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;

  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;

  return Color(parsed);
}
