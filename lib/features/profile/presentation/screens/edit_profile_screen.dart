import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../data/repositories/profile_repository.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';

/// Edit Profile Screen
/// Allows users to edit their profile information
class EditProfileScreen extends StatefulWidget {
  final User currentUser;
  final AppLanguage currentLanguage;

  const EditProfileScreen({
    super.key,
    required this.currentUser,
    required this.currentLanguage,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _areaController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final MediaPickerService _mediaPicker = MediaPickerService();
  final ProfileRepository _profileRepo = ProfileRepository();

  File? _selectedImage;
  bool _isSaving = false;

  Color _iconChipBg({Color? seed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = seed ?? AppColors.primaryOf(context);
    return isDark ? base.withValues(alpha: 0.28) : base.withValues(alpha: 0.1);
  }

  Color _iconChipFg({Color? seed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.onPrimaryOf(context)
        : (seed ?? AppColors.primary);
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentUser.displayName;
    _bioController.text = widget.currentUser.bio ?? '';
    _areaController.text = widget.currentUser.area ?? '';
    _districtController.text = widget.currentUser.district ?? '';
    _stateController.text = widget.currentUser.state ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _areaController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: _iconChipFg(seed: AppColors.primary),
              ),
              title: Text(
                AppLocalizations(widget.currentLanguage).chooseFromGallery,
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: _iconChipFg(seed: AppColors.primary),
              ),
              title: Text(AppLocalizations(widget.currentLanguage).takePhoto),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    File? file;
    if (source == 'gallery') {
      file = await _mediaPicker.pickImageFromGallery();
    } else {
      file = await _mediaPicker.pickImageFromCamera();
    }

    // Crop image
    if (file != null && mounted) {
      final croppedFile = await _mediaPicker.cropImage(file);
      if (croppedFile != null && mounted) {
        setState(() => _selectedImage = croppedFile);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? profilePictureUrl;
      if (_selectedImage != null) {
        // Upload to storage (demo mode - returns local path)
        profilePictureUrl = await _profileRepo.uploadProfilePicture(
          _selectedImage!.path,
          widget.currentUser.id,
        );
      }

      // Update profile in database
      await _profileRepo.updateProfile(
        userId: widget.currentUser.id,
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        profilePicture: profilePictureUrl ?? widget.currentUser.profilePicture,
        area: _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        district: _districtController.text.trim().isEmpty
            ? null
            : _districtController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
      );

      // Update in shared preferences
      final authRepo = await AuthRepository.init();
      await authRepo.updateProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        profilePicture: profilePictureUrl ?? widget.currentUser.profilePicture,
        area: _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        district: _districtController.text.trim().isEmpty
            ? null
            : _districtController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        syncRemote: false,
        notifyUserSync: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations(widget.currentLanguage).profileUpdatedSuccess,
            ),
            backgroundColor: AppColors.successOf(context),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.errorOf(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLanguage);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.editProfile),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                AppLocalizations(widget.currentLanguage).save,
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile picture
              GestureDetector(
                onTap: _pickProfilePicture,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary,
                      child: _selectedImage != null
                          ? ClipOval(
                              child: Image.file(
                                _selectedImage!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          : widget.currentUser.profilePicture != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: widget.currentUser.profilePicture!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.background,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.background,
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: AppColors.onPrimaryOf(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations.tapToChangeProfilePicture,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 32),

              // Display name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: localizations.displayName,
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.nameRequired;
                  }
                  if (value.trim().length < 2) {
                    return localizations.nameMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: '${localizations.bio} (${localizations.optional})',
                  prefixIcon: const Icon(Icons.info_outline),
                  hintText: localizations.bioHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Location Details Section
              _buildSectionHeader(
                localizations.locationDetails,
                Icons.location_on_rounded,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: InputDecoration(
                  labelText: localizations.area,
                  prefixIcon: const Icon(Icons.place_outlined),
                  hintText: localizations.areaHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: localizations.district,
                  prefixIcon: const Icon(Icons.map_outlined),
                  hintText: localizations.districtHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stateController,
                decoration: InputDecoration(
                  labelText: localizations.stateLabel,
                  prefixIcon: const Icon(Icons.flag_outlined),
                  hintText: localizations.stateHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _iconChipBg(seed: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: _iconChipFg(seed: AppColors.primary),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizations.profileVisibilityInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _iconChipFg(seed: AppColors.primary)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}
