import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/cloud_functions_service.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/firestore_service.dart';

/// Storage Limits Screen — Admin can view; SuperAdmin can edit configured values.
class StorageLimitsScreen extends StatefulWidget {
  final User currentUser;

  const StorageLimitsScreen({super.key, required this.currentUser});

  @override
  State<StorageLimitsScreen> createState() => _StorageLimitsScreenState();
}

class _StorageLimitsScreenState extends State<StorageLimitsScreen> {
  AppLocalizations get _l => AppLocalizations(
    AppLanguage.fromCode(widget.currentUser.preferredLanguage),
  );

  bool _isLoading = true;
  bool _isSaving = false;

  // Configured totals
  double _postsLimit = 5.0;
  double _interactionsLimit = 2.0;
  double _usersLimit = 1.0;
  double _systemFilesLimit = 3.0;

  // Configured utilised values (manual)
  double _postsUtilised = 0.0;
  double _interactionsUtilised = 0.0;
  double _usersUtilised = 0.0;
  double _systemFilesUtilised = 0.0;

  // Saved snapshot for dirty-check
  double _savedPostsLimit = 5.0;
  double _savedInteractionsLimit = 2.0;
  double _savedUsersLimit = 1.0;
  double _savedSystemFilesLimit = 3.0;
  double _savedPostsUtilised = 0.0;
  double _savedInteractionsUtilised = 0.0;
  double _savedUsersUtilised = 0.0;
  double _savedSystemFilesUtilised = 0.0;

  bool get canView =>
      widget.currentUser.role == UserRole.superAdmin ||
      widget.currentUser.role == UserRole.admin;

  bool get canEdit => widget.currentUser.role == UserRole.superAdmin;

  bool get _hasUnsavedChanges =>
      (_postsLimit - _savedPostsLimit).abs() > 0.001 ||
      (_interactionsLimit - _savedInteractionsLimit).abs() > 0.001 ||
      (_usersLimit - _savedUsersLimit).abs() > 0.001 ||
      (_systemFilesLimit - _savedSystemFilesLimit).abs() > 0.001 ||
      (_postsUtilised - _savedPostsUtilised).abs() > 0.001 ||
      (_interactionsUtilised - _savedInteractionsUtilised).abs() > 0.001 ||
      (_usersUtilised - _savedUsersUtilised).abs() > 0.001 ||
      (_systemFilesUtilised - _savedSystemFilesUtilised).abs() > 0.001;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final configDoc = await FirestoreService.storageConfig.get();
      final config = configDoc.data() ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _postsLimit = _toDouble(config['posts_limit_gb'], 5.0);
        _interactionsLimit = _toDouble(config['interactions_limit_gb'], 2.0);
        _usersLimit = _toDouble(config['users_limit_gb'], 1.0);
        _systemFilesLimit = _toDouble(config['system_files_gb'], 3.0);

        _postsUtilised = _toDouble(config['posts_utilised_gb'], 0.0);
        _interactionsUtilised = _toDouble(
          config['interactions_utilised_gb'],
          0.0,
        );
        _usersUtilised = _toDouble(config['users_utilised_gb'], 0.0);
        _systemFilesUtilised = _toDouble(
          config['system_files_utilised_gb'],
          0.0,
        );

        _savedPostsLimit = _postsLimit;
        _savedInteractionsLimit = _interactionsLimit;
        _savedUsersLimit = _usersLimit;
        _savedSystemFilesLimit = _systemFilesLimit;
        _savedPostsUtilised = _postsUtilised;
        _savedInteractionsUtilised = _interactionsUtilised;
        _savedUsersUtilised = _usersUtilised;
        _savedSystemFilesUtilised = _systemFilesUtilised;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_l.failedToLoadStorageData}: $e')),
      );
    }
  }

  Future<void> _saveConfig() async {
    if (!canEdit) return;

    if (!_hasUnsavedChanges) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.noChangesToSave)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await CloudFunctionsService.instance
          .httpsCallable('updateStorageConfig')
          .call({
            'posts_limit_gb': _postsLimit,
            'interactions_limit_gb': _interactionsLimit,
            'users_limit_gb': _usersLimit,
            'system_files_gb': _systemFilesLimit,
            'posts_utilised_gb': _postsUtilised,
            'interactions_utilised_gb': _interactionsUtilised,
            'users_utilised_gb': _usersUtilised,
            'system_files_utilised_gb': _systemFilesUtilised,
          });
      await _loadData();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l.storageConfigUpdated),
          backgroundColor: AppColors.successOf(context),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_l.failedToSave}: $e'),
          backgroundColor: AppColors.errorOf(context),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return Scaffold(
        appBar: AppBar(title: Text(_l.storageLimits)),
        body: Center(child: Text(_l.noAccessToPage)),
      );
    }

    final totalLimit =
        _postsLimit + _interactionsLimit + _usersLimit + _systemFilesLimit;
    final totalUsed =
        _postsUtilised +
        _interactionsUtilised +
        _usersUtilised +
        _systemFilesUtilised;

    return Scaffold(
      appBar: AppBar(
        title: Text(_l.storageLimits),
        actions: [
          if (canEdit)
            TextButton.icon(
              onPressed: _isSaving || !_hasUnsavedChanges ? null : _saveConfig,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_l.save),
            ),
        ],
      ),
      bottomNavigationBar: canEdit
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: _isSaving || !_hasUnsavedChanges
                      ? null
                      : _saveConfig,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? _l.saving : _l.saveStorageConfig),
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTotalStorageCard(totalUsed, totalLimit),
                  const SizedBox(height: 16),

                  _buildSectionHeader(_l.configuredStorage),
                  const SizedBox(height: 8),
                  _buildConfigCard(
                    title: _l.postsStorage,
                    icon: Icons.article_outlined,
                    color: AppColors.primary,
                    utilised: _postsUtilised,
                    total: _postsLimit,
                    onChangedUtilised: (v) =>
                        setState(() => _postsUtilised = v),
                    onChangedTotal: (v) => setState(() => _postsLimit = v),
                  ),
                  _buildConfigCard(
                    title: _l.interactionsStorage,
                    icon: Icons.favorite_outline,
                    color: AppColors.warningOf(context),
                    utilised: _interactionsUtilised,
                    total: _interactionsLimit,
                    onChangedUtilised: (v) =>
                        setState(() => _interactionsUtilised = v),
                    onChangedTotal: (v) =>
                        setState(() => _interactionsLimit = v),
                  ),
                  _buildConfigCard(
                    title: _l.usersStorage,
                    icon: Icons.people_outline,
                    color: AppColors.infoOf(context),
                    utilised: _usersUtilised,
                    total: _usersLimit,
                    onChangedUtilised: (v) =>
                        setState(() => _usersUtilised = v),
                    onChangedTotal: (v) => setState(() => _usersLimit = v),
                  ),
                  _buildConfigCard(
                    title: _l.systemFilesLimitLabel,
                    icon: Icons.settings_outlined,
                    color: AppColors.iconMutedOf(context),
                    utilised: _systemFilesUtilised,
                    total: _systemFilesLimit,
                    onChangedUtilised: (v) =>
                        setState(() => _systemFilesUtilised = v),
                    onChangedTotal: (v) =>
                        setState(() => _systemFilesLimit = v),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalStorageCard(double totalUsed, double totalLimit) {
    final percentage = totalLimit > 0
        ? (totalUsed / totalLimit).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  color: AppColors.onPrimaryOf(context),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  _l.totalStorage,
                  style: TextStyle(
                    color: AppColors.onPrimaryOf(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppColors.onPrimaryOf(
                  context,
                ).withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.onPrimaryOf(context),
                ),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${totalUsed.toStringAsFixed(2)} GB / ${totalLimit.toStringAsFixed(2)} GB',
              style: TextStyle(
                color: AppColors.onPrimaryOf(context).withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildConfigCard({
    required String title,
    required IconData icon,
    required Color color,
    required double utilised,
    required double total,
    required ValueChanged<double> onChangedUtilised,
    required ValueChanged<double> onChangedTotal,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    label: _l.configuredUtilisedGb,
                    value: utilised,
                    enabled: canEdit,
                    onChanged: onChangedUtilised,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    label: _l.configuredTotalGb,
                    value: total,
                    enabled: canEdit,
                    minValue: 0.01,
                    onChanged: onChangedTotal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
    double minValue = 0,
  }) {
    return TextFormField(
      enabled: enabled,
      initialValue: value.toStringAsFixed(2),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
      ],
      onChanged: (raw) {
        final parsed = double.tryParse(raw);
        if (parsed == null) return;
        if (parsed < minValue) return;
        onChanged(parsed);
      },
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double _toDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
