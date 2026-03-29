import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/post_sync_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/user_sync_service.dart';

/// Basic Details Form — Public users fill in Name, Area, District, State
/// Shown after first login or accessible from profile settings
class BasicDetailsScreen extends StatefulWidget {
  final User currentUser;
  final bool isFirstTime; // If true, shows welcome message and can't go back

  const BasicDetailsScreen({
    super.key,
    required this.currentUser,
    this.isFirstTime = false,
  });

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _areaController;
  late TextEditingController _districtController;
  late TextEditingController _stateController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentUser.displayName,
    );
    _areaController = TextEditingController(
      text: widget.currentUser.area ?? '',
    );
    _districtController = TextEditingController(
      text: widget.currentUser.district ?? '',
    );
    _stateController = TextEditingController(
      text: widget.currentUser.state ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirestoreService.users.doc(widget.currentUser.id).set({
        'display_name': _nameController.text.trim(),
        'area': _areaController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await CacheService.invalidate('profile_user_${widget.currentUser.id}');
      await CacheService.invalidate('profile_stats_${widget.currentUser.id}');
      UserSyncService.notify(
        reason: UserSyncReason.updated,
        userId: widget.currentUser.id,
      );
      PostSyncService.notify(
        reason: PostSyncReason.updated,
        authorId: widget.currentUser.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Details saved successfully!'),
            backgroundColor: AppColors.successOf(context),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: AppColors.errorOf(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isFirstTime,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Basic Details'),
          automaticallyImplyLeading: !widget.isFirstTime,
          actions: [
            if (!widget.isFirstTime)
              TextButton(
                onPressed: _isSubmitting ? null : _saveDetails,
                child: const Text('SAVE'),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isFirstTime) ...[
                  // Welcome banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.onPrimaryOf(
                              context,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.waving_hand,
                            color: AppColors.onPrimaryOf(context),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to Focus Today!',
                                style: TextStyle(
                                  color: AppColors.onPrimaryOf(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Please fill in your basic details to get started.',
                                style: TextStyle(
                                  color: AppColors.onPrimaryOf(
                                    context,
                                  ).withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (v.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Area field
                TextFormField(
                  controller: _areaController,
                  decoration: InputDecoration(
                    labelText: 'Area / Village / Town',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Area is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // District field
                TextFormField(
                  controller: _districtController,
                  decoration: InputDecoration(
                    labelText: 'District',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'District is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // State field
                TextFormField(
                  controller: _stateController,
                  decoration: InputDecoration(
                    labelText: 'State',
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'State is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _saveDetails,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimaryOf(context),
                            ),
                          )
                        : Text(
                            widget.isFirstTime ? 'Continue' : 'Save Details',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                if (widget.isFirstTime) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
