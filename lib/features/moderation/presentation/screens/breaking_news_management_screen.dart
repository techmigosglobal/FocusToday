import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/utils/english_content_normalizer.dart';
import '../../../../shared/models/user.dart';
import '../../../workspace/presentation/widgets/send_breaking_news_dialog.dart';
import '../../../../main.dart';

/// Breaking News Management Screen
/// Allows admins/superAdmins to view, edit, and manage breaking news
class BreakingNewsManagementScreen extends StatefulWidget {
  final User currentUser;

  const BreakingNewsManagementScreen({super.key, required this.currentUser});

  @override
  State<BreakingNewsManagementScreen> createState() =>
      _BreakingNewsManagementScreenState();
}

class _BreakingNewsManagementScreenState
    extends State<BreakingNewsManagementScreen> {
  List<Map<String, dynamic>> _allBreakingNews = [];
  bool _isLoading = true;
  String _selectedLanguage = 'en';
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  AppLocalizations get _l =>
      AppLocalizations(AppLanguage.fromCode(_selectedLanguage));

  @override
  void initState() {
    super.initState();
    _selectedLanguage = 'en';
    _initLanguage();
    _loadBreakingNews();
  }

  Future<void> _initLanguage() async {
    final lang = FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= lang;
    _languageService = lang;
    if (!_isLanguageListenerAttached) {
      lang.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (mounted) setState(() => _selectedLanguage = lang.currentLanguage.code);
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextCode = languageService.currentLanguage.code;
    if (nextCode == _selectedLanguage) return;
    setState(() => _selectedLanguage = nextCode);
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    super.dispose();
  }

  Future<void> _loadBreakingNews() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirestoreService.breakingNews
          .orderBy('published_at', descending: true)
          .limit(20)
          .get();

      if (!mounted) return;

      setState(() {
        _allBreakingNews = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[BreakingNewsManagement] Load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_l.errorLabel}: $e')));
      }
    }
  }

  Future<void> _deactivateBreakingNews(String id) async {
    try {
      await FirestoreService.breakingNews.doc(id).update({
        'is_active': false,
        'deactivated_at': FieldValue.serverTimestamp(),
        'deactivated_by': widget.currentUser.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l.breakingNewsDeactivated),
            backgroundColor: AppColors.successOf(context),
          ),
        );
        _loadBreakingNews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_l.errorLabel}: $e')));
      }
    }
  }

  Future<void> _reactivateBreakingNews(String id) async {
    try {
      // First deactivate all active ones
      final activeNews = await FirestoreService.breakingNews
          .where('is_active', isEqualTo: true)
          .get();

      final batch = FirestoreService.db.batch();
      for (var doc in activeNews.docs) {
        batch.update(doc.reference, {'is_active': false});
      }
      // Activate the selected one
      batch.update(FirestoreService.breakingNews.doc(id), {'is_active': true});
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l.breakingNewsActivated),
            backgroundColor: AppColors.successOf(context),
          ),
        );
        _loadBreakingNews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_l.errorLabel}: $e')));
      }
    }
  }

  Future<void> _deleteBreakingNews(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l.delete),
        content: Text(_l.deletePostMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructiveFgOf(context),
            ),
            child: Text(_l.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreService.breakingNews.doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l.breakingNewsDeleted),
            backgroundColor: AppColors.successOf(context),
          ),
        );
        _loadBreakingNews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_l.errorLabel}: $e')));
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> news) {
    final titleController = TextEditingController(text: news['title'] ?? '');
    final subtitleController = TextEditingController(
      text: news['subtitle'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l.edit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: _l.titleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subtitleController,
              decoration: InputDecoration(
                labelText: _l.subtitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateBreakingNews(
                news['id'],
                titleController.text,
                subtitleController.text,
              );
            },
            child: Text(_l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBreakingNews(
    String id,
    String title,
    String subtitle,
  ) async {
    if (title.trim().isEmpty) return;
    if (!EnglishContentNormalizer.areEnglishLike([title, subtitle])) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter breaking news content in English only.',
            ),
          ),
        );
      }
      return;
    }
    try {
      await FirestoreService.breakingNews.doc(id).update({
        'title': title.trim(),
        'subtitle': subtitle.trim().isEmpty ? null : subtitle.trim(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': widget.currentUser.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l.breakingNewsUpdated),
            backgroundColor: AppColors.successOf(context),
          ),
        );
        _loadBreakingNews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_l.errorLabel}: $e')));
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return _l.unknown;
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(_l.breakingNewsManagement),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBreakingNews,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => SendBreakingNewsDialog(
              currentUser: widget.currentUser,
              languageCode: _selectedLanguage,
            ),
          ).then((_) => _loadBreakingNews());
        },
        icon: const Icon(Icons.add),
        label: Text(_l.sendBreakingNews),
        backgroundColor: AppColors.destructiveFgOf(context),
        foregroundColor: AppColors.onPrimaryOf(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allBreakingNews.isEmpty
          ? _buildEmptyState()
          : _buildBreakingNewsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 80,
            color: AppColors.textSecondaryOf(context).withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            _l.noBreakingNews,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _l.createFirstBreakingNews,
            style: TextStyle(color: AppColors.textMutedOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakingNewsList() {
    final activeNews = _allBreakingNews
        .where((n) => n['is_active'] == true)
        .toList();
    final inactiveNews = _allBreakingNews
        .where((n) => n['is_active'] != true)
        .toList();

    return RefreshIndicator(
      onRefresh: () async => _loadBreakingNews(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (activeNews.isNotEmpty) ...[
            _buildSectionHeader(
              _l.activeBreakingNews,
              AppColors.destructiveFgOf(context),
            ),
            ...activeNews.map((news) => _buildNewsCard(news, isActive: true)),
            const SizedBox(height: 24),
          ],
          if (inactiveNews.isNotEmpty) ...[
            _buildSectionHeader(
              _l.pastBreakingNews,
              AppColors.textSecondaryOf(context),
            ),
            ...inactiveNews.map(
              (news) => _buildNewsCard(news, isActive: false),
            ),
          ],
          const SizedBox(height: 80), // FAB space
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Safely parses a Firestore field that may be a [Timestamp] or an ISO-8601 [String].
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Widget _buildNewsCard(Map<String, dynamic> news, {required bool isActive}) {
    final publishedAt = _parseTimestamp(news['published_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(
                color: AppColors.destructiveFgOf(
                  context,
                ).withValues(alpha: 0.5),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditDialog(news),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.destructiveFgOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _l.liveLabel,
                        style: TextStyle(
                          color: AppColors.onPrimaryOf(context),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondaryOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _l.inactiveLabel,
                        style: TextStyle(
                          color: AppColors.onPrimaryOf(context),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatDate(publishedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMutedOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                news['title'] ?? _l.noTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              if (news['subtitle'] != null &&
                  news['subtitle'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  news['subtitle'],
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.edit,
                    label: _l.edit,
                    onTap: () => _showEditDialog(news),
                  ),
                  const SizedBox(width: 8),
                  if (isActive) ...[
                    _buildActionButton(
                      icon: Icons.toggle_off,
                      label: _l.deactivateLabel,
                      color: AppColors.warningOf(context),
                      onTap: () => _deactivateBreakingNews(news['id']),
                    ),
                  ] else ...[
                    _buildActionButton(
                      icon: Icons.toggle_on,
                      label: _l.activateLabel,
                      color: AppColors.successOf(context),
                      onTap: () => _reactivateBreakingNews(news['id']),
                    ),
                  ],
                  const Spacer(),
                  _buildActionButton(
                    icon: Icons.delete,
                    label: _l.delete,
                    color: AppColors.destructiveFgOf(context),
                    onTap: () => _deleteBreakingNews(news['id']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
