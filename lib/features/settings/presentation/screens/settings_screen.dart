import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/notification_preferences_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../main.dart';
import '../../../../shared/widgets/slice_surface.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../auth/presentation/screens/splash_screen.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../../../feed/presentation/screens/create_post_screen.dart';
import '../../../feed/presentation/screens/pending_posts_screen.dart';
import '../../../feed/presentation/screens/rejected_posts_screen.dart';
import '../../../feed/presentation/screens/all_posts_screen.dart';
import '../../../legal/presentation/screens/legal_screens.dart';
import '../../../departments/presentation/screens/departments_screen.dart';
import '../../../moderation/presentation/screens/analytics_screen.dart';
import '../../../moderation/presentation/screens/storage_limits_screen.dart';
import '../../../moderation/presentation/screens/user_management_screen.dart';
import '../../../meetings/presentation/screens/meetings_management_screen.dart';
import '../../../enrollment/presentation/screens/reporter_application_screen.dart';

/// Modern Settings Screen
/// Beautiful settings UI with profile card, toggles, and grouped sections
class SettingsScreen extends StatefulWidget {
  final User currentUser;

  const SettingsScreen({super.key, required this.currentUser});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _notificationGroupingEnabled = true;
  bool _quietHoursEnabled = false;
  bool _darkModeEnabled = false;
  bool _autoPlayVideos = true;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  AppLanguage _selectedLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  User? _displayUser;

  Color _tileIconBg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.primaryOf(context).withValues(alpha: 0.28)
        : AppColors.primary.withValues(alpha: 0.1);
  }

  Color _tileIconFg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.onPrimaryOf(context) : AppColors.primary;
  }

  @override
  void initState() {
    super.initState();
    _displayUser = widget.currentUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final languageService =
        FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= languageService;
    final themeService = FocusTodayApp.themeService;
    final notificationPreferences = await NotificationService.instance
        .getPreferences();
    if (!_isLanguageListenerAttached) {
      languageService.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (!mounted) return;
    setState(() {
      _languageService = languageService;
      _selectedLanguage = languageService.currentLanguage;
      _darkModeEnabled = themeService?.isDarkMode ?? false;
      _notificationsEnabled = notificationPreferences.pushEnabled;
      _notificationGroupingEnabled = notificationPreferences.groupingEnabled;
      _quietHoursEnabled = notificationPreferences.quietHoursEnabled;
      _quietStart = TimeOfDay(
        hour: notificationPreferences.quietStartHour,
        minute: notificationPreferences.quietStartMinute,
      );
      _quietEnd = TimeOfDay(
        hour: notificationPreferences.quietEndHour,
        minute: notificationPreferences.quietEndMinute,
      );
    });
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    final languageService = _languageService;
    if (languageService == null) return;
    await languageService.setLanguage(language);
    HapticFeedback.selectionClick();
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _selectedLanguage) return;
    setState(() => _selectedLanguage = nextLanguage);
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations(_selectedLanguage).logoutTitle),
        content: Text(AppLocalizations(_selectedLanguage).logoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations(_selectedLanguage).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorOf(context),
              foregroundColor: AppColors.onPrimaryOf(context),
            ),
            child: Text(AppLocalizations(_selectedLanguage).logout),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authRepo = await AuthRepository.init();
      await authRepo.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _runPushSelfTest() async {
    try {
      await NotificationService.instance.onUserAuthenticated(
        widget.currentUser.id,
        widget.currentUser.role,
      );
      final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendTestFcmToSelf')
          .call({
            'title': 'Focus Today Push Test',
            'body': 'If you see this in notification bar, push is working.',
          });
      final data = Map<String, dynamic>.from(
        (result.data as Map?) ?? const <String, dynamic>{},
      );
      final targeted = data['targeted'] ?? 0;
      final success = data['success'] ?? 0;
      final failed = data['failed'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Push test sent. targeted: $targeted, success: $success, failed: $failed',
          ),
          backgroundColor: AppColors.successOf(context),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Push test failed (${e.code}): ${e.message ?? ''}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Push test failed: $e')));
    }
  }

  String _formatTime(TimeOfDay value) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(value, alwaysUse24HourFormat: false);
  }

  String _quietHoursLabel() {
    return '${_formatTime(_quietStart)} - ${_formatTime(_quietEnd)}';
  }

  Future<void> _pickQuietTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
    );
    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _quietStart = selected;
      } else {
        _quietEnd = selected;
      }
    });

    if (isStart) {
      await NotificationService.instance.setQuietHoursStart(
        TimeOfDayLite(hour: selected.hour, minute: selected.minute),
      );
    } else {
      await NotificationService.instance.setQuietHoursEnd(
        TimeOfDayLite(hour: selected.hour, minute: selected.minute),
      );
    }
  }

  Future<void> _showQuietHoursEditor() async {
    final l = AppLocalizations(_selectedLanguage);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.nightlight_round),
                title: Text(l.quietStart),
                subtitle: Text(_formatTime(_quietStart)),
                onTap: () {
                  Navigator.pop(context);
                  _pickQuietTime(isStart: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_rounded),
                title: Text(l.quietEnd),
                subtitle: Text(_formatTime(_quietEnd)),
                onTap: () {
                  Navigator.pop(context);
                  _pickQuietTime(isStart: false);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onPushNotificationsToggled(bool value) async {
    if (!mounted) return;

    if (!value) {
      setState(() => _notificationsEnabled = false);
      await NotificationService.instance.setPushEnabled(false);
      return;
    }

    final granted = await NotificationService.instance
        .requestSystemNotificationPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() => _notificationsEnabled = false);
      await NotificationService.instance.setPushEnabled(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'System notification permission is blocked. Enable it in app settings.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    setState(() => _notificationsEnabled = true);
    await NotificationService.instance.setPushEnabled(true);
  }

  Widget _buildRoleModulesSection() {
    final l = AppLocalizations(_selectedLanguage);
    if (widget.currentUser.canModerate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(l.adminWorkspace, Icons.admin_panel_settings),
          _buildSettingsCard([
            _buildNavTile(
              l.allPostsQueue,
              Icons.dashboard_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      AllPostsScreen(currentUser: widget.currentUser),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              l.userManagement,
              Icons.people_alt_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      UserManagementScreen(currentUser: widget.currentUser),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              l.analyticsDashboard,
              Icons.analytics_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) => AnalyticsScreen(
                    currentUser: widget.currentUser,
                    currentLanguage: _selectedLanguage,
                  ),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              l.storageLimits,
              Icons.storage_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      StorageLimitsScreen(currentUser: widget.currentUser),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              l.meetingsTitle,
              Icons.event_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) => MeetingsManagementScreen(
                    currentUser: widget.currentUser,
                    currentLanguage: _selectedLanguage,
                  ),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              'Test Push Notifications',
              Icons.notifications_active_rounded,
              _runPushSelfTest,
            ),
          ]),
        ],
      );
    }

    if (widget.currentUser.role == UserRole.reporter) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(l.reporterWorkspace, Icons.newspaper_rounded),
          _buildSettingsCard([
            _buildNavTile(
              l.createPost,
              Icons.add_circle_outline_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      CreatePostScreen(currentUser: widget.currentUser),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              l.pendingPosts,
              Icons.pending_actions_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      PendingPostsScreen(currentUser: widget.currentUser),
                ),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              l.rejectedPosts,
              Icons.assignment_return_outlined,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) =>
                      RejectedPostsScreen(currentUser: widget.currentUser),
                ),
              ),
            ),
          ]),
        ],
      );
    }

    if (widget.currentUser.role == UserRole.publicUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(l.publicUser, Icons.person_outline_rounded),
          _buildSettingsCard([
            _buildNavTile(
              l.applyAsReporter,
              Icons.app_registration_rounded,
              () => Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) => ReporterApplicationScreen(
                    currentUser: widget.currentUser,
                  ),
                ),
              ),
            ),
          ]),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(_selectedLanguage);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SliceBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 110,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  localizations.settings,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(26),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF173A67),
                        AppColors.primary,
                        const Color(0xFF2D5F8B),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(
                  AppDimensions.responsivePadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Card
                    _buildProfileCard(localizations),
                    const SizedBox(height: 24),

                    // Preferences Section
                    _buildSectionHeader(
                      localizations.preferences,
                      Icons.tune_rounded,
                    ),
                    _buildSettingsCard([
                      _buildLanguageSelector(localizations),
                      _buildDivider(),
                      _buildSwitchTile(
                        localizations.darkMode,
                        localizations.enableDarkTheme,
                        Icons.dark_mode_rounded,
                        _darkModeEnabled,
                        (value) {
                          setState(() => _darkModeEnabled = value);
                          FocusTodayApp.themeService?.setDarkMode(value);
                        },
                      ),
                      _buildDivider(),
                      _buildSwitchTile(
                        localizations.autoPlayVideos,
                        localizations.playVideosInFeed,
                        Icons.play_circle_rounded,
                        _autoPlayVideos,
                        (value) => setState(() => _autoPlayVideos = value),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Notifications Section
                    _buildSectionHeader(
                      localizations.notifications,
                      Icons.notifications_rounded,
                    ),
                    _buildSettingsCard([
                      _buildSwitchTile(
                        localizations.pushNotifications,
                        localizations.receiveUpdates,
                        Icons.notifications_active_rounded,
                        _notificationsEnabled,
                        _onPushNotificationsToggled,
                      ),
                      _buildDivider(),
                      _buildSwitchTile(
                        localizations.groupNotifications,
                        localizations.groupNotificationsHint,
                        Icons.view_list_rounded,
                        _notificationGroupingEnabled,
                        (value) {
                          setState(() => _notificationGroupingEnabled = value);
                          NotificationService.instance.setGroupingEnabled(
                            value,
                          );
                        },
                      ),
                      _buildDivider(),
                      _buildSwitchTile(
                        localizations.quietHours,
                        localizations.quietHoursHint,
                        Icons.bedtime_rounded,
                        _quietHoursEnabled,
                        (value) {
                          setState(() => _quietHoursEnabled = value);
                          NotificationService.instance.setQuietHoursEnabled(
                            value,
                          );
                        },
                      ),
                      if (_quietHoursEnabled) ...[
                        _buildDivider(),
                        _buildNavTile(
                          localizations.quietHoursSchedule,
                          Icons.schedule_rounded,
                          _showQuietHoursEditor,
                          trailing: Text(
                            _quietHoursLabel(),
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),

                    // Role-specific modules section (available for every role)
                    _buildRoleModulesSection(),
                    const SizedBox(height: 24),

                    _buildEmergencyContactsSection(localizations),
                    const SizedBox(height: 24),

                    // About Section
                    _buildSectionHeader(
                      localizations.about,
                      Icons.info_rounded,
                    ),
                    _buildSettingsCard([
                      _buildNavTile(
                        localizations.privacyPolicy,
                        Icons.privacy_tip_rounded,
                        () => Navigator.push(
                          context,
                          SmoothPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildNavTile(
                        localizations.termsOfService,
                        Icons.description_rounded,
                        () => Navigator.push(
                          context,
                          SmoothPageRoute(
                            builder: (_) => const TermsOfUseScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildNavTile(
                        localizations.disclaimer,
                        Icons.gavel_rounded,
                        () => Navigator.push(
                          context,
                          SmoothPageRoute(
                            builder: (_) => const DisclaimerScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildNavTile(
                        localizations.appVersion,
                        Icons.apps_rounded,
                        null,
                        trailing: Text(
                          'v1.0.0',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Logout Button
                    _buildLogoutButton(localizations),
                    const SizedBox(height: 16),
                    _buildTechMigosBranding(),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 96,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsSection(AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          localizations.emergencyContacts,
          Icons.contact_phone_rounded,
        ),
        _buildSettingsCard([
          _buildNavTile(
            localizations.emergencyContacts,
            Icons.contact_emergency_rounded,
            () => Navigator.push(
              context,
              SmoothPageRoute(builder: (_) => const DepartmentsScreen()),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildTechMigosBranding() {
    return Center(
      child: Text(
        AppLocalizations(_selectedLanguage).maintainedByTechMigos,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryOf(context).withValues(alpha: 0.82),
        ),
      ),
    );
  }

  Widget _buildProfileCard(AppLocalizations localizations) {
    final user = _displayUser ?? widget.currentUser;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: ClipOval(
                child:
                    user.profilePicture != null &&
                        user.profilePicture!.trim().isNotEmpty
                    ? Image.network(
                        user.profilePicture!.trim(),
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _buildSettingsAvatarFallback(user.displayName),
                      )
                    : _buildSettingsAvatarFallback(user.displayName),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.phoneNumber,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) => EditProfileScreen(
                    currentUser: _displayUser ?? widget.currentUser,
                    currentLanguage: _selectedLanguage,
                  ),
                ),
              );
              if (result == true && mounted) {
                // Refresh user data after profile update
                final authRepo = await AuthRepository.init();
                final updatedUser = await authRepo.restoreSession();
                if (updatedUser != null && mounted) {
                  setState(() {
                    _displayUser = updatedUser;
                  });
                }
              }
            },
            icon: Icon(Icons.edit_rounded, color: _tileIconFg()),
            style: IconButton.styleFrom(backgroundColor: _tileIconBg()),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsAvatarFallback(String displayName) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.secondary : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return SliceCard(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _buildLanguageSelector(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _tileIconBg(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.language_rounded, color: _tileIconFg(), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.languageLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  localizations.selectLanguage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildLanguageChip('EN', AppLanguage.english),
                _buildLanguageChip('తె', AppLanguage.telugu),
                _buildLanguageChip('हि', AppLanguage.hindi),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label, AppLanguage language) {
    final isSelected = _selectedLanguage == language;
    return GestureDetector(
      onTap: () => _changeLanguage(language),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _tileIconBg(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _tileIconFg(), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (newValue) {
              HapticFeedback.selectionClick();
              onChanged(newValue);
            },
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(
    String title,
    IconData icon,
    VoidCallback? onTap, {
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _tileIconBg(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _tileIconFg(), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondaryOf(context),
                  size: 16,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 68, color: AppColors.dividerOf(context));
  }

  Widget _buildLogoutButton(AppLocalizations localizations) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded),
        label: Text(localizations.logout),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.destructiveBgOf(context),
          foregroundColor: AppColors.destructiveFgOf(context),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusCard),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
