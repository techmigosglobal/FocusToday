import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/ux_telemetry_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/premium_public_ui.dart';
import '../../../../shared/widgets/slice_surface.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../feed/data/repositories/post_repository.dart';
import '../../../feed/presentation/screens/post_detail_screen.dart';
import '../../../meetings/presentation/screens/meetings_list_screen.dart';
import '../../../moderation/presentation/screens/moderation_screen.dart';
import '../../data/repositories/notification_repository.dart';
import '../../../../main.dart';

/// Notifications Screen — loads real notifications from backend.
class NotificationsScreen extends StatefulWidget {
  final User currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationRepository _notifRepo = NotificationRepository();
  final UxTelemetryService _telemetry = UxTelemetryService.instance;
  final PostRepository _postRepo = PostRepository();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _isMarkAllInFlight = false;
  final Set<String> _busyNotificationIds = <String>{};
  AppLanguage _currentLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;

  late final TabController _tabController;

  // Tab index -> set of notification type strings that belong to this tab.
  // null means "show all".
  static const _tabTypeGroups = <int, Set<String>?>{
    0: null, // All
    1: {'breaking_news'}, // Alerts
    2: {
      'post_approved',
      'post_rejected',
      'new_post_pending',
      'post_resubmitted',
      'reporter_application_approved',
      'reporter_application_rejected',
    }, // Approvals
    3: {
      'system',
      'info',
      'like',
      'comment',
      'new_comment',
      'follower',
      'new_content',
      'meeting_created',
      'meeting_interest',
      'meeting_not_interested',
      'meeting_reminder',
      'role_changed',
      'post_published_digest',
      'post_published',
    }, // Activity
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
      _loadLanguage();
    });
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final service =
        FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= service;
    _languageService = service;
    if (!_isLanguageListenerAttached) {
      service.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (mounted) setState(() => _currentLanguage = service.currentLanguage);
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _currentLanguage) return;
    setState(() => _currentLanguage = nextLanguage);
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notifRepo.getNotifications(
        widget.currentUser.id,
      );
      if (mounted) {
        setState(() {
          _notifications = List<AppNotification>.of(notifications);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Returns notifications filtered to the current tab.
  List<AppNotification> get _visibleNotifications {
    final types = _tabTypeGroups[_tabController.index];
    if (types == null) return _notifications;
    return _notifications.where((n) => types.contains(n.type)).toList();
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkAllInFlight) return;
    HapticFeedback.selectionClick();
    final unreadIds = _notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toSet();
    if (unreadIds.isEmpty) return;
    setState(() {
      _isMarkAllInFlight = true;
      _notifications = _notifications
          .map(
            (n) => unreadIds.contains(n.id)
                ? AppNotification(
                    id: n.id,
                    userId: n.userId,
                    title: n.title,
                    body: n.body,
                    type: n.type,
                    isRead: true,
                    actionData: n.actionData,
                    createdAt: n.createdAt,
                  )
                : n,
          )
          .toList(growable: true);
    });
    unawaited(
      _telemetry.track(
        eventName: 'notifications_mark_all_read',
        eventGroup: 'header',
        screen: 'notifications',
        user: widget.currentUser,
      ),
    );
    try {
      await _notifRepo.markAllAsRead(widget.currentUser.id);
      if (!mounted) return;
      unawaited(_loadNotifications());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations(_currentLanguage).markAllRead),
          duration: const Duration(seconds: 1),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkAllInFlight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final localizations = AppLocalizations(_currentLanguage);
    final visibleNotifications = _visibleNotifications;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SliceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: FeatureFlags.publicPremiumRedesign
                    ? HeroHeader(
                        title: localizations.notifications,
                        subtitle: unreadCount > 0
                            ? '$unreadCount unread priority updates'
                            : 'You are fully caught up',
                        icon: Icons.notifications_active_rounded,
                        actions: [
                          if (unreadCount > 0)
                            TextButton(
                              onPressed: _isMarkAllInFlight
                                  ? null
                                  : _markAllAsRead,
                              child: _isMarkAllInFlight
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.onPrimaryOf(context),
                                      ),
                                    )
                                  : Text(
                                      localizations.markAllRead,
                                      style: TextStyle(
                                        color: AppColors.onPrimaryOf(context),
                                      ),
                                    ),
                            ),
                        ],
                      )
                    : SliceCard(
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.notifications,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    unreadCount > 0
                                        ? '$unreadCount unread updates'
                                        : 'All caught up',
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (unreadCount > 0)
                              TextButton(
                                onPressed: _isMarkAllInFlight
                                    ? null
                                    : _markAllAsRead,
                                child: Text(localizations.markAllRead),
                              ),
                          ],
                        ),
                      ),
              ),
              // GAP-009: category tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    final label = const [
                      'all',
                      'alerts',
                      'approvals',
                      'activity',
                    ][index];
                    unawaited(
                      _telemetry.trackDiscoveryTap(
                        user: widget.currentUser,
                        screen: 'notifications',
                        railLabel: 'tab_$label',
                        selected: true,
                      ),
                    );
                    setState(() {});
                  },
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: AppColors.dividerOf(
                    context,
                  ).withValues(alpha: 0),
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondaryOf(context),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Alerts'),
                    Tab(text: 'Approvals'),
                    Tab(text: 'Activity'),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : visibleNotifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                          itemCount: visibleNotifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationTile(
                              visibleNotifications[index],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notification) {
    final isBusy = _busyNotificationIds.contains(notification.id);
    return Dismissible(
      key: Key(notification.id),
      confirmDismiss: (_) async => !isBusy,
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.destructiveFgOf(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: AppColors.onPrimaryOf(context),
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        _notifRepo.deleteNotification(notification.id);
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: SliceCard(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        onTap: isBusy
            ? null
            : () {
                HapticFeedback.lightImpact();
                if (!notification.isRead) {
                  unawaited(_notifRepo.markAsRead(notification.id));
                  setState(() {
                    final index = _notifications.indexWhere(
                      (n) => n.id == notification.id,
                    );
                    if (index != -1) {
                      _notifications[index] = AppNotification(
                        id: notification.id,
                        userId: notification.userId,
                        title: notification.title,
                        body: notification.body,
                        type: notification.type,
                        isRead: true,
                        actionData: notification.actionData,
                        createdAt: notification.createdAt,
                      );
                    }
                  });
                }
                _handleNotificationTap(notification);
              },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationIcon(notification.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.infoOf(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (isBusy) ...[
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getTimeAgo(notification.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    setState(() => _busyNotificationIds.add(notification.id));
    try {
      Map<String, dynamic>? data;

      if (notification.actionData != null &&
          notification.actionData!.isNotEmpty) {
        try {
          data = Map<String, dynamic>.from(
            json.decode(notification.actionData!),
          );
        } catch (_) {}
      }

      final type = notification.type;

      if (data != null && data['post_id'] != null) {
        final isAdminType =
            widget.currentUser.role == UserRole.superAdmin ||
            widget.currentUser.role == UserRole.admin;
        final isPendingType =
            type == 'new_post_pending' || type == 'post_resubmitted';

        if (isAdminType && isPendingType) {
          unawaited(
            _telemetry.trackNavigation(
              user: widget.currentUser,
              screen: 'notifications',
              destination: 'moderation',
              metadata: {'notification_type': type},
            ),
          );
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => ModerationScreen(currentUser: widget.currentUser),
            ),
          );
          return;
        }

        final opened = await _openPostById(
          data['post_id'].toString(),
          notificationType: type,
        );
        if (opened) return;
      }

      if (type == 'meeting_created' ||
          type == 'meeting_interest' ||
          type == 'meeting_reminder') {
        if (!mounted) return;
        unawaited(
          _telemetry.trackNavigation(
            user: widget.currentUser,
            screen: 'notifications',
            destination: 'meetings',
            metadata: {'notification_type': type},
          ),
        );
        Navigator.push(
          context,
          SmoothPageRoute(
            builder: (_) => MeetingsListScreen(currentUser: widget.currentUser),
          ),
        );
        return;
      }

      if (type == 'breaking_news') {
        final newsId = (data?['news_id'] ?? '').toString().trim();
        if (newsId.isNotEmpty) {
          try {
            final newsDoc = await FirestoreService.breakingNews
                .doc(newsId)
                .get();
            final linkedPostId = newsDoc.data()?['post_id']?.toString();
            if (linkedPostId != null && linkedPostId.isNotEmpty) {
              final opened = await _openPostById(
                linkedPostId,
                notificationType: type,
              );
              if (opened) return;
            }
          } catch (e) {
            debugPrint(
              '[Notifications] Failed to resolve breaking news route: $e',
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busyNotificationIds.remove(notification.id));
      }
    }
  }

  Future<bool> _openPostById(
    String postId, {
    required String notificationType,
  }) async {
    try {
      final post = await _postRepo.getPostById(postId);
      if (post == null || !mounted) return false;
      unawaited(
        _telemetry.trackNavigation(
          user: widget.currentUser,
          screen: 'notifications',
          destination: 'post_detail',
          metadata: {'post_id': postId, 'notification_type': notificationType},
        ),
      );
      Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) => PostDetailScreen(
            post: post,
            currentUser: widget.currentUser,
            currentLanguage: _currentLanguage,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[Notifications] Failed to open post $postId: $e');
      return false;
    }
  }

  Widget _buildNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'post_approved':
        icon = Icons.check_circle;
        color = AppColors.secondary;
        break;
      case 'post_rejected':
        icon = Icons.cancel;
        color = AppColors.destructiveFgOf(context);
        break;
      case 'new_content':
      case 'post_published':
      case 'post_published_digest':
        icon = Icons.fiber_new;
        color = AppColors.primary;
        break;
      case 'breaking_news':
        icon = Icons.bolt_rounded;
        color = AppColors.errorOf(context);
        break;
      case 'meeting_created':
      case 'meeting_interest':
      case 'meeting_not_interested':
      case 'meeting_reminder':
        icon = Icons.event_rounded;
        color = AppColors.infoOf(context);
        break;
      case 'emergency_alert':
        icon = Icons.warning_amber_rounded;
        color = AppColors.warningOf(context);
        break;
      case 'like':
        icon = Icons.favorite;
        color = AppColors.likeStrong;
        break;
      case 'new_comment':
      case 'comment':
        icon = Icons.comment;
        color = AppColors.secondary;
        break;
      case 'follower':
        icon = Icons.person_add;
        color = AppColors.primary;
        break;
      default:
        icon = Icons.info;
        color = AppColors.accent;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SliceCard(
        margin: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${difference.inDays ~/ 7}w ago';
  }
}
