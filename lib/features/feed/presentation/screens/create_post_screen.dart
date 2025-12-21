import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../data/repositories/post_repository.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/services/permission_service.dart';

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
  final _articleContentController = TextEditingController();
  final _storyContentController = TextEditingController();
  final _poetryVersesController = TextEditingController();
  final MediaPickerService _mediaPicker = MediaPickerService();
  final PostRepository _postRepo = PostRepository();
  final PermissionService _permissionService = PermissionService();

  String _selectedCategory = 'News';
  File? _selectedMedia;
  ContentType _contentType = ContentType.none;
  bool _isSubmitting = false;
  late LanguageService _languageService;
  AppLanguage _currentLanguage = AppLanguage.english;

  final List<String> _categories = [
    'News',
    'Entertainment',
    'Sports',
    'Politics',
    'Technology',
    'Health',
    'Business',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initLanguage();
  }

  Future<void> _initLanguage() async {
    _languageService = await LanguageService.init();
    _languageService.addListener(_updateLanguage);
    setState(() {
      _currentLanguage = _languageService.currentLanguage;
    });
  }

  void _updateLanguage() {
    if (mounted) {
      setState(() {
        _currentLanguage = _languageService.currentLanguage;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _articleContentController.dispose();
    _storyContentController.dispose();
    _poetryVersesController.dispose();
    _languageService.removeListener(_updateLanguage);
    super.dispose();
  }

  /// Show media source selection bottom sheet
  Future<void> _showMediaSourcePicker(ContentType type) async {
    // Request storage permission with rationale dialog
    final hasPermission = await _permissionService.requestStoragePermission(
      context,
    );
    if (!hasPermission) {
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

    // Request camera permission if using camera
    if (source == 'camera') {
      final hasCameraPermission = await _permissionService
          .requestCameraPermission(context);
      if (!hasCameraPermission) {
        return;
      }
    }

    if (!mounted) return;

    File? file;
    try {
      if (type == ContentType.image) {
        if (source == 'gallery') {
          file = await _mediaPicker.pickImageFromGallery();
        } else {
          file = await _mediaPicker.pickImageFromCamera();
        }

        // Crop image if selected
        if (file != null && mounted) {
          try {
            final croppedFile = await _mediaPicker.cropImage(file);
            file = croppedFile ?? file;
          } catch (cropError) {
            debugPrint('Image crop error: $cropError');
            // Continue with uncropped image if crop fails
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not crop image, using original'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      } else {
        if (source == 'gallery') {
          file = await _mediaPicker.pickVideoFromGallery();
        } else {
          file = await _mediaPicker.pickVideoFromCamera();
        }
      }
    } on PlatformException catch (e) {
      debugPrint(
        'Platform exception selecting media: ${e.code} - ${e.message}',
      );
      if (mounted) {
        String errorMessage = 'Error selecting media';
        if (e.code == 'photo_access_denied' ||
            e.code == 'camera_access_denied') {
          errorMessage =
              'Permission denied. Please enable permissions in settings.';
        } else if (e.code == 'already_active') {
          errorMessage = 'Media picker is already open';
        } else {
          errorMessage = 'Error: ${e.message ?? e.code}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    } catch (e) {
      debugPrint('Error selecting media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting media: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Validate file before setting state
    if (file != null && mounted) {
      try {
        // Check if file exists
        if (!file.existsSync()) {
          throw Exception('Selected file does not exist');
        }

        // Check file size
        final fileSize = file.lengthSync();
        if (fileSize == 0) {
          throw Exception('Selected file is empty');
        }

        setState(() {
          _selectedMedia = file;
          _contentType = type;
        });
      } catch (e) {
        debugPrint('File validation error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid file: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  /// Show verification success dialog
  void _showVerificationDialog() {
    final localizations = AppLocalizations(_currentLanguage);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              localizations.postSubmitted,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              localizations.postPendingReview,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_top,
                    size: 16,
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    localizations.pending,
                    style: TextStyle(
                      color: const Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return to feed
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Submit post
  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contentType != ContentType.none &&
        !_contentType.isTextBased &&
        _selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select media for this post type')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? mediaUrl;
      String? pdfUrl;

      // 1. Upload media if exists
      if (_selectedMedia != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedMedia!.path.split('/').last}';
        final destination = 'posts/${widget.currentUser.id}/$fileName';

        mediaUrl = await _postRepo.uploadMedia(
          _selectedMedia!.path,
          destination,
        );

        if (_contentType == ContentType.pdf) {
          pdfUrl = mediaUrl;
          mediaUrl = null; // Clear if it was PDF
        }
      }

      // Prepare content-specific data
      String? articleContent;
      List<String>? poemVerses;

      if (_contentType == ContentType.article) {
        articleContent = _articleContentController.text.trim();
      } else if (_contentType == ContentType.story) {
        articleContent = _storyContentController.text.trim();
      } else if (_contentType == ContentType.poetry) {
        final versesText = _poetryVersesController.text.trim();
        if (versesText.isNotEmpty) {
          poemVerses = versesText
              .split('\n\n')
              .where((verse) => verse.trim().isNotEmpty)
              .toList();
        }
      }

      // 2. Create post document in Firestore
      await _postRepo.createPost(
        authorId: widget.currentUser.id,
        authorName: widget.currentUser.displayName,
        authorAvatar: widget.currentUser.profilePicture,
        caption: _captionController.text.trim(),
        mediaUrl: mediaUrl,
        contentType: _contentType,
        category: _selectedCategory,
        status: PostStatus.pending,
        pdfFilePath: pdfUrl,
        articleContent: articleContent,
        poemVerses: poemVerses,
      );

      if (mounted) {
        _showVerificationDialog();
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
    final localizations = AppLocalizations(_currentLanguage);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.createPost),
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
                localizations.submit.toUpperCase(),
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
                  hintText: localizations.captionHint,
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
                    return localizations.captionRequired;
                  }
                  if (value.trim().length < 10) {
                    return localizations.captionMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category selection
              Text(
                localizations.category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                    child: Text(localizations.getCategoryName(category)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Content Type selection
              Text(
                'Content Type',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ContentType>(
                initialValue: _contentType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: ContentType.none,
                    child: Text('Text Only'),
                  ),
                  DropdownMenuItem(
                    value: ContentType.article,
                    child: Text('Article'),
                  ),
                  DropdownMenuItem(
                    value: ContentType.story,
                    child: Text('Story'),
                  ),
                  DropdownMenuItem(
                    value: ContentType.poetry,
                    child: Text('Poetry'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _contentType = value;
                      // Clear media when switching to text-based types
                      if (value.isTextBased) {
                        _selectedMedia = null;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Article content input
              if (_contentType == ContentType.article) ...[
                Text(
                  'Article Content',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _articleContentController,
                  maxLines: 10,
                  maxLength: 5000,
                  decoration: InputDecoration(
                    hintText: 'Write your article content here...',
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
                      return 'Article content is required';
                    }
                    if (value.trim().length < 50) {
                      return 'Article must be at least 50 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Story content input
              if (_contentType == ContentType.story) ...[
                Text(
                  'Story Content',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _storyContentController,
                  maxLines: 10,
                  maxLength: 5000,
                  decoration: InputDecoration(
                    hintText: 'Write your story here...',
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
                      return 'Story content is required';
                    }
                    if (value.trim().length < 50) {
                      return 'Story must be at least 50 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Poetry verses input
              if (_contentType == ContentType.poetry) ...[
                Text(
                  'Poetry Verses',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Separate verses with double line breaks',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _poetryVersesController,
                  maxLines: 10,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText:
                        'Write your poetry verses here...\n\nSeparate each verse with a blank line.',
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
                      return 'Poetry content is required';
                    }
                    if (value.trim().length < 20) {
                      return 'Poetry must be at least 20 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Media preview or add media buttons (only for non-text types or when media is selected)
              if (!_contentType.isTextBased || _selectedMedia != null) ...[
                Text(
                  localizations.mediaPreview,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                                    const Text(
                                      'PDF Document',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedMedia!.path.split('/').last,
                                      style: const TextStyle(
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
              ] else if (!_contentType.isTextBased) ...[
                Text(
                  localizations.addMedia,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showMediaSourcePicker(ContentType.image),
                        icon: const Icon(Icons.image),
                        label: Text(localizations.imageLabel),
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
                        label: Text(localizations.videoLabel),
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
                    label: Text(localizations.pdfLabel),
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
                        localizations.postReviewInfo,
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
