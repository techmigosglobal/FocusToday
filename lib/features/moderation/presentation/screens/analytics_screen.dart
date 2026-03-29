import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/post_sync_service.dart';
import '../../../../core/services/user_sync_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../feed/data/repositories/post_repository.dart';
import '../../data/repositories/user_repository.dart';

/// Analytics Screen — Interactive dashboard with content & user insights
class AnalyticsScreen extends StatefulWidget {
  final User currentUser;
  final AppLanguage currentLanguage;
  const AnalyticsScreen({
    super.key,
    required this.currentUser,
    required this.currentLanguage,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late TabController _tabController;

  // Content stats
  int _totalPosts = 0;
  int _pendingPosts = 0;
  int _approvedPosts = 0;
  int _rejectedPosts = 0;
  int _totalLikes = 0;
  int _totalBookmarks = 0;
  int _totalShares = 0;
  Map<String, int> _categoryBreakdown = {};
  Map<String, int> _contentTypeBreakdown = {};

  // User stats
  int _totalUsers = 0;
  int _reporters = 0;
  int _admins = 0;
  int _publicUsers = 0;
  int _premiumUsers = 0;
  int _adPartners = 0;
  StreamSubscription<PostSyncEvent>? _postSyncSubscription;
  StreamSubscription<UserSyncEvent>? _userSyncSubscription;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenForLiveSync();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _postSyncSubscription?.cancel();
    _userSyncSubscription?.cancel();
    _refreshDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenForLiveSync() {
    _postSyncSubscription = PostSyncService.stream.listen((_) {
      _debouncedRefresh();
    });
    _userSyncSubscription = UserSyncService.stream.listen((_) {
      _debouncedRefresh();
    });
  }

  void _debouncedRefresh() {
    if (!mounted) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadAnalytics();
    });
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final postRepo = PostRepository();
      final userRepo = UserRepository();

      // Fetch all posts by status in parallel
      final results = await Future.wait([
        postRepo.getPostsByStatus(PostStatus.approved),
        postRepo.getPostsByStatus(PostStatus.pending),
        postRepo.getPostsByStatus(PostStatus.rejected),
        userRepo.getAllUsersFlat(pageSize: 50),
        _loadMonetizationSnapshot(),
      ]);

      final approved = results[0] as List<Post>;
      final pending = results[1] as List<Post>;
      final rejected = results[2] as List<Post>;
      final users = results[3] as List<User>;
      final monetization = results[4] as Map<String, dynamic>;

      final allPosts = [...approved, ...pending, ...rejected];

      // Category breakdown
      final catMap = <String, int>{};
      for (final p in allPosts) {
        catMap[p.category] = (catMap[p.category] ?? 0) + 1;
      }

      // Content type breakdown
      final typeMap = <String, int>{};
      for (final p in allPosts) {
        final label = p.contentType.toStr();
        typeMap[label] = (typeMap[label] ?? 0) + 1;
      }

      // Engagement
      int likes = 0, bookmarks = 0, shares = 0;
      for (final p in approved) {
        likes += p.likesCount;
        bookmarks += p.bookmarksCount;
        shares += p.sharesCount;
      }

      // User role distribution
      int reporterCount = 0, adminCount = 0, pubCount = 0;
      for (final u in users) {
        switch (u.role) {
          case UserRole.reporter:
            reporterCount++;
            break;
          case UserRole.admin:
          case UserRole.superAdmin:
            adminCount++;
            break;
          case UserRole.publicUser:
            pubCount++;
            break;
        }
      }
      final premiumUsers = users.where((u) => u.isSubscribed).length;

      if (!mounted) return;
      setState(() {
        _totalPosts = allPosts.length;
        _approvedPosts = approved.length;
        _pendingPosts = pending.length;
        _rejectedPosts = rejected.length;
        _totalLikes = likes;
        _totalBookmarks = bookmarks;
        _totalShares = shares;
        _categoryBreakdown = catMap;
        _contentTypeBreakdown = typeMap;
        _totalUsers = users.length;
        _reporters = reporterCount;
        _admins = adminCount;
        _publicUsers = pubCount;
        _premiumUsers = premiumUsers;
        _adPartners = (monetization['ad_partners'] as int?) ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Analytics] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _loadMonetizationSnapshot() async {
    int adPartners = 0;

    try {
      final partners = await FirestoreService.partners
          .where('status', isEqualTo: 'approved')
          .count()
          .get();
      adPartners = partners.count ?? 0;
    } catch (_) {
      // Non-blocking: analytics should still render without monetization extras.
    }

    return {'ad_partners': adPartners};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Material(
              color: AppColors.primary,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.onPrimaryOf(context),
                labelColor: AppColors.onPrimaryOf(context),
                unselectedLabelColor: AppColors.onPrimaryOf(
                  context,
                ).withValues(alpha: 0.7),
                tabs: [
                  Tab(
                    text: AppLocalizations(widget.currentLanguage).content,
                    icon: const Icon(Icons.article_rounded, size: 18),
                  ),
                  Tab(
                    text: AppLocalizations(widget.currentLanguage).users,
                    icon: const Icon(Icons.people_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadAnalytics,
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildContentTab(), _buildUsersTab()],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.7),
            AppColors.accent,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -18,
            child: Icon(
              Icons.analytics_rounded,
              size: 120,
              color: AppColors.onPrimaryOf(context).withValues(alpha: 0.08),
            ),
          ),
          Text(
            AppLocalizations(widget.currentLanguage).analytics,
            style: TextStyle(
              color: AppColors.onPrimaryOf(context),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    final l = AppLocalizations(widget.currentLanguage);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview cards
        _buildSectionTitle(l.overview, Icons.dashboard_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(
                    l.totalPosts,
                    '$_totalPosts',
                    Icons.article_rounded,
                    AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(
                    l.approved,
                    '$_approvedPosts',
                    Icons.check_circle_rounded,
                    AppColors.successOf(context),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(
                    l.pending,
                    '$_pendingPosts',
                    Icons.pending_rounded,
                    AppColors.warningOf(context),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(
                    l.rejected,
                    '$_rejectedPosts',
                    Icons.cancel_rounded,
                    AppColors.destructiveFgOf(context),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Engagement
        _buildSectionTitle(l.engagement, Icons.favorite_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth < 100
                      ? (constraints.maxWidth - 12) / 2
                      : cardWidth,
                  child: _buildStatCard(
                    l.likes,
                    _formatNumber(_totalLikes),
                    Icons.favorite_rounded,
                    AppColors.likeStrong,
                  ),
                ),
                SizedBox(
                  width: cardWidth < 100
                      ? (constraints.maxWidth - 12) / 2
                      : cardWidth,
                  child: _buildStatCard(
                    l.saved,
                    _formatNumber(_totalBookmarks),
                    Icons.bookmark_rounded,
                    AppColors.warningOf(context),
                  ),
                ),
                SizedBox(
                  width: cardWidth < 100
                      ? (constraints.maxWidth - 12) / 2
                      : cardWidth,
                  child: _buildStatCard(
                    l.shares,
                    _formatNumber(_totalShares),
                    Icons.share_rounded,
                    AppColors.infoOf(context),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Post status distribution bar
        _buildSectionTitle(l.statusDistribution, Icons.pie_chart_rounded),
        const SizedBox(height: 12),
        _buildDistributionBar([
          _DistSegment(
            l.approved,
            _approvedPosts,
            AppColors.successOf(context),
          ),
          _DistSegment(l.pending, _pendingPosts, AppColors.warningOf(context)),
          _DistSegment(
            l.rejected,
            _rejectedPosts,
            AppColors.destructiveFgOf(context),
          ),
        ]),

        const SizedBox(height: 24),

        // Content type breakdown
        _buildSectionTitle(l.contentTypes, Icons.category_rounded),
        const SizedBox(height: 12),
        _buildBreakdownList(_contentTypeBreakdown, _contentTypeColors(context)),

        const SizedBox(height: 24),

        // Category breakdown
        _buildSectionTitle(l.categories, Icons.label_rounded),
        const SizedBox(height: 12),
        _buildBreakdownList(_categoryBreakdown, _categoryColors(context)),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildUsersTab() {
    final l = AppLocalizations(widget.currentLanguage);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle(l.userOverview, Icons.people_rounded),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                l.totalUsers,
                '$_totalUsers',
                Icons.group_rounded,
                AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth < 100
                      ? (constraints.maxWidth - 12) / 2
                      : cardWidth,
                  child: _buildStatCard(
                    l.reporters,
                    '$_reporters',
                    Icons.mic_rounded,
                    AppColors.secondary,
                  ),
                ),
                SizedBox(
                  width: cardWidth < 100
                      ? (constraints.maxWidth - 12) / 2
                      : cardWidth,
                  child: _buildStatCard(
                    l.admins,
                    '$_admins',
                    Icons.admin_panel_settings,
                    AppColors.accent,
                  ),
                ),
                SizedBox(
                  width: cardWidth < 100
                      ? (constraints.maxWidth - 12) / 2
                      : cardWidth,
                  child: _buildStatCard(
                    l.publicUsers,
                    '$_publicUsers',
                    Icons.person_rounded,
                    AppColors.infoOf(context),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        _buildSectionTitle(l.roleDistribution, Icons.pie_chart_rounded),
        const SizedBox(height: 12),
        _buildDistributionBar([
          _DistSegment(l.publicUsers, _publicUsers, AppColors.infoOf(context)),
          _DistSegment(l.reporters, _reporters, AppColors.secondary),
          _DistSegment(l.admins, _admins, AppColors.accent),
        ]),

        const SizedBox(height: 24),

        // Quick stats
        _buildSectionTitle(l.quickStats, Icons.bolt_rounded),
        const SizedBox(height: 12),
        _buildQuickStat(
          l.avgPostsPerUser,
          _totalUsers > 0
              ? (_totalPosts / _totalUsers).toStringAsFixed(1)
              : '0',
        ),
        _buildQuickStat(
          l.approvalRate,
          _totalPosts > 0
              ? '${(_approvedPosts / _totalPosts * 100).toStringAsFixed(1)}%'
              : '0%',
        ),
        _buildQuickStat(
          l.avgLikesPerPost,
          _approvedPosts > 0
              ? (_totalLikes / _approvedPosts).toStringAsFixed(1)
              : '0',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('Monetization', Icons.payments_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(
                    'Premium Users',
                    '$_premiumUsers',
                    Icons.workspace_premium_rounded,
                    AppColors.trustBlue,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildStatCard(
                    'Ad Partners',
                    '$_adPartners',
                    Icons.campaign_rounded,
                    AppColors.accent,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - anim)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionBar(List<_DistSegment> segments) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceTier2Of(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            AppLocalizations(widget.currentLanguage).noData,
            style: TextStyle(color: AppColors.textSecondaryOf(context)),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 36,
              sections: segments.where((s) => s.value > 0).map((s) {
                final pct = (s.value / total * 100).round();
                return PieChartSectionData(
                  value: s.value.toDouble(),
                  title: '$pct%',
                  color: s.color,
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.toastText,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: segments.map((s) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${s.label} (${s.value})',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBreakdownList(
    Map<String, int> data,
    Map<String, Color> colorMap,
  ) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          AppLocalizations(widget.currentLanguage).noDataAvailable,
          style: TextStyle(color: AppColors.textSecondaryOf(context)),
        ),
      );
    }

    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final requiredWidth = math.max(
          constraints.maxWidth,
          sorted.length * 62.0,
        );
        final chartHeight = sorted.length * 40.0 + 30;

        return SizedBox(
          height: chartHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: requiredWidth,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (sorted.first.value.toDouble()) * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = sorted[group.x.toInt()];
                        return BarTooltipItem(
                          '${_capitalize(entry.key)}: ${entry.value}',
                          const TextStyle(
                            color: AppColors.toastText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= sorted.length) {
                            return const SizedBox();
                          }
                          final title = _capitalize(sorted[idx].key);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              title.length > 8
                                  ? '${title.substring(0, 7)}..'
                                  : title,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: List.generate(sorted.length, (i) {
                    final entry = sorted[i];
                    final color =
                        colorMap[entry.key.toLowerCase()] ?? AppColors.primary;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: color,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Map<String, Color> _contentTypeColors(BuildContext context) => {
    'image': AppColors.successOf(context),
    'video': AppColors.likeStrong,
    'pdf': AppColors.warningOf(context),
    'article': AppColors.infoOf(context),
    'story': AppColors.trustBlue,
    'poetry': AppColors.secondary,
    'none': AppColors.textSecondaryOf(context),
  };

  Map<String, Color> _categoryColors(BuildContext context) => {
    'technology': AppColors.infoOf(context),
    'business': AppColors.successOf(context),
    'sports': AppColors.warningOf(context),
    'politics': AppColors.trustBlue,
    'health': AppColors.infoOf(context),
    'world': AppColors.textSecondaryOf(context),
    'news': AppColors.primary,
    'articles': AppColors.trustBlue,
    'stories': AppColors.secondary,
    'poetry': AppColors.warningOf(context),
    'education': AppColors.secondary,
    'other': AppColors.textMutedOf(context),
  };
}

class _DistSegment {
  final String label;
  final int value;
  final Color color;
  const _DistSegment(this.label, this.value, this.color);
}
