import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../feed/data/repositories/post_repository.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';

/// Reporter analytics dashboard (personal content performance)
class ReporterAnalyticsScreen extends StatefulWidget {
  final User currentUser;

  const ReporterAnalyticsScreen({super.key, required this.currentUser});

  @override
  State<ReporterAnalyticsScreen> createState() =>
      _ReporterAnalyticsScreenState();
}

class _ReporterAnalyticsScreenState extends State<ReporterAnalyticsScreen> {
  bool _isLoading = true;
  bool _hasError = false;

  Map<String, dynamic> _totals = const {};
  List<Map<String, dynamic>> _topCategories = const [];
  List<Map<String, dynamic>> _topPosts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final repo = PostRepository();
      final approved = await repo.getPostsByAuthor(
        widget.currentUser.id,
        status: PostStatus.approved,
      );
      final pending = await repo.getPostsByAuthor(
        widget.currentUser.id,
        status: PostStatus.pending,
      );
      final rejected = await repo.getPostsByAuthor(
        widget.currentUser.id,
        status: PostStatus.rejected,
      );

      final all = [...approved, ...pending, ...rejected];
      final likes = approved.fold<int>(0, (s, p) => s + p.likesCount);
      final bookmarks = approved.fold<int>(0, (s, p) => s + p.bookmarksCount);
      final shares = approved.fold<int>(0, (s, p) => s + p.sharesCount);

      final catScore = <String, int>{};
      for (final p in all) {
        catScore[p.category] = (catScore[p.category] ?? 0) + 1;
      }
      final topCategories = catScore.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topPosts = [...approved]
        ..sort(
          (a, b) => (b.likesCount + b.sharesCount).compareTo(
            a.likesCount + a.sharesCount,
          ),
        );

      if (!mounted) return;
      setState(() {
        _totals = {
          'posts': all.length,
          'approved': approved.length,
          'pending': pending.length,
          'rejected': rejected.length,
          'likes': likes,
          'bookmarks': bookmarks,
          'shares': shares,
        };
        _topCategories = topCategories
            .take(6)
            .map((e) => {'category': e.key, 'count': e.value})
            .toList();
        _topPosts = topPosts
            .take(8)
            .map(
              (p) => {
                'id': p.id,
                'caption': p.caption,
                'likes': p.likesCount,
                'shares': p.sharesCount,
              },
            )
            .toList();
        _isLoading = false;
      });
      return;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  Widget _statCard(String label, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(
      AppLanguage.fromCode(Localizations.localeOf(context).languageCode),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.myAnalytics)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l.retry),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l.performanceOverview,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _statCard(
                              l.totalPosts,
                              _toInt(_totals['posts']),
                              Icons.article_rounded,
                              AppColors.primary,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              l.approved,
                              _toInt(_totals['approved']),
                              Icons.check_circle_rounded,
                              AppColors.successOf(context),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              l.pending,
                              _toInt(_totals['pending']),
                              Icons.pending_rounded,
                              AppColors.warningOf(context),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              l.rejected,
                              _toInt(_totals['rejected']),
                              Icons.cancel_rounded,
                              AppColors.destructiveFgOf(context),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              l.likes,
                              _toInt(_totals['likes']),
                              Icons.favorite_rounded,
                              AppColors.likeStrong,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              l.bookmarks,
                              _toInt(_totals['bookmarks']),
                              Icons.bookmark_rounded,
                              AppColors.warningOf(context),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              l.shares,
                              _toInt(_totals['shares']),
                              Icons.share_rounded,
                              AppColors.infoOf(context),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.topCategories,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_topCategories.isEmpty)
                    Text(l.noCategoryDataYet)
                  else
                    ..._topCategories.map((row) {
                      final category = (row['category'] ?? l.other).toString();
                      final count = _toInt(row['count']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.label_rounded),
                        title: Text(category),
                        trailing: Text(
                          '$count',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  Text(
                    l.topPosts,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_topPosts.isEmpty)
                    Text(l.noPostsYet)
                  else
                    ..._topPosts.map((row) {
                      final caption = (row['caption'] ?? '').toString().trim();
                      final likes = _toInt(row['likes']);
                      final shares = _toInt(row['shares']);
                      return Card(
                        child: ListTile(
                          title: Text(
                            caption.isEmpty ? l.untitledPost : caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            l.likesSharesSummary(likes, shares),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
