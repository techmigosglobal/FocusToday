import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../moderation/data/repositories/report_repository.dart';
import '../../data/repositories/post_repository.dart';

/// Post Options Bottom Sheet
/// Shows action options for a post
class PostOptionsBottomSheet extends StatelessWidget {
  final Post post;
  final User currentUser;
  final AppLanguage currentLanguage;

  const PostOptionsBottomSheet({
    super.key,
    required this.post,
    required this.currentUser,
    required this.currentLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(currentLanguage);
    final isOwnPost = post.authorId == currentUser.id;
    final isAdmin =
        currentUser.role == UserRole.superAdmin ||
        currentUser.role == UserRole.admin;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  localizations.more,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),

          // Copy Link
          _buildOption(
            context,
            icon: Icons.link,
            title: localizations.copyLink,
            onTap: () {
              Clipboard.setData(ClipboardData(text: 'https://crii-focus-today.web.app/p/${post.id}'));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizations.linkCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Share
          _buildOption(
            context,
            icon: Icons.share,
            title: localizations.share,
            onTap: () {
              Navigator.pop(context);
              // Share handled by parent
            },
          ),

          // Report (if not own post)
          if (!isOwnPost)
            _buildOption(
              context,
              icon: Icons.flag_outlined,
              title: localizations.reportPost,
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context);
              },
            ),

          // Hide Post (if not own post)
          if (!isOwnPost)
            _buildOption(
              context,
              icon: Icons.visibility_off_outlined,
              title: localizations.hidePost,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.postHidden),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

          // Delete (if own post or admin)
          if (isOwnPost || isAdmin)
            _buildOption(
              context,
              icon: Icons.delete_outline,
              title: localizations.delete,
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context);
              },
            ),

          // Block User (Admin only, not own post)
          if (isAdmin && !isOwnPost)
            _buildOption(
              context,
              icon: Icons.block,
              title: localizations.blockUser,
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(
        title,
        style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 16),
      ),
      onTap: onTap,
    );
  }

  void _showReportDialog(BuildContext context) {
    final reasons = [
      'Inappropriate content',
      'Spam or misleading',
      'Hate speech',
      'Violence or threats',
      'Copyright violation',
      'Other',
    ];
    String? selectedReason;
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations(currentLanguage).reportPostTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations(currentLanguage).reportPostMessage),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selectedReason ?? '',
                onChanged: (v) => setDialogState(() => selectedReason = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons
                      .map(
                        (reason) => RadioListTile<String>(
                          title: Text(
                            reason,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: reason,
                          dense: true,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (selectedReason == 'Other')
                TextField(
                  controller: customController,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue...',
                  ),
                  maxLines: 2,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations(currentLanguage).cancel),
            ),
            TextButton(
              onPressed: () async {
                if (selectedReason == null) return;
                final reason = selectedReason == 'Other'
                    ? customController.text.trim()
                    : selectedReason!;
                if (reason.isEmpty) return;
                Navigator.pop(context);
                final success = await ReportRepository().reportPost(
                  postId: post.id,
                  reporterId: currentUser.id,
                  reason: reason,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? AppLocalizations(
                                currentLanguage,
                              ).reportConfirmation
                            : 'You have already reported this post',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations(currentLanguage).report),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PostRepository().deletePost(
                post.id,
                authorId: post.authorId,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations(currentLanguage).deleteConfirmation,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations(currentLanguage).delete),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations(currentLanguage).blockUserTitle),
        content: Text(AppLocalizations(currentLanguage).blockUserMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations(currentLanguage).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations(currentLanguage).blockConfirmation,
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations(currentLanguage).block),
          ),
        ],
      ),
    );
  }
}
