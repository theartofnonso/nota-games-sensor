import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/coach_client_dto.dart';
import 'package:trainware/services/chat_bootstrap_service.dart';
import 'package:trainware/services/chat_unread_counts_service.dart';
import 'package:trainware/services/coach_clients_service.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/widgets/navigation/app_floating_navigation_bar.dart';
import 'package:trainware/widgets/search_bar.dart';
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
    CoachClientsService.instance.addListener(_onCoachClientsServiceChanged);
    _refreshUnreadWhenAgoraReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<ClientOverrideController>().userId;
      unawaited(
        CoachClientsService.instance.loadClients(coachAuthUserId: uid),
      );
    });
  }

  void _onCoachClientsServiceChanged() {
    if (mounted) setState(() {});
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
    CoachClientsService.instance.removeListener(_onCoachClientsServiceChanged);
    ChatUnreadCountsService().unreadByClientId.removeListener(
      _handleUnreadChange,
    );
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
      final uid = context.read<ClientOverrideController>().userId;
      await CoachClientsService.instance.loadClients(coachAuthUserId: uid);
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

  Future<void> _openClientExperience({
    required BuildContext itemContext,
    required CoachClientDto client,
    required SupabaseExerciseAndRoutineController routineController,
    required NutritionLogController nutritionController,
  }) async {
    showCoachLoadingOverlay(itemContext);
    try {
      await routineController.loadClientData(
        clientId: client.clientId,
        clientName: client.clientName ?? '',
      );
      await nutritionController.loadClientData(clientId: client.clientId);
    } finally {
      if (itemContext.mounted) {
        hideCoachLoadingOverlay(itemContext);
      }
    }
    if (!mounted || !context.mounted) return;
    if (widget.navigateToOverviewOnSelect) {
      context.go('/');
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _retryLoadClients() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) setState(() {});
    try {
      final uid = context.read<ClientOverrideController>().userId;
      await CoachClientsService.instance.loadClients(coachAuthUserId: uid);
      if (mounted) setState(() {});
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final routineController =
        context.read<SupabaseExerciseAndRoutineController>();
    final nutritionController = context.read<NutritionLogController>();

    final navBarBottomInset =
        MediaQuery.paddingOf(context).bottom + kAppFloatingNavBarReserveHeight;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: themeGradient(context: context)),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Padding(
            padding: EdgeInsets.only(bottom: navBarBottomInset),
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
                          onPressed:
                              _isRefreshing ? null : () => _retryLoadClients(),
                          icon:
                              _isRefreshing
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
              final subscribed =
                  clients.where((c) => c.subscriptionActive).toList();
              final notSubscribed =
                  clients.where((c) => !c.subscriptionActive).toList();
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
                          child:
                              clients.isEmpty
                                  ? _CoachClientsEmptyState(
                                    isSearchEmpty:
                                        _searchQuery.isNotEmpty &&
                                        service.clients.isNotEmpty,
                                  )
                                  : RefreshIndicator(
                                    onRefresh: _refreshClientsAndUnread,
                                    child: ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      children: [
                                        if (subscribed.isNotEmpty &&
                                            notSubscribed.isNotEmpty)
                                          _CoachClientsSectionHeader(
                                            title: 'Subscribed',
                                          ),
                                        ...subscribed.map(
                                          (client) => _CoachClientTile(
                                            client: client,
                                            theme: theme,
                                            isDarkMode: isDarkMode,
                                            unreadCount:
                                                _unreadByClientId[client
                                                    .clientId] ??
                                                0,
                                            onTap: () {
                                              unawaited(
                                                _openClientExperience(
                                                  itemContext: context,
                                                  client: client,
                                                  routineController:
                                                      routineController,
                                                  nutritionController:
                                                      nutritionController,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        if (notSubscribed.isNotEmpty) ...[
                                          if (subscribed.isNotEmpty)
                                            const SizedBox(height: 20),
                                          _CoachClientsSectionHeader(
                                            title: 'Inactive subscription',
                                            subtitle:
                                                'Their program isn’t available until they have an active subscription.',
                                          ),
                                          ...notSubscribed.map(
                                            (client) => _CoachClientTile(
                                              client: client,
                                              theme: theme,
                                              isDarkMode: isDarkMode,
                                              unreadCount:
                                                  _unreadByClientId[client
                                                      .clientId] ??
                                                  0,
                                              onTap: null,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
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
      ),
    );
  }
}

class _CoachClientsSectionHeader extends StatelessWidget {
  const _CoachClientsSectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = Colors.white.withValues(alpha: 0.65);
    return Padding(
      padding: EdgeInsets.only(bottom: subtitle != null ? 10 : 8, top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachClientTile extends StatelessWidget {
  const _CoachClientTile({
    required this.client,
    required this.theme,
    required this.isDarkMode,
    required this.unreadCount,
    this.onTap,
  });

  final CoachClientDto client;
  final ThemeData theme;
  final bool isDarkMode;
  final int unreadCount;
  final VoidCallback? onTap;

  bool get _enabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final joinedLabel = DateFormat(
      'MMM yyyy',
    ).format(client.createdAt.toLocal());
    final showUnread = unreadCount > 0 && _enabled;

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  client.initials,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.clientName ?? '',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Client since $joinedLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showUnread) ...[
                    UnreadBadge(
                      count: unreadCount,
                      fontSize: 11,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(
                      alpha: _enabled ? 0.7 : 0.35,
                    ),
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: _enabled ? 1.0 : 0.48,
        child: card,
      ),
    );
  }
}

/// Circle icon + title + body (matches coach feedback feed & nutrition log empty states).
class _CoachClientsEmptyState extends StatelessWidget {
  const _CoachClientsEmptyState({required this.isSearchEmpty});

  final bool isSearchEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);

    final title =
        isSearchEmpty ? 'No matching clients' : 'No clients yet';
    final body =
        isSearchEmpty
            ? 'Try a different name in the search box.'
            : 'Once clients join and are linked to you, they’ll appear here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.05,
                ),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.users,
                size: 48,
                color: muted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
