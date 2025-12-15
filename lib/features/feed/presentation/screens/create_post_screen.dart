import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../data/repositories/post_repository.dart';

/// Create Post Screen
/// Screen for creating new posts (Admin and Reporter only)
class CreatePostScreen extends StatefulWidget {
  final User currentUser;

  const CreatePostScreen({super.key, required this.currentUser});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final MediaPickerService _mediaPicker = MediaPickerService();
  final PostRepository _postRepo = PostRepository();

  String _selectedCategory = 'News';
  File? _selectedMedia;
  ContentType _contentType = ContentType.none;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'News',
    'Entertainment',
    'Sports',
    'Politics',
    'Technology',
    'Health',
    'Business',
    'Other',
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// Show media source selection bottom sheet
  Future<void> _showMediaSourcePicker(ContentType type) async {
    // Request storage permission before accessing gallery or camera
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to select media.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text(
                type == ContentType.image ? 'Take Photo' : 'Record Video',
              ),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    File? file;
    if (type == ContentType.image) {
      if (source == 'gallery') {
        file = await _mediaPicker.pickImageFromGallery();
      } else {
        file = await _mediaPicker.pickImageFromCamera();
      }

      // Crop image if selected
      if (file != null && mounted) {
        final croppedFile = await _mediaPicker.cropImage(file);
        file = croppedFile ?? file;
      }
    } else {
      if (source == 'gallery') {
        file = await _mediaPicker.pickVideoFromGallery();
      } else {
        file = await _mediaPicker.pickVideoFromCamera();
      }
    }

    if (file != null && mounted) {
      setState(() {
        _selectedMedia = file;
        _contentType = type;
      });
    }
  }

  /// Remove selected media
  void _removeMedia() {
    setState(() {
      _selectedMedia = null;
      _contentType = ContentType.none;
    });
  }

  /// Pick PDF file with validation
  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);

      // Validate file size (max 10MB)
      final fileSize = await file.length();
      final maxSize = 10 * 1024 * 1024; // 10MB

      if (fileSize > maxSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF file size must be less than 10MB'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _selectedMedia = file;
          _contentType = ContentType.pdf;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Submit post
  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Future: Upload media to server/storage if exists
      String? mediaUrl;
      if (_selectedMedia != null) {
        // For now, use local path
        // In production, upload to cloud storage
        mediaUrl = _selectedMedia!.path;
      }

      // Create post
      await _postRepo.createPost(
        authorId: widget.currentUser.id,
        authorName: widget.currentUser.displayName,
        authorAvatar: widget.currentUser.profilePicture,
        caption: _captionController.text.trim(),
        mediaUrl: mediaUrl,
        contentType: _contentType,
        category: _selectedCategory,
        status: PostStatus.pending,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post submitted for review!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate post was created
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          if (_isSubmitting)
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
              onPressed: _submitPost,
              child: Text(
                'POST',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Caption input
              TextFormField(
                controller: _captionController,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'What\'s happening?',
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
                    return 'Please enter a caption';
                  }
                  if (value.trim().length < 10) {
                    return 'Caption must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category selection
              const Text(
                'Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Media preview or add media buttons
              if (_selectedMedia != null) ...[
                const Text(
                  'Media Preview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _contentType == ContentType.image
                            ? Image.file(_selectedMedia!, fit: BoxFit.contain)
                            : _contentType == ContentType.pdf
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      size: 64,
                                      color: Colors.red.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'PDF Document',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedMedia!.path.split('/').last,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_circle_outline,
                                      size: 64,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Video selected',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _removeMedia,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Add Media (Optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showMediaSourcePicker(ContentType.image),
                        icon: const Icon(Icons.image),
                        label: const Text('Image'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showMediaSourcePicker(ContentType.video),
                        icon: const Icon(Icons.videocam),
                        label: const Text('Video'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // PDF Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickPdfFile,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    label: const Text('PDF Document'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your post will be reviewed by admins before publishing',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
}
