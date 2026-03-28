import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/screens/home.dart';
import 'package:trainware/services/app_bottom_sheet_visibility.dart';
import 'package:trainware/services/chat_unread_counts_service.dart';
import 'package:trainware/services/chat_unread_service.dart';
import 'package:trainware/screens/logs/coach_feedback_feed_screen.dart';
import 'package:trainware/screens/preferences/account_settings_screen.dart';
import 'package:trainware/utils/app_privileges.dart';
import 'package:trainware/utils/shell_tab_paths.dart';
import 'package:trainware/utils/coach_mapping_utils.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/widgets/badges/unread_badge.dart';
import 'package:trainware/widgets/navigation/app_floating_navigation_bar.dart';

/// Wraps primary tab routes with a floating custom nav (frosted pill). Chat,
/// routine plan, and coach feedback open as pushed screens with a close control.
class MainShellScaffold extends StatefulWidget {
  final Widget child;

  const MainShellScaffold({super.key, required this.child});

  @override
  State<MainShellScaffold> createState() => _MainShellScaffoldState();
}

class _MainShellScaffoldState extends State<MainShellScaffold>
    with WidgetsBindingObserver {
  int _navIndex = 0;
  int _chatUnreadCount = 0;
  ClientOverrideController? _accessController;

  bool get _chatInNavBar => AppConfig.isCoach || AppPrivileges.isProWithCoach;

  /// Pro client with coach: full feedback feed in nav (matches settings card).
  bool get _feedbackInNavBar => AppPrivileges.isProWithCoach;

  int get _settingsNavIndex {
    if (AppConfig.isCoach) return 4;
    if (_feedbackInNavBar) return 4;
    return 2;
  }

  /// Bottom-nav index of the Chat tab (varies by flavor / item count).
  int get _chatNavIndex {
    if (AppConfig.isCoach) return 3;
    return 2;
  }

  /// Coach clients picker is full-screen; no bottom nav on `/coach`.
  /// Client workout template detail (`/routine_template/...`) is a drill-down from
  /// Routines; hide nav there so it matches a stacked detail screen.
  bool _showFloatingNavBar(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (AppConfig.isCoach && path == '/coach') return false;
    if (isShellRoutineTemplatePath(path)) return false;
    return true;
  }

  /// [AppBottomSheetVisibility] is updated by [showAppBottomSheet] / [showAppActionBottomSheet].
  bool _shouldShowFloatingNavBar(BuildContext context, int openSheetCount) {
    if (openSheetCount > 0) return false;
    return _showFloatingNavBar(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accessController = context.read<ClientOverrideController>();
    _attachChatListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _bootstrapChatContext();
    });
  }

  void _attachChatListeners() {
    if (AppConfig.isCoach) {
      _chatUnreadCount = 0;
      ChatUnreadCountsService().totalUnreadCount.addListener(
        _handleChatUnreadChange,
      );
      ChatUnreadCountsService().unreadByClientId.addListener(
        _handleChatUnreadChange,
      );
      _accessController!.addListener(_handleChatUnreadChange);
    } else {
      _chatUnreadCount = ChatUnreadService().unreadCount.value;
      ChatUnreadService().unreadCount.addListener(_handleChatUnreadChange);
    }
  }

  Future<void> _bootstrapChatContext() async {
    if (!mounted) return;
    final accessController = context.read<ClientOverrideController>();
    if (AppConfig.isCoach) {
      ChatUnreadCountsService().refreshTotalUnreadCount();
      _handleChatUnreadChange();
      final clientId = accessController.selectedClientId;
      if (clientId != null) {
        ChatUnreadCountsService().refreshUnreadCountForClient(clientId);
      }
    } else {
      final userId = accessController.userId;
      if (userId == null) return;
      final coachData = await fetchCoachForClient(userId);
      if (coachData == null || !mounted) return;
      final coachId = coachData['coachId'];
      final coachName = coachData['coachName'];
      if (coachId == null) return;
      accessController.setCoachData(
        coachId: coachId,
        coachName: coachName ?? '',
      );
      await ChatUnreadService().updateContext(
        userId: accessController.userId,
        coachId: coachId,
        userIdOverride: accessController.selectedClientId,
      );
      _handleChatUnreadChange();
    }
  }

  void _handleChatUnreadChange() {
    if (!mounted) return;
    final accessController = _accessController;
    setState(() {
      if (AppConfig.isCoach) {
        if (accessController == null) return;
        final clientId = accessController.selectedClientId;
        _chatUnreadCount =
            clientId == null
                ? 0
                : (ChatUnreadCountsService().unreadByClientId.value[clientId] ??
                    0);
      } else {
        _chatUnreadCount = ChatUnreadService().unreadCount.value;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (AppConfig.isCoach) {
      ChatUnreadCountsService().totalUnreadCount.removeListener(
        _handleChatUnreadChange,
      );
      ChatUnreadCountsService().unreadByClientId.removeListener(
        _handleChatUnreadChange,
      );
      _accessController?.removeListener(_handleChatUnreadChange);
    } else {
      ChatUnreadService().unreadCount.removeListener(_handleChatUnreadChange);
    }
    _accessController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (AppConfig.isCoach) {
          ChatUnreadCountsService().refreshTotalUnreadCount();
        } else {
          ChatUnreadService().refreshSubscription();
          ChatUnreadService().refreshUnreadCount();
        }
      });
    }
  }

  void _syncNavIndexFromRoute() {
    final path = GoRouterState.of(context).uri.path;
    int next = _navIndex;

    if (path == '/' || path == Home.routeName) {
      next = 0;
    } else if (AppConfig.isCoach && path == '/coach') {
      next = 1;
    } else if (!AppConfig.isCoach && path == kShellRoutinesPath) {
      next = 1;
    } else if (!AppConfig.isCoach && isShellRoutineTemplatePath(path)) {
      next = 1;
    } else if (AppConfig.isCoach && path == kShellRoutinesPath) {
      next = 2;
    } else if (AppConfig.isCoach && isShellRoutineTemplatePath(path)) {
      next = 2;
    } else if (!AppConfig.isCoach &&
        _feedbackInNavBar &&
        path == CoachFeedbackFeedScreen.routeName) {
      next = 3;
    } else if (path == AccountSettingsScreen.routeName) {
      next = _settingsNavIndex;
    } else {
      return;
    }

    if (next != _navIndex) {
      setState(() => _navIndex = next);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNavIndexFromRoute();
  }

  @override
  void didUpdateWidget(covariant MainShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncNavIndexFromRoute();
      });
    }
  }

  Future<void> _openChatOverlay() async {
    setState(() => _navIndex = _chatNavIndex);
    await navigateToChat(context: context);
    if (mounted) _syncNavIndexFromRoute();
  }

  void _onDestinationSelected(int index) {
    final router = GoRouter.of(context);
    final settingsIdx = _settingsNavIndex;

    if (index == settingsIdx) {
      setState(() => _navIndex = settingsIdx);
      router.go(AccountSettingsScreen.routeName);
      return;
    }

    if (AppConfig.isCoach) {
      switch (index) {
        case 0:
          router.go('/');
          break;
        case 1:
          router.go('/coach');
          break;
        case 2:
          navigateToPrimaryRoutinePlan(context: context);
          break;
        case 3:
          _openChatOverlay();
          break;
      }
      if (index == 0 || index == 1 || index == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncNavIndexFromRoute();
        });
      }
      return;
    }

    // Client app
    if (_feedbackInNavBar) {
      switch (index) {
        case 0:
          router.go('/');
          break;
        case 1:
          navigateToPrimaryRoutinePlan(context: context);
          break;
        case 2:
          _openChatOverlay();
          break;
        case 3:
          navigateToCoachFeedbackFeed(context: context);
          break;
      }
      if (index == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncNavIndexFromRoute();
        });
      }
      return;
    }

    // Solo / self-coaching client: home, routines, settings
    switch (index) {
      case 0:
        router.go('/');
        break;
      case 1:
        navigateToPrimaryRoutinePlan(context: context);
        break;
    }
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncNavIndexFromRoute();
      });
    }
  }

  List<AppFloatingNavItem> _buildNavItems() {
    final items = <AppFloatingNavItem>[
      AppFloatingNavItem(
        label: 'Home',
        icon: const Icon(Icons.home_outlined, size: 24),
        selectedIcon: const Icon(Icons.home, size: 24),
      ),
      AppFloatingNavItem(
        label: AppConfig.isCoach ? 'Clients' : 'Routines',
        icon:
            AppConfig.isCoach
                ? const Icon(Icons.people_outline, size: 24)
                : const _NavDumbbellsAssetIcon(),
        selectedIcon:
            AppConfig.isCoach
                ? const Icon(Icons.people, size: 24)
                : const _NavDumbbellsAssetIcon(),
      ),
      if (AppConfig.isCoach)
        AppFloatingNavItem(
          label: 'Routines',
          icon: const _NavDumbbellsAssetIcon(),
          selectedIcon: const _NavDumbbellsAssetIcon(),
        ),
    ];

    if (_chatInNavBar) {
      items.add(
        AppFloatingNavItem(
          label: 'Chat',
          icon: _BadgedChatBubbleIcon(unreadCount: _chatUnreadCount),
          selectedIcon: _BadgedChatBubbleIcon(unreadCount: _chatUnreadCount),
        ),
      );
    }

    if (_feedbackInNavBar) {
      items.add(
        AppFloatingNavItem(
          label: 'Coach feedback',
          icon: const Icon(Icons.rate_review_outlined, size: 24),
          selectedIcon: const Icon(Icons.rate_review, size: 24),
        ),
      );
    }

    items.add(
      AppFloatingNavItem(
        label: 'Settings',
        icon: const Icon(Icons.person_outline, size: 24),
        selectedIcon: const Icon(Icons.person, size: 24),
      ),
    );

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _buildNavItems();
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          ValueListenableBuilder<int>(
            valueListenable: AppBottomSheetVisibility.instance.openCount,
            builder: (context, openSheetCount, _) {
              if (!_shouldShowFloatingNavBar(context, openSheetCount)) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 16,
                right: 16,
                bottom: bottomSafe + 10,
                child: AppFloatingNavigationBar(
                  currentIndex: _navIndex,
                  onDestinationSelected: _onDestinationSelected,
                  items: navItems,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Routines tab (client): `icons/dumbbells.png`, tinted to match nav [Icon]s.
class _NavDumbbellsAssetIcon extends StatelessWidget {
  const _NavDumbbellsAssetIcon();

  static const String _assetPath = 'icons/dumbbells.png';

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 24,
      height: 24,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _BadgedChatBubbleIcon extends StatelessWidget {
  final int unreadCount;

  const _BadgedChatBubbleIcon({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(2),
          child: FaIcon(FontAwesomeIcons.comment, size: 22, color: color),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: UnreadBadge(count: unreadCount),
          ),
      ],
    );
  }
}
