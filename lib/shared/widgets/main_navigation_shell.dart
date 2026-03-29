import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/language_service.dart';
import '../../shared/models/user.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/all_posts_screen.dart';
import '../../features/meetings/presentation/screens/meetings_list_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/user_sync_service.dart';
import '../../features/profile/data/repositories/profile_repository.dart';

/// Main Navigation Shell
///
/// Provides consistent bottom navigation across the app.
/// Role-based tabs ensure critical features are always 1 tap away:
/// - All roles: Feed, Discover, Settings
/// - Admin/SuperAdmin/Reporter: + All Posts queue
class MainNavigationShell extends StatefulWidget {
  final User currentUser;
  final int initialIndex;
  final bool showProfilePrompt;

  const MainNavigationShell({
    super.key,
    required this.currentUser,
    this.initialIndex = 0,
    this.showProfilePrompt = false,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late final PageController _pageController;
  final ProfileRepository _profileRepository = ProfileRepository();
  StreamSubscription<UserSyncEvent>? _userSyncSubscription;
  late User _currentUser;
  int _currentIndex = 0;
  DateTime? _lastQuitTime;
  final List<int> _tabBackStack = [];
  bool _suppressHistoryOnce = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    final safeInitialIndex = widget.initialIndex
        .clamp(0, _buildScreens(_currentUser).length - 1)
        .toInt();
    _pageController = PageController(initialPage: safeInitialIndex);
    _currentIndex = safeInitialIndex;
    _syncForegroundSurface();
    _listenToUserSync();
  }

  @override
  void dispose() {
    NotificationService.instance.setForegroundSurface(
      AppForegroundSurface.other,
    );
    _userSyncSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id) {
      _currentUser = widget.currentUser;
      final maxIndex = _buildScreens(_currentUser).length - 1;
      if (_currentIndex > maxIndex) {
        _currentIndex = maxIndex;
      }
    }
  }

  List<Widget> _buildScreens(User activeUser) {
    final hasEventsTab =
        activeUser.role == UserRole.publicUser ||
        activeUser.role == UserRole.reporter ||
        activeUser.role == UserRole.admin ||
        activeUser.role == UserRole.superAdmin;

    return [
      FeedScreen(
        currentUser: activeUser,
        showProfilePrompt: widget.showProfilePrompt,
      ),
      SearchScreen(currentUser: activeUser),
      if (hasEventsTab) MeetingsListScreen(currentUser: activeUser),
      if (activeUser.canModerate) AllPostsScreen(currentUser: activeUser),
      SettingsScreen(currentUser: activeUser),
    ];
  }

  List<_NavItem> _buildNavItems(User activeUser) {
    final l = AppLocalizations(
      AppLanguage.fromCode(activeUser.preferredLanguage),
    );
    final hasEventsTab =
        activeUser.role == UserRole.publicUser ||
        activeUser.role == UserRole.reporter ||
        activeUser.role == UserRole.admin ||
        activeUser.role == UserRole.superAdmin;

    return [
      _NavItem(icon: Icons.home_rounded, label: 'Feed'),
      _NavItem(icon: Icons.explore_rounded, label: 'Discover'),
      if (hasEventsTab)
        _NavItem(icon: Icons.event_rounded, label: l.upcomingEvents),
      if (activeUser.canModerate)
        _NavItem(icon: Icons.dashboard_rounded, label: 'Queue'),
      _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
    ];
  }

  void _listenToUserSync() {
    _userSyncSubscription = UserSyncService.stream.listen((event) {
      if (!mounted) return;
      if (event.userId != null && event.userId != _currentUser.id) return;
      _refreshCurrentUser();
    });
  }

  Future<void> _refreshCurrentUser() async {
    final latest = await _profileRepository.getUserById(_currentUser.id);
    if (!mounted || latest == null) return;
    setState(() {
      _currentUser = latest;
      final maxIndex = _buildScreens(_currentUser).length - 1;
      if (_currentIndex > maxIndex) {
        _currentIndex = maxIndex;
      }
    });
  }

  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    _navigateToTab(index);
  }

  void _navigateToTab(int index, {bool recordHistory = true}) {
    if (_currentIndex == index) return;
    if (recordHistory) {
      _tabBackStack.add(_currentIndex);
    }
    _suppressHistoryOnce = true;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _syncForegroundSurface() {
    NotificationService.instance.setForegroundSurface(
      _currentIndex == 0
          ? AppForegroundSurface.feed
          : AppForegroundSurface.other,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens(_currentUser);
    final navItems = _buildNavItems(_currentUser);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (_currentIndex != 0) {
          if (_tabBackStack.isNotEmpty) {
            final previousIndex = _tabBackStack.removeLast();
            _navigateToTab(previousIndex, recordHistory: false);
          } else {
            _navigateToTab(_currentIndex - 1, recordHistory: false);
          }
          return;
        }

        final now = DateTime.now();
        if (_lastQuitTime == null ||
            now.difference(_lastQuitTime!) > const Duration(seconds: 2)) {
          _lastQuitTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          onPageChanged: (index) {
            if (_suppressHistoryOnce) {
              _suppressHistoryOnce = false;
            } else if (index != _currentIndex) {
              _tabBackStack.add(_currentIndex);
            }
            setState(() => _currentIndex = index);
            _syncForegroundSurface();
          },
          children: screens,
        ),
        extendBody: true,
        bottomNavigationBar: _buildBottomNav(navItems),
      ),
    );
  }

  Widget _buildBottomNav(List<_NavItem> navItems) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.dividerOf(context).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  return _buildNavItem(item, index);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index) {
    final isActive = _currentIndex == index;
    final color = isActive
        ? AppColors.primaryOf(context)
        : AppColors.iconMutedOf(context);

    return InkWell(
      onTap: () => _onNavTap(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryOf(context).withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 21, color: color),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isActive ? 10 : 4,
              height: 2.5,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryOf(context)
                    : AppColors.textSecondaryOf(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  _NavItem({required this.icon, required this.label});
}
