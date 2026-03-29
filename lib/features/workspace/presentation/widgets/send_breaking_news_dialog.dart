import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/utils/english_content_normalizer.dart';
import '../../../../shared/models/user.dart';

enum _AudienceType { all, roles, users }

class SendBreakingNewsDialog extends StatefulWidget {
  final User currentUser;
  final String languageCode;

  const SendBreakingNewsDialog({
    super.key,
    required this.currentUser,
    required this.languageCode,
  });

  @override
  State<SendBreakingNewsDialog> createState() => _SendBreakingNewsDialogState();
}

class _SendBreakingNewsDialogState extends State<SendBreakingNewsDialog> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _delayMinutesController = TextEditingController(text: '0');
  final _userSearchController = TextEditingController();
  bool _isSending = false;
  _AudienceType _audienceType = _AudienceType.all;
  final Set<String> _selectedRoles = {'public_user'};
  final Set<String> _selectedUserIds = {};
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _userSearchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _delayMinutesController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoadingUsers = true);
      final snap = await FirestoreService.users.limit(200).get();
      final users = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList(growable: false);
      users.sort((a, b) {
        final aName = (a['display_name'] ?? '').toString().toLowerCase();
        final bName = (b['display_name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  void _filterUsers() {
    final query = _userSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredUsers = _allUsers);
      return;
    }
    setState(() {
      _filteredUsers = _allUsers
          .where((u) {
            final name = (u['display_name'] ?? '').toString().toLowerCase();
            final phone = (u['phone_number'] ?? '').toString().toLowerCase();
            final email = (u['email'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                phone.contains(query) ||
                email.contains(query);
          })
          .toList(growable: false);
    });
  }

  Future<void> _sendBreakingNews() async {
    final localizations = AppLocalizations(
      AppLanguage.fromCode(widget.languageCode),
    );
    final title = _titleController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final delayMinutes = int.tryParse(_delayMinutesController.text.trim()) ?? 0;
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizations.pleaseEnterTitle)));
      return;
    }
    if (!EnglishContentNormalizer.areEnglishLike([title, subtitle])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter breaking news content in English only.'),
        ),
      );
      return;
    }
    if (_audienceType == _AudienceType.roles && _selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.pleaseSelectAtLeastOneRole)),
      );
      return;
    }
    if (_audienceType == _AudienceType.users && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.pleaseSelectAtLeastOneUser)),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // 1. Deactivate old breaking news
      final activeNews = await FirestoreService.breakingNews
          .where('is_active', isEqualTo: true)
          .get();

      final batch = FirestoreService.db.batch();
      for (var doc in activeNews.docs) {
        batch.update(doc.reference, {'is_active': false});
      }

      // 2. Add new breaking news
      final newDocRef = FirestoreService.breakingNews.doc();
      batch.set(newDocRef, {
        'title': title,
        'headline': title,
        'subtitle': _subtitleController.text.trim().isEmpty ? null : subtitle,
        'summary': _subtitleController.text.trim().isEmpty ? null : subtitle,
        'notify_delay_minutes': delayMinutes.clamp(0, 1440),
        'published_at': FieldValue.serverTimestamp(),
        'is_active': true,
        'created_by': widget.currentUser.id,
        'audience': {
          'type': _audienceType == _AudienceType.all
              ? 'all'
              : _audienceType == _AudienceType.roles
              ? 'roles'
              : 'users',
          'roles': _selectedRoles.toList(growable: false),
          'user_ids': _selectedUserIds.toList(growable: false),
        },
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.breakingNewsSentSuccessfully),
            backgroundColor: AppColors.successOf(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorSendingBreakingNews}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(
      AppLanguage.fromCode(widget.languageCode),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            Icons.campaign_rounded,
            color: AppColors.destructiveBgOf(context),
          ),
          const SizedBox(width: 12),
          Text(
            localizations.sendBreakingNews,
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLines: 2,
              style: TextStyle(color: AppColors.textPrimaryOf(context)),
              decoration: InputDecoration(
                labelText: localizations.mainHeadingRequired,
                hintText: localizations.breakingNewsTitleHint,
                filled: true,
                fillColor: isDark
                    ? AppColors.surfaceDarkElevated
                    : AppColors.surfaceTier2Of(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subtitleController,
              maxLines: 2,
              style: TextStyle(color: AppColors.textPrimaryOf(context)),
              decoration: InputDecoration(
                labelText: localizations.subtitleOptional,
                hintText: localizations.breakingNewsSubtitleHint,
                filled: true,
                fillColor: isDark
                    ? AppColors.surfaceDarkElevated
                    : AppColors.surfaceTier2Of(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              localizations.breakingNewsBannerInfo,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _delayMinutesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: localizations.notifyUsersAfterMinutes,
                hintText: localizations.breakingNewsDelayHint,
                filled: true,
                fillColor: isDark
                    ? AppColors.surfaceDarkElevated
                    : AppColors.surfaceTier2Of(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.sendTo,
              style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_AudienceType>(
              segments: [
                ButtonSegment(
                  value: _AudienceType.all,
                  label: Text(localizations.allUsers),
                ),
                ButtonSegment(
                  value: _AudienceType.roles,
                  label: Text(localizations.byRole),
                ),
                ButtonSegment(
                  value: _AudienceType.users,
                  label: Text(localizations.specificUsers),
                ),
              ],
              selected: {_audienceType},
              onSelectionChanged: (next) {
                setState(() => _audienceType = next.first);
              },
            ),
            if (_audienceType == _AudienceType.roles) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRoleChip('public_user', localizations.publicUsers),
                  _buildRoleChip('reporter', localizations.reporter),
                  _buildRoleChip('admin', localizations.admin),
                  _buildRoleChip('super_admin', localizations.superAdminLabel),
                ],
              ),
            ],
            if (_audienceType == _AudienceType.users) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _userSearchController,
                decoration: InputDecoration(
                  hintText: localizations.searchUsersByNamePhoneEmail,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceDarkElevated
                      : AppColors.surfaceTier2Of(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dividerOf(context)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (_, i) {
                          final user = _filteredUsers[i];
                          final id = user['id'].toString();
                          final selected = _selectedUserIds.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedUserIds.add(id);
                                } else {
                                  _selectedUserIds.remove(id);
                                }
                              });
                            },
                            title: Text(
                              (user['display_name'] ?? localizations.unknown)
                                  .toString(),
                            ),
                            subtitle: Text(
                              (user['phone_number'] ?? user['email'] ?? '')
                                  .toString(),
                            ),
                            dense: true,
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendBreakingNews,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.destructiveBgOf(context),
            foregroundColor: AppColors.onPrimaryOf(context),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSending
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimaryOf(context),
                  ),
                )
              : Text(
                  localizations.broadcastNow,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String role, String label) {
    final selected = _selectedRoles.contains(role);
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (value) {
        setState(() {
          if (value) {
            _selectedRoles.add(role);
          } else {
            _selectedRoles.remove(role);
          }
        });
      },
    );
  }
}
