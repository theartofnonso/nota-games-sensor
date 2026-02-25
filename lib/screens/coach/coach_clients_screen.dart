import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/coach_client_dto.dart';
import 'package:trainware/services/chat_bootstrap_service.dart';
import 'package:trainware/services/chat_unread_counts_service.dart';
import 'package:trainware/services/coach_clients_service.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/widgets/search_bar.dart';
import 'package:trainware/widgets/empty_states/list_empty_state.dart';
import 'package:trainware/widgets/badges/unread_badge.dart';
import 'package:trainware/widgets/loading/coach_loading_overlay.dart';

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
  String _appVersion = '';
  Map<String, int> _unreadByClientId = const {};
  late final TextEditingController _searchController;
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
    _unreadByClientId = ChatUnreadCountsService().unreadByClientId.value;
    ChatUnreadCountsService().unreadByClientId.addListener(_handleUnreadChange);
    _getAppVersion();
    _refreshUnreadWhenAgoraReady();
  }

  /// Refresh unread counts when Agora has logged in. Clients are pre-loaded
  /// at startup, so we just need Agora ready to fetch counts.
  void _refreshUnreadWhenAgoraReady() {
    void doRefresh() {
      if (!mounted) return;
      ChatUnreadCountsService().refreshUnreadCounts();
    }

    if (ChatBootstrapService.agoraLoggedIn.value) {
      doRefresh();
      return;
    }
    void listener() {
      if (!ChatBootstrapService.agoraLoggedIn.value) return;
      ChatBootstrapService.agoraLoggedIn.removeListener(listener);
      doRefresh();
    }
    ChatBootstrapService.agoraLoggedIn.addListener(listener);
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
      ChatUnreadCountsService().refreshUnreadCounts();
      ChatUnreadCountsService().refreshTotalUnreadCount();
    }
  }

  Future<void> _refreshClientsAndUnread() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) setState(() {});
    try {
      await CoachClientsService.instance.loadClients();
      await ChatUnreadCountsService().refreshUnreadCounts();
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() {});
    }
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

  List<CoachClientDto> _filterClients(List<CoachClientDto> clients) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return clients;
    return clients.where((c) {
      final name = (c.clientName ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  Future<void> _retryLoadClients() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) setState(() {});
    try {
      await CoachClientsService.instance.loadClients();
      if (mounted) setState(() {});
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    if (!mounted) return;
    setState(() {
      _appVersion = "APP VERSION: $version (BUILD $buildNumber)";
    });
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
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final service = CoachClientsService.instance;

              if (_isRefreshing && service.clients.isEmpty) {
                return const Center(child: CoachLoadingIndicator());
              }
              if (service.loadError != null && service.clients.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Failed to load clients.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _isRefreshing ? null : () => _retryLoadClients(),
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(_isRefreshing ? 'Retrying…' : 'Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final clients = _filterClients(service.clients);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
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
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: clients.isEmpty
                              ? const ListEmptyState(
                                  message:
                                      'No clients found yet. Once clients are added, they’ll appear here.',
                                )
                              : RefreshIndicator(
                                  onRefresh: _refreshClientsAndUnread,
                                  child: ListView.separated(
                                    itemCount: clients.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final client = clients[index];
                                      final unreadCount =
                                          _unreadByClientId[client.clientId] ??
                                              0;
                                      final joinedLabel = DateFormat('MMM yyyy')
                                          .format(client.createdAt.toLocal());
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () async {
                                          showCoachLoadingOverlay(context);
                                          try {
                                            await routineController
                                                .loadClientData(
                                              clientId: client.clientId,
                                              clientName:
                                                  client.clientName ?? '',
                                            );
                                            await nutritionController
                                                .loadClientData(
                                              clientId: client.clientId,
                                            );
                                          } finally {
                                            if (mounted && context.mounted) {
                                              hideCoachLoadingOverlay(context);
                                            }
                                          }
                                          if (!mounted || !context.mounted) {
                                            return;
                                          }
                                          if (widget
                                              .navigateToOverviewOnSelect) {
                                            context.go('/');
                                          } else {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.06),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
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
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Text(
                                                  client.initials,
                                                  style: theme
                                                      .textTheme.titleSmall
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
                                                      client.clientName ?? '',
                                                      style: theme
                                                          .textTheme.titleMedium
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Client since $joinedLabel',
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.6),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (unreadCount > 0) ...[
                                                    UnreadBadge(
                                                      count: unreadCount,
                                                      fontSize: 11,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
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
                        const SizedBox(height: 12),
                        Text(
                          _appVersion,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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
