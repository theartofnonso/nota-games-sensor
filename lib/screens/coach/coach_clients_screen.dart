import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/services/chat_unread_counts_service.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/widgets/badges/unread_badge.dart';
import 'package:trainware/widgets/search_bar.dart';
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

class _CoachClientsScreenState extends State<CoachClientsScreen>
    with WidgetsBindingObserver {
  late Future<List<_CoachClient>> _clientsFuture;
  String? _loadingClientId;
  Map<String, int> _unreadByClientId = const {};
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clientsFuture = _loadClients();
    _searchController = TextEditingController();
    _unreadByClientId = ChatUnreadCountsService().unreadByClientId.value;
    ChatUnreadCountsService().unreadByClientId.addListener(_handleUnreadChange);
    ChatUnreadCountsService()
        .updateContext(coachId: Supabase.instance.client.auth.currentUser?.id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatUnreadCountsService()
        .unreadByClientId
        .removeListener(_handleUnreadChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleUnreadChange() {
    if (!mounted) return;
    setState(() {
      _unreadByClientId = ChatUnreadCountsService().unreadByClientId.value;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatUnreadCountsService().refreshSubscription();
      ChatUnreadCountsService().refreshUnreadCounts();
    }
  }

  Future<void> _refreshClientsAndUnread() async {
    final next = _loadClients();
    if (mounted) {
      setState(() {
        _clientsFuture = next;
      });
    }
    await next;
    await ChatUnreadCountsService().refreshUnreadCounts();
  }

  void _updateSearch(String value) {
    if (!mounted) return;
    setState(() {
      _searchQuery = value.trim();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _updateSearch('');
  }

  List<_CoachClient> _filterClients(List<_CoachClient> clients) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return clients;
    return clients.where((client) {
      final name = client.name.toLowerCase();
      return name.contains(query);
    }).toList();
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
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: FutureBuilder<List<_CoachClient>>(
            future: _clientsFuture,
            builder: (context, snapshot) {
              final theme = Theme.of(context);
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load clients.',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }

              final clients = _filterClients(snapshot.data ?? const []);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'Clients',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a client to view their training experience.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: CSearchBar(
                      hintText: 'Search clients',
                      onChanged: _updateSearch,
                      onClear: _clearSearch,
                      controller: _searchController,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (clients.isEmpty)
                    const Expanded(
                      child: ListEmptyState(
                        message:
                            'No clients found yet. Once clients are added, they’ll appear here.',
                      ),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshClientsAndUnread,
                        child: ListView.separated(
                          itemCount: clients.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final client = clients[index];
                            final isLoadingClient =
                                _loadingClientId == client.id;
                            final unreadCount =
                                _unreadByClientId[client.id] ?? 0;
                            final joinedLabel = DateFormat('MMM yyyy')
                                .format(client.createdAt.toLocal());
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: isLoadingClient
                                  ? null
                                  : () async {
                                      setState(
                                          () => _loadingClientId = client.id);
                                      try {
                                        await routineController.loadClientData(
                                          clientId: client.id,
                                          clientName: client.name,
                                        );
                                        await nutritionController
                                            .loadClientData(
                                          clientId: client.id,
                                        );
                                        if (context.mounted) {
                                          if (widget
                                              .navigateToOverviewOnSelect) {
                                            context.go('/');
                                          } else {
                                            Navigator.of(context).pop();
                                          }
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(
                                              () => _loadingClientId = null);
                                        }
                                      }
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        client.initials,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.name,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Client since $joinedLabel',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: Colors.white
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isLoadingClient)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    else
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          UnreadBadge(
                                            count: unreadCount,
                                            fontSize: 11,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                          ),
                                          if (unreadCount > 0)
                                            const SizedBox(width: 8),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
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
