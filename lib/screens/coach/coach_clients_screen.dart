import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/widgets/empty_states/list_empty_state.dart';

class CoachClientsScreen extends StatefulWidget {
  final bool navigateToOverviewOnSelect;

  const CoachClientsScreen({
    super.key,
    this.navigateToOverviewOnSelect = false,
  });

  @override
  State<CoachClientsScreen> createState() => _CoachClientsScreenState();
}

class _CoachClientsScreenState extends State<CoachClientsScreen> {
  late final Future<List<_CoachClient>> _clientsFuture;
  String? _loadingClientId;

  @override
  void initState() {
    super.initState();
    _clientsFuture = _loadClients();
  }

  Future<List<_CoachClient>> _loadClients() async {
    final response = await Supabase.instance.client
        .from('clients')
        .select('id, email, name, created_at')
        .order('name', ascending: true);
    final rows = response as List<dynamic>;
    return rows
        .map((row) => _CoachClient.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final routineController =
        context.read<SupabaseExerciseAndRoutineController>();
    final nutritionController = context.read<NutritionLogController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'Clients'.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.all(16),
          child: FutureBuilder<List<_CoachClient>>(
            future: _clientsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load clients.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              final clients = snapshot.data ?? const [];
              if (clients.isEmpty) {
                return const ListEmptyState(
                  message:
                      'No clients found yet. Once clients are added, they’ll appear here.',
                );
              }

              return ListView.separated(
                itemCount: clients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final client = clients[index];
                  final isLoadingClient = _loadingClientId == client.id;
                  return InkWell(
                    onTap: isLoadingClient
                        ? null
                        : () async {
                            setState(() => _loadingClientId = client.id);
                            try {
                              await routineController.loadClientData(
                                clientId: client.id,
                                clientName: client.name,
                                clientEmail: null,
                              );
                              await nutritionController.loadClientData(
                                clientId: client.id,
                              );
                              if (context.mounted) {
                                if (widget.navigateToOverviewOnSelect) {
                                  context.go('/');
                                } else {
                                  Navigator.of(context).pop();
                                }
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _loadingClientId = null);
                              }
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  (isDarkMode ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.18),
                                  (isDarkMode ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              client.initials,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                const SizedBox.shrink(),
                              ],
                            ),
                          ),
                          if (isLoadingClient)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CoachClient {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  const _CoachClient({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  factory _CoachClient.fromJson(Map<String, dynamic> json) {
    return _CoachClient(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return _fallbackInitials(email);
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return _fallbackInitials(email);
    }
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.first.toString().toUpperCase();
    final last = parts.last.characters.first.toString().toUpperCase();
    return '$first$last';
  }

  String _fallbackInitials(String value) {
    if (value.isEmpty) return '';
    final cleaned = value.split('@').first;
    return cleaned.characters.take(2).toString().toUpperCase();
  }
}
