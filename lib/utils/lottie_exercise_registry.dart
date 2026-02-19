import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logger.dart';

/// Resolves exercise IDs to Lottie animations from Supabase `exercises.lottie_path`.
/// Uses a local file cache so lookups still work when offline.
class LottieExerciseRegistry {
  static Future<Map<String, String>>? _cache;
  static final _rand = Random();
  static final _logger = getLogger(className: 'LottieExerciseRegistry');
  static const _cacheFileName = 'exercise_lottie_registry_cache.json';

  static Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  static Future<Map<String, String>> _readLocalCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return const {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      _logger.w('Failed reading lottie registry cache: $e');
      return const {};
    }
  }

  static Future<void> _writeLocalCache(Map<String, String> map) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(map), flush: true);
    } catch (e) {
      _logger.w('Failed writing lottie registry cache: $e');
    }
  }

  static Future<Map<String, String>> _fetchFromSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select('id,lottie_path')
          .order('name', ascending: true);
      final rows = response as List<dynamic>;
      final map = <String, String>{};
      for (final row in rows) {
        final json = Map<String, dynamic>.from(row as Map);
        final id = (json['id'] ?? '').toString().trim();
        final path = (json['lottie_path'] ?? '').toString().trim();
        if (id.isNotEmpty && path.isNotEmpty) {
          map[id] = path;
        }
      }
      if (map.isNotEmpty) {
        await _writeLocalCache(map);
      }
      return map;
    } catch (e) {
      _logger.w('Failed loading lottie registry from Supabase: $e');
      return const {};
    }
  }

  static Future<Map<String, String>> _refreshFromSupabase() async {
    final remote = await _fetchFromSupabase();
    if (remote.isNotEmpty) {
      _cache = Future.value(remote);
      return remote;
    }
    final cached = await _readLocalCache();
    _cache = Future.value(cached);
    return cached;
  }

  static Future<Map<String, String>> _load() async {
    final cached = await _readLocalCache();
    if (cached.isNotEmpty) {
      _cache = Future.value(cached);
      unawaited(_refreshFromSupabase());
      return cached;
    }
    return _refreshFromSupabase();
  }

  /// Returns the lottie asset path for the given exercise [id], or null.
  static Future<String?> lottieFor(String id) async {
    _cache ??= _load();
    final map = await _cache!;
    return map[id.trim()];
  }

  /// Returns a random lottie asset path from the registry (or null if empty).
  static Future<String?> randomLottie() async {
    _cache ??= _load();
    final map = await _cache!;
    if (map.isEmpty) return null;
    final values = map.values.toList(growable: false);
    return values[_rand.nextInt(values.length)];
  }
}
