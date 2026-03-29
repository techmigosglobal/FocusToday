import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/user.dart';
import '../../../moderation/data/repositories/user_repository.dart';

/// Admin screen to review reporter applications (GAP-003)
class ReporterApplicationsScreen extends StatefulWidget {
  final User currentUser;

  const ReporterApplicationsScreen({super.key, required this.currentUser});

  @override
  State<ReporterApplicationsScreen> createState() =>
      _ReporterApplicationsScreenState();
}

class _ReporterApplicationsScreenState extends State<ReporterApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserRepository _userRepo = UserRepository();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
    String docId,
    String applicantId,
    String status, {
    String? rejectionReason,
  }) async {
    final l = AppLocalizations(
      AppLanguage.fromCode(widget.currentUser.preferredLanguage),
    );
    setState(() => _isProcessing = true);
    try {
      if (status == 'approved') {
        if (applicantId.trim().isEmpty) {
          throw Exception('Invalid applicant id');
        }
        final roleUpdated = await _userRepo.updateUserRole(
          applicantId,
          UserRole.reporter,
        );
        if (!roleUpdated) {
          throw Exception('Unable to update user role to reporter');
        }
      }

      final updateData = <String, dynamic>{
        'status': status,
        'reviewed_by': widget.currentUser.id,
        'reviewed_at': FieldValue.serverTimestamp(),
      };
      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      await FirestoreService.reporterApplications.doc(docId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? l.reporterApprovedMessage
                  : l.reporterRejectedMessage,
            ),
            backgroundColor: status == 'approved'
                ? AppColors.successOf(context)
                : AppColors.errorOf(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showRejectDialog(String docId, String applicantId) async {
    final l = AppLocalizations(
      AppLanguage.fromCode(widget.currentUser.preferredLanguage),
    );
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.rejectApplication),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: l.enterRejectionReason,
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructiveBgOf(context),
            ),
            child: Text(l.reject),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _updateStatus(
        docId,
        applicantId,
        'rejected',
        rejectionReason: reasonController.text.trim(),
      );
    }
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(
      AppLanguage.fromCode(widget.currentUser.preferredLanguage),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.reporterApplications),
        backgroundColor: AppColors.surfaceOf(context),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l.pending),
            Tab(text: l.approved),
            Tab(text: l.rejected),
          ],
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ApplicationList(
                  status: 'pending',
                  localizations: l,
                  onApprove: _updateStatus,
                  onReject: _showRejectDialog,
                ),
                _ApplicationList(status: 'approved', localizations: l),
                _ApplicationList(status: 'rejected', localizations: l),
              ],
            ),
    );
  }
}

class _ApplicationList extends StatelessWidget {
  final String status;
  final AppLocalizations localizations;
  final Future<void> Function(
    String,
    String,
    String, {
    String? rejectionReason,
  })?
  onApprove;
  final Future<void> Function(String, String)? onReject;

  const _ApplicationList({
    required this.status,
    required this.localizations,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.reporterApplications
          .where('status', isEqualTo: status)
          .orderBy('submitted_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  localizations.noApplications(
                    status == 'pending'
                        ? localizations.pending
                        : status == 'approved'
                        ? localizations.approved
                        : localizations.rejected,
                  ),
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _ApplicationCard(
              docId: doc.id,
              data: data,
              isPending: status == 'pending',
              onApprove: onApprove != null
                  ? () => onApprove!(
                      doc.id,
                      data['applicant_id'] as String? ?? '',
                      'approved',
                    )
                  : null,
              onReject: onReject != null
                  ? () =>
                        onReject!(doc.id, data['applicant_id'] as String? ?? '')
                  : null,
            );
          },
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isPending;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ApplicationCard({
    required this.docId,
    required this.data,
    required this.isPending,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(
      AppLanguage.fromCode(Localizations.localeOf(context).languageCode),
    );
    final name = (data['full_name'] as String?) ?? 'Unknown';
    final phone = (data['phone'] as String?) ?? '-';
    final district = (data['district'] as String?) ?? '-';
    final state = (data['state'] as String?) ?? '-';
    final qualification = (data['qualification'] as String?) ?? '-';
    final experience = (data['experience'] as String?) ?? '';
    final motivation = (data['motivation'] as String?) ?? '';
    final submittedAt = data['submitted_at'];
    final submittedLabel = _formatSubmittedAt(submittedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.overlaySoftOf(context).withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      phone,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: '$district, $state',
          ),
          _InfoRow(icon: Icons.school_outlined, label: qualification),
          if (experience.trim().isNotEmpty)
            _InfoRow(icon: Icons.work_outline_rounded, label: experience),
          _InfoRow(icon: Icons.schedule_rounded, label: submittedLabel),
          if (motivation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              motivation,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(l.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructiveFgOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l.approve),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.successOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatSubmittedAt(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    if (dt == null) return '-';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textSecondaryOf(context).withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
