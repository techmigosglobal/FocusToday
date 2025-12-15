import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/models/user.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../data/repositories/auth_repository.dart';

/// Role Selection Screen
/// New users select their role (Admin/Reporter/Public)
class RoleSelectionScreen extends StatefulWidget {
  final String phoneNumber;

  const RoleSelectionScreen({super.key, required this.phoneNumber});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;
  bool _isLoading = false;

  /// Role data
  final List<Map<String, dynamic>> _roles = [
    {
      'role': UserRole.admin,
      'title': 'Admin',
      'description': 'Full control & content moderation',
      'icon': Icons.admin_panel_settings,
      'features': [
        'Upload content immediately',
        'Approve/reject/edit posts',
        'Access latest content',
        'User management',
      ],
    },
    {
      'role': UserRole.reporter,
      'title': 'Reporter',
      'description': 'Create & submit content for approval',
      'icon': Icons.camera_alt,
      'features': [
        'Upload content for approval',
        'All standard user features',
        'Access latest content',
        'Content analytics',
      ],
    },
    {
      'role': UserRole.publicUser,
      'title': 'Public User',
      'description': 'Browse & interact with content',
      'icon': Icons.person,
      'features': [
        'View content (7-day delay)',
        'Like, bookmark & share',
        'Search & explore',
        'Upgrade to premium',
      ],
    },
  ];

  /// Continue with selected role
  Future<void> _continue() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedRole = _selectedRole!;
      // Save session
      final authRepo = await AuthRepository.init();
      await authRepo.saveSession(
        phoneNumber: widget.phoneNumber,
        displayName: widget.phoneNumber, // Default to phone number
        role: selectedRole,
      );

      // Get the saved user
      final user = await authRepo.restoreSession();

      if (mounted && user != null) {
        // Navigate to feed
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => FeedScreen(currentUser: user)),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving session: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(
                AppDimensions.screenPaddingHorizontal,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Select your role to get started',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This cannot be changed later',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.warning),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Role cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPaddingHorizontal,
                ),
                itemCount: _roles.length,
                itemBuilder: (context, index) {
                  final roleData = _roles[index];
                  final role = roleData['role'] as UserRole;
                  final isSelected = _selectedRole == role;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedRole = role),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surface,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusCard,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  roleData['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary,
                                  size: 32,
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Title and description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roleData['title'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: isSelected
                                                ? AppColors.primary
                                                : null,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      roleData['description'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textPrimary
                                                .withValues(alpha: 0.7),
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Radio indicator
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Features
                          ...List.generate(
                            (roleData['features'] as List<String>).length,
                            (featureIndex) {
                              final feature =
                                  (roleData['features']
                                      as List<String>)[featureIndex];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        feature,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.all(
                AppDimensions.screenPaddingHorizontal,
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _continue,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
