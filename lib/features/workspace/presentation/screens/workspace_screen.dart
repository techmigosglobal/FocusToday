import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/slice_surface.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../feed/presentation/screens/all_posts_screen.dart';
import '../../../feed/presentation/screens/create_post_screen.dart';
import '../../../feed/presentation/screens/pending_posts_screen.dart';
import '../../../feed/presentation/screens/rejected_posts_screen.dart';
import '../../../moderation/presentation/screens/analytics_screen.dart';
import '../../../moderation/presentation/screens/audit_timeline_screen.dart';
import '../../../moderation/presentation/screens/moderation_screen.dart';
import '../../../moderation/presentation/screens/storage_limits_screen.dart';
import '../../../moderation/presentation/screens/user_management_screen.dart';
import '../../../moderation/presentation/screens/breaking_news_management_screen.dart';
import '../../../meetings/presentation/screens/meetings_management_screen.dart';
import '../../../enrollment/presentation/screens/reporter_applications_screen.dart';
import '../../../focus_landing/presentation/screens/landing_content_management_screen.dart';
import '../widgets/send_breaking_news_dialog.dart';
import 'campaign_screen.dart';
import '../../../../core/services/language_service.dart';

class WorkspaceScreen extends StatelessWidget {
  final User currentUser;
  final AppLanguage currentLanguage;

  const WorkspaceScreen({
    super.key,
    required this.currentUser,
    required this.currentLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = currentUser.role == UserRole.superAdmin;
    final isReporter = currentUser.role == UserRole.reporter;
    final hasWorkspaceAccess = currentUser.canModerate || isReporter;
    final localizations = AppLocalizations(currentLanguage);

    if (!hasWorkspaceAccess) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(localizations.adminWorkspace),
          backgroundColor: AppColors.surfaceOf(context),
          elevation: 0,
          centerTitle: true,
        ),
        body: SliceBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.workspaceAccessRequired,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.workspaceToolsAvailable,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isReporter
              ? localizations.reporterWorkspace
              : localizations.adminWorkspace,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: isReporter
            ? [
                IconButton(
                  tooltip: localizations.pendingPosts,
                  icon: const Icon(Icons.pending_actions_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    SmoothPageRoute(
                      builder: (_) =>
                          PendingPostsScreen(currentUser: currentUser),
                    ),
                  ),
                ),
              ]
            : null,
        backgroundColor: AppColors.surfaceOf(context),
        elevation: 0,
        centerTitle: true,
      ),
      body: SliceBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimensions.responsivePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isReporter) ...[
                _buildSectionHeader(
                  context,
                  localizations.management,
                  Icons.admin_panel_settings,
                ),
                _buildSettingsCard(context, [
                  _buildNavTile(
                    context,
                    localizations.allPostsQueue,
                    Icons.dashboard_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            AllPostsScreen(currentUser: currentUser),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.userManagement,
                    Icons.people_alt_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            UserManagementScreen(currentUser: currentUser),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.moderation,
                    Icons.rule_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            ModerationScreen(currentUser: currentUser),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.reporterApplications,
                    Icons.assignment_ind_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => ReporterApplicationsScreen(
                          currentUser: currentUser,
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  context,
                  localizations.operations,
                  Icons.bolt_rounded,
                ),
                _buildSettingsCard(context, [
                  _buildNavTile(
                    context,
                    localizations.analytics,
                    Icons.analytics_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => AnalyticsScreen(
                          currentUser: currentUser,
                          currentLanguage: currentLanguage,
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    isSuperAdmin
                        ? localizations.storageConfig
                        : localizations.storageUsage,
                    Icons.storage_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            StorageLimitsScreen(currentUser: currentUser),
                      ),
                    ),
                  ),
                  _buildNavTile(
                    context,
                    localizations.meetingsTitle,
                    Icons.event_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => MeetingsManagementScreen(
                          currentUser: currentUser,
                          currentLanguage: currentLanguage,
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.landingContent,
                    Icons.view_compact_alt_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => LandingContentManagementScreen(
                          currentUser: currentUser,
                          currentLanguage: currentLanguage,
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.auditLogs,
                    Icons.history_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => const AuditTimelineScreen(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  context,
                  localizations.breakingNews,
                  Icons.campaign_rounded,
                ),
                _buildSettingsCard(context, [
                  _buildNavTile(
                    context,
                    localizations.sendBreakingNews,
                    Icons.send_rounded,
                    () => _showSendBreakingNewsDialog(context),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.breakingNews,
                    Icons.edit_notifications_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => BreakingNewsManagementScreen(
                          currentUser: currentUser,
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.fcmCampaigns,
                    Icons.campaign_outlined,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            CampaignScreen(currentLanguage: currentLanguage),
                      ),
                    ),
                  ),
                ]),
              ],
              if (isReporter) ...[
                _buildSectionHeader(
                  context,
                  localizations.contentCreation,
                  Icons.edit_document,
                ),
                _buildSettingsCard(context, [
                  _buildNavTile(
                    context,
                    localizations.createPost,
                    Icons.add_circle_outline_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            CreatePostScreen(currentUser: currentUser),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.pendingPosts,
                    Icons.pending_actions_rounded,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            PendingPostsScreen(currentUser: currentUser),
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  _buildNavTile(
                    context,
                    localizations.rejectedPosts,
                    Icons.assignment_return_outlined,
                    () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            RejectedPostsScreen(currentUser: currentUser),
                      ),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendBreakingNewsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SendBreakingNewsDialog(
        currentUser: currentUser,
        languageCode: currentLanguage.code,
      ),
    );
  }

  Color _tileIconBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.primaryOf(context).withValues(alpha: 0.28)
        : AppColors.primary.withValues(alpha: 0.1);
  }

  Color _tileIconFg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.onPrimaryOf(context) : AppColors.primary;
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.secondary : AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.overlaySoftOf(context).withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.16
                  : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNavTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _tileIconBg(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _tileIconFg(context), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.textPrimaryOf(context),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondaryOf(context).withValues(alpha: 0.5),
        size: 24,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 20,
      color: AppColors.dividerOf(context),
    );
  }
}
