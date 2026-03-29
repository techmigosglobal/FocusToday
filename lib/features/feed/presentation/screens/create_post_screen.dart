import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../data/repositories/post_repository.dart';
import '../utils/post_form_validation.dart';
import '../../../enrollment/presentation/screens/reporter_application_screen.dart';
import '../../../../main.dart';

/// Create Post Screen - 3-Step Wizard
/// Step 1: Choose Content Type (Image/Video/Text)
/// Step 2: Add Content (Media + Caption + Category)
/// Step 3: Preview & Submit
class CreatePostScreen extends StatefulWidget {
  final User currentUser;

  const CreatePostScreen({super.key, required this.currentUser});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // Form and controllers
  late quill.QuillController _captionController;
  late quill.QuillController _contentController;

  // Focus nodes and scroll controller for step 2
  final _captionFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _step2ScrollController = ScrollController();
  final _captionEditorScrollController = ScrollController();
  final _contentEditorScrollController = ScrollController();
  final _captionPreviewFocusNode = FocusNode();
  final _contentPreviewFocusNode = FocusNode();
  final _captionPreviewScrollController = ScrollController();
  final _contentPreviewScrollController = ScrollController();
  final _captionEditorKey = GlobalKey();
  final _contentEditorKey = GlobalKey();

  // Services
  final MediaPickerService _mediaPicker = MediaPickerService();
  final PermissionService _permissionService = PermissionService();

  // State
  int _currentStep = 0;
  ContentType _selectedType = ContentType.none;
  String _selectedCategory = 'News';
  File? _selectedMedia;
  bool _isSubmitting = false;
  bool _isUploadingMedia = false;
  double _uploadProgress = 0.0;
  double _submitProgress = 0.0;

  final List<String> _categories = [
    'News',
    'Articles',
    'Stories',
    'Poetry',
    'Others',
  ];

  static const String _draftKey = 'create_post_draft';

  bool get _hasCreateAccess => widget.currentUser.canUploadContent;
  bool get _hasUnsavedChanges =>
      _selectedType != ContentType.none ||
      _selectedCategory != 'News' ||
      _selectedMedia != null ||
      _captionController.document.toPlainText().trim().isNotEmpty ||
      _contentController.document.toPlainText().trim().isNotEmpty;
  AppLocalizations get _localizations {
    final lang =
        FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english;
    return AppLocalizations(lang);
  }

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

  Widget _withQuillLocalizations(Widget child) {
    return Localizations.override(
      context: context,
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _captionController = quill.QuillController.basic();
    _contentController = quill.QuillController.basic();
    _loadDraft();
    _captionFocusNode.addListener(_onFocusChange);
    _contentFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Scroll focused editor into view once keyboard is shown.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (!_step2ScrollController.hasClients) return;
      final targetContext = _captionFocusNode.hasFocus
          ? _captionEditorKey.currentContext
          : _contentFocusNode.hasFocus
          ? _contentEditorKey.currentContext
          : null;
      final targetObject = targetContext?.findRenderObject();
      if (targetObject == null) return;
      final viewport = RenderAbstractViewport.of(targetObject);
      final revealOffset = viewport.getOffsetToReveal(targetObject, 0.2).offset;
      final targetOffset = revealOffset
          .clamp(
            _step2ScrollController.position.minScrollExtent,
            _step2ScrollController.position.maxScrollExtent,
          )
          .toDouble();
      if ((targetOffset - _step2ScrollController.offset).abs() < 8) return;
      _step2ScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftJson = prefs.getString(_draftKey);
    if (draftJson != null) {
      if (!mounted) return;

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(_localizations.draftFound),
          content: Text(_localizations.restoreDraftQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                _localizations.discard,
                style: TextStyle(color: AppColors.textSecondaryOf(context)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _localizations.restore,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (shouldRestore == true) {
        final data = jsonDecode(draftJson) as Map<String, dynamic>;
        setState(() {
          _selectedType = ContentType.values.firstWhere(
            (e) => e.toString() == data['type'],
            orElse: () => ContentType.none,
          );
          _selectedCategory = data['category'] ?? 'News';
          final dynamic captionDeltaData = data['captionDelta'];
          if (captionDeltaData is List) {
            try {
              final captionDoc = quill.Document.fromJson(
                List<dynamic>.from(captionDeltaData),
              );
              _captionController = quill.QuillController(
                document: captionDoc,
                selection: const TextSelection.collapsed(offset: 0),
              );
            } catch (_) {
              final captionText = (data['caption'] ?? '').toString();
              final captionDoc = quill.Document()..insert(0, captionText);
              _captionController = quill.QuillController(
                document: captionDoc,
                selection: TextSelection.collapsed(
                  offset: captionDoc.length - 1,
                ),
              );
            }
          } else {
            final captionText = (data['caption'] ?? '').toString();
            final captionDoc = quill.Document()..insert(0, captionText);
            _captionController = quill.QuillController(
              document: captionDoc,
              selection: TextSelection.collapsed(offset: captionDoc.length - 1),
            );
          }

          final dynamic deltaData = data['contentDelta'];
          if (deltaData is List) {
            try {
              final doc = quill.Document.fromJson(
                List<dynamic>.from(deltaData),
              );
              _contentController = quill.QuillController(
                document: doc,
                selection: const TextSelection.collapsed(offset: 0),
              );
            } catch (_) {
              final text = (data['content'] ?? '').toString();
              final doc = quill.Document()..insert(0, text);
              _contentController = quill.QuillController(
                document: doc,
                selection: TextSelection.collapsed(offset: doc.length - 1),
              );
            }
          } else {
            final text = (data['content'] ?? '').toString();
            final doc = quill.Document()..insert(0, text);
            _contentController = quill.QuillController(
              document: doc,
              selection: TextSelection.collapsed(offset: doc.length - 1),
            );
          }
          if (data['mediaPath'] != null) {
            final file = File(data['mediaPath']);
            if (file.existsSync()) {
              _selectedMedia = file;
            }
          }
          if (_selectedType != ContentType.none) {
            _currentStep = 1;
          }
        });
      } else {
        prefs.remove(_draftKey);
      }
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final plainCaption = _captionController.document.toPlainText().trim();
    final captionDelta = _captionController.document.toDelta().toJson();
    final plainContent = _contentController.document.toPlainText().trim();
    final deltaContent = _contentController.document.toDelta().toJson();
    final draftData = {
      'type': _selectedType.toString(),
      'category': _selectedCategory,
      'caption': plainCaption,
      'captionDelta': captionDelta,
      'content': plainContent,
      'contentDelta': deltaContent,
      'mediaPath': _selectedMedia?.path,
    };
    await prefs.setString(_draftKey, jsonEncode(draftData));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localizations.draftSavedSuccessfully),
        backgroundColor: AppColors.successOf(context),
      ),
    );
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _contentController.dispose();
    _captionFocusNode.dispose();
    _contentFocusNode.dispose();
    _step2ScrollController.dispose();
    _captionEditorScrollController.dispose();
    _contentEditorScrollController.dispose();
    _captionPreviewFocusNode.dispose();
    _contentPreviewFocusNode.dispose();
    _captionPreviewScrollController.dispose();
    _contentPreviewScrollController.dispose();
    super.dispose();
  }

  // ==================== STEP NAVIGATION ====================

  void _nextStep() {
    if (_currentStep == 0 && _selectedType == ContentType.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_localizations.pleaseSelectContentType)),
      );
      return;
    }

    if (_currentStep == 1) {
      final validation = PostFormValidator.validate(
        contentType: _selectedType,
        caption: _captionController.document.toPlainText(),
        category: _selectedCategory,
        hasMedia: _selectedMedia != null,
        bodyContent: _contentController.document.toPlainText(),
      );
      if (!validation.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_validationMessage(validation.issue))),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      HapticFeedback.lightImpact();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      HapticFeedback.lightImpact();
    }
  }

  bool _isTextBasedType(ContentType type) {
    return type == ContentType.article ||
        type == ContentType.story ||
        type == ContentType.poetry ||
        type == ContentType.none;
  }

  String _previewMediaFileName() {
    final file = _selectedMedia;
    if (file == null) return '';
    final path = file.path.trim();
    if (path.isEmpty) return '';
    return path.split('/').last;
  }

  Widget _buildStep3MediaBackground() {
    final fileName = _previewMediaFileName();

    if (_selectedMedia != null && _selectedType == ContentType.image) {
      return Image.file(_selectedMedia!, fit: BoxFit.cover);
    }

    if (_selectedMedia != null && _selectedType == ContentType.video) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                size: 82,
                color: Colors.white,
              ),
              if (fileName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_selectedMedia != null && _selectedType == ContentType.pdf) {
      return Container(
        color: Colors.red.withValues(alpha: 0.1),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 10),
                Text(
                  _localizations.pdfLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (fileName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(
        child: Icon(
          _selectedType == ContentType.pdf
              ? Icons.picture_as_pdf
              : _selectedType == ContentType.video
              ? Icons.play_circle_outline
              : Icons.article_outlined,
          size: 80,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // ==================== MEDIA HANDLING ====================

  Future<void> _pickMedia() async {
    final hasPermission = await _permissionService.requestStoragePermission(
      context,
    );
    if (!hasPermission || !mounted) return;

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
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _iconChipBg(seed: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library,
                  color: _iconChipFg(seed: AppColors.primary),
                ),
              ),
              title: Text(
                _localizations.chooseFromGallery,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _localizations.selectFromYourPhotos,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                ),
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _iconChipBg(seed: AppColors.secondary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: _iconChipFg(seed: AppColors.secondary),
                ),
              ),
              title: Text(
                _selectedType == ContentType.image
                    ? _localizations.takePhoto
                    : _localizations.recordVideo,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _localizations.useCamera,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                ),
              ),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    if (source == 'camera') {
      final hasCameraPermission = await _permissionService
          .requestCameraPermission(context);
      if (!hasCameraPermission) return;
    }

    try {
      File? file;
      if (_selectedType == ContentType.image) {
        file = source == 'gallery'
            ? await _mediaPicker.pickImageFromGallery()
            : await _mediaPicker.pickImageFromCamera();

        if (file != null && mounted) {
          final croppedFile = await _mediaPicker.cropImage(file);
          file = croppedFile ?? file;
        }
      } else {
        file = source == 'gallery'
            ? await _mediaPicker.pickVideoFromGallery()
            : await _mediaPicker.pickVideoFromCamera();
      }

      if (file != null && file.existsSync() && mounted) {
        setState(() => _selectedMedia = file);
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizations.errorWithMessage('$e')),
            backgroundColor: AppColors.errorOf(context),
          ),
        );
      }
    }
  }

  Future<void> _pickPdf() async {
    try {
      final file = await _mediaPicker.pickPdfFile();
      if (file != null && file.existsSync() && mounted) {
        setState(() => _selectedMedia = file);
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizations.errorWithMessage('$e')),
            backgroundColor: AppColors.errorOf(context),
          ),
        );
      }
    }
  }

  // ==================== SUBMIT ====================

  Future<void> _submitPost() async {
    if (_isSubmitting) return;
    final validation = PostFormValidator.validate(
      contentType: _selectedType,
      caption: _captionController.document.toPlainText(),
      category: _selectedCategory,
      hasMedia: _selectedMedia != null,
      bodyContent: _contentController.document.toPlainText(),
    );
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_validationMessage(validation.issue))),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isUploadingMedia = _selectedMedia != null;
      _uploadProgress = _selectedMedia != null ? 0.0 : 1.0;
      _submitProgress = _selectedMedia != null ? 0.05 : 0.3;
    });
    HapticFeedback.mediumImpact();

    try {
      // Determine post status based on user role
      final postStatus =
          (widget.currentUser.role == UserRole.superAdmin ||
              widget.currentUser.role == UserRole.admin)
          ? PostStatus.approved
          : PostStatus.pending;

      final postRepo = PostRepository();

      // Upload media file to server if selected
      String? uploadedMediaUrl;
      bool mediaUploadFailed = false;
      if (_selectedMedia != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedMedia!.path.split('/').last}';
        final destination = 'posts/$fileName';
        uploadedMediaUrl = await postRepo.uploadMedia(
          _selectedMedia!.path,
          destination,
          userId: widget.currentUser.id,
          onSendProgress: (sent, total) {
            if (!mounted || total <= 0) return;
            setState(() {
              _uploadProgress = (sent / total).clamp(0.0, 1.0);
              _submitProgress = (_uploadProgress * 0.7).clamp(0.05, 0.7);
            });
          },
        );
        if (mounted) {
          setState(() {
            _uploadProgress = 1.0;
            _isUploadingMedia = false;
            _submitProgress = 0.72;
          });
        }
        mediaUploadFailed = uploadedMediaUrl == null;
      }

      if (mounted) {
        setState(() {
          _submitProgress = _selectedMedia != null ? 0.8 : 0.7;
        });
      }

      final plainContent = _contentController.document.toPlainText().trim();
      final plainCaption = _captionController.document.toPlainText().trim();
      final captionDelta = _captionController.document.toDelta().toJson();
      final contentDelta = _contentController.document.toDelta().toJson();

      // Create post with server URL (not local path)
      final createResult = await postRepo.createPost(
        authorId: widget.currentUser.id,
        authorName: widget.currentUser.displayName,
        authorRole: widget.currentUser.role.toStr(),
        authorAvatar: widget.currentUser.profilePicture,
        caption: plainCaption,
        captionDelta: captionDelta,
        mediaUrl: uploadedMediaUrl,
        contentType: _selectedType,
        category: _selectedCategory,
        status: postStatus,
        // Plain text is stored in current schema; delta is ready for structured
        // storage once backend field support is added.
        articleContent: plainContent.isNotEmpty ? plainContent : null,
        articleContentDelta: plainContent.isNotEmpty ? contentDelta : null,
      );
      debugPrint(
        '[CreatePost] postId=${createResult.postId} translationStatus='
        '${createResult.translationStatus} usedCF=${createResult.usedCloudFunction}',
      );

      if (mounted) {
        setState(() => _submitProgress = 1.0);
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingMedia = false;
          _uploadProgress = 0.0;
          _submitProgress = 0.0;
        });

        await _clearDraft();
        if (!mounted) return;

        if (mediaUploadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _localizations.errorWithMessage(
                  'Image upload failed; post was submitted as text-only.',
                ),
              ),
              backgroundColor: AppColors.warningOf(context),
            ),
          );
        }

        _showSuccessDialog(
          isAdmin:
              widget.currentUser.role == UserRole.superAdmin ||
              widget.currentUser.role == UserRole.admin,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingMedia = false;
          _uploadProgress = 0.0;
          _submitProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizations.errorWithMessage('$e')),
            backgroundColor: AppColors.errorOf(context),
          ),
        );
      }
    }
  }

  String _validationMessage(PostFormIssue? issue) {
    switch (issue) {
      case PostFormIssue.captionMissing:
        return _localizations.captionRequired;
      case PostFormIssue.captionTooShort:
        return _localizations.atLeast3CharactersRequired;
      case PostFormIssue.textContentMissing:
        return _localizations.contentRequiredForTextPosts;
      case PostFormIssue.mediaMissing:
        return _localizations.pleaseAddMedia;
      case PostFormIssue.categoryMissing:
        return _localizations.categoryRequired;
      case null:
        return _localizations.pleaseVerifyPostDetails;
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges || _isSubmitting) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_localizations.discardChangesQuestion),
        content: Text(_localizations.unsavedChangesSaveDraftPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: Text(_localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: Text(_localizations.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: Text(_localizations.saveDraft),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'save') {
      await _saveDraft();
      return true;
    }
    return choice == 'discard';
  }

  void _showSuccessDialog({bool isAdmin = false}) {
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
                  colors: isAdmin
                      ? [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.7),
                        ]
                      : [Colors.green, Colors.green.shade700],
                ),
              ),
              child: Icon(
                isAdmin ? Icons.publish : Icons.check,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAdmin
                  ? _localizations.postPublished
                  : _localizations.postSubmitted,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? _localizations.postNowLiveInFeed
                  : _localizations.postPendingReview,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _localizations.done,
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (!_hasCreateAccess) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          title: Text(_localizations.createPost),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 56,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(height: 14),
                Text(
                  _localizations.postingAccessRequired,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _localizations.postingAccessDescription,
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (widget.currentUser.role == UserRole.publicUser)
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) => ReporterApplicationScreen(
                          currentUser: widget.currentUser,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.app_registration_rounded),
                    label: Text(_localizations.applyAsReporter),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_hasUnsavedChanges || _isSubmitting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _confirmDiscardChanges();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(_localizations.createPost),
          centerTitle: true,
          actions: [
            if (_selectedType != ContentType.none)
              TextButton(
                onPressed: _saveDraft,
                child: Text(
                  _localizations.saveDraft,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              if (_isSubmitting) _buildSubmissionProgress(),

              // Step content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),

              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStepDot(0, _localizations.typeStep),
          _buildStepLine(0),
          _buildStepDot(1, _localizations.contentStep),
          _buildStepLine(1),
          _buildStepDot(2, _localizations.previewStep),
        ],
      ),
    );
  }

  Widget _buildSubmissionProgress() {
    final percent = (_submitProgress * 100).clamp(0, 100).toStringAsFixed(0);
    final label = _isUploadingMedia
        ? _localizations.uploadingPercent(percent)
        : '${_localizations.submitting} $percent%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _submitProgress.clamp(0.0, 1.0),
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 40 : 32,
          height: isCurrent ? 40 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.primary
                : Theme.of(context).dividerColor,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Theme.of(context).hintColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? AppColors.primary
                : AppColors.textSecondaryOf(context),
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = _currentStep > step;

    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1TypeSelection();
      case 1:
        return _buildStep2Content();
      case 2:
        return _buildStep3Preview();
      default:
        return const SizedBox();
    }
  }

  // ==================== STEP 1: TYPE SELECTION ====================

  Widget _buildStep1TypeSelection() {
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _localizations.whatWouldYouLikeToShare,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _localizations.chooseContentTypeToCreate,
            style: TextStyle(color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 32),
          _buildTypeCard(
            ContentType.image,
            Icons.image_rounded,
            _localizations.imagePost,
            _localizations.sharePhotoWithAudience,
            AppColors.successOf(context),
          ),
          const SizedBox(height: 16),
          _buildTypeCard(
            ContentType.video,
            Icons.videocam_rounded,
            _localizations.videoPost,
            _localizations.uploadVideoClip,
            AppColors.likeStrong,
          ),
          const SizedBox(height: 16),
          _buildTypeCard(
            ContentType.article,
            Icons.article_rounded,
            _localizations.textPost,
            _localizations.writeArticleStoryNews,
            AppColors.infoOf(context),
          ),
          const SizedBox(height: 16),
          _buildTypeCard(
            ContentType.pdf,
            Icons.picture_as_pdf_rounded,
            _localizations.pdfLabel,
            _localizations.uploadPdfFileToShare,
            AppColors.warningOf(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(
    ContentType type,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = type);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? color
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? color
                    : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                border: Border.all(
                  color: isSelected ? color : Theme.of(context).dividerColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 2: CONTENT ====================

  Widget _buildStep2Content() {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = keyboardInset > 0
        ? keyboardInset + 24
        : 120 + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      key: const ValueKey('step2'),
      controller: _step2ScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PDF picker
          if (_selectedType == ContentType.pdf) ...[
            Text(
              _localizations.uploadPdf,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: _selectedMedia != null
                    ? Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  size: 48,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    _selectedMedia!.path.split('/').last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedMedia = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file,
                            size: 48,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _localizations.tapToSelectPdfFile,
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _localizations.max20Mb,
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Media picker (for image/video)
          if (_selectedType == ContentType.image ||
              _selectedType == ContentType.video) ...[
            Text(
              _localizations.addMedia,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedMedia != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _selectedType == ContentType.image
                                ? Image.file(_selectedMedia!, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedMedia = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedType == ContentType.image
                                ? Icons.add_photo_alternate
                                : Icons.video_call,
                            size: 48,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _localizations.tapToAddMediaType(
                              _selectedType == ContentType.image
                                  ? _localizations.imageLabel.toLowerCase()
                                  : _localizations.videoLabel.toLowerCase(),
                            ),
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Caption/Title
          Text(
            _localizations.titleCaption,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _withQuillLocalizations(
            quill.QuillSimpleToolbar(
              controller: _captionController,
              config: quill.QuillSimpleToolbarConfig(
                showBoldButton: true,
                showItalicButton: true,
                showListBullets: true,
                showListNumbers: true,
                showUndo: false,
                showRedo: false,
                showStrikeThrough: false,
                showInlineCode: false,
                showSubscript: false,
                showSuperscript: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: false,
                showAlignmentButtons: false,
                showLeftAlignment: false,
                showCenterAlignment: false,
                showRightAlignment: false,
                showJustifyAlignment: false,
                showHeaderStyle: false,
                showFontFamily: false,
                showFontSize: false,
                showCodeBlock: false,
                showQuote: false,
                showIndent: false,
                showLink: false,
                showSearchButton: false,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: _captionEditorKey,
            constraints: const BoxConstraints(minHeight: 96, maxHeight: 180),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).inputDecorationTheme.fillColor ??
                  Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _captionFocusNode.hasFocus
                    ? AppColors.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _withQuillLocalizations(
              quill.QuillEditor(
                controller: _captionController,
                focusNode: _captionFocusNode,
                scrollController: _captionEditorScrollController,
                config: quill.QuillEditorConfig(
                  placeholder: _localizations.writeCompellingHeadline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Content/Description (for all posts - optional for media, required for text)
          Text(
            _localizations.contentDescription,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _withQuillLocalizations(
            quill.QuillSimpleToolbar(
              controller: _contentController,
              config: quill.QuillSimpleToolbarConfig(
                showBoldButton: true,
                showItalicButton: true,
                showListBullets: true,
                showListNumbers: true,
                showUndo: false,
                showRedo: false,
                showStrikeThrough: false,
                showInlineCode: false,
                showSubscript: false,
                showSuperscript: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: false,
                showAlignmentButtons: false,
                showLeftAlignment: false,
                showCenterAlignment: false,
                showRightAlignment: false,
                showJustifyAlignment: false,
                showHeaderStyle: false,
                showFontFamily: false,
                showFontSize: false,
                showCodeBlock: false,
                showQuote: false,
                showIndent: false,
                showLink: false,
                showSearchButton: false,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isTextBasedType(_selectedType)
                ? _localizations.writeFullContentOfPost
                : _localizations.addAdditionalDetailsOptional,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: _contentEditorKey,
            constraints: BoxConstraints(
              minHeight: 140,
              maxHeight: _isTextBasedType(_selectedType) ? 320 : 200,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).inputDecorationTheme.fillColor ??
                  Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _contentFocusNode.hasFocus
                    ? AppColors.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _withQuillLocalizations(
              quill.QuillEditor(
                controller: _contentController,
                focusNode: _contentFocusNode,
                scrollController: _contentEditorScrollController,
                config: quill.QuillEditorConfig(
                  placeholder: _isTextBasedType(_selectedType)
                      ? _localizations.writeYourContentHere
                      : _localizations.addDescriptionStoryContext,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category
          Text(
            _localizations.category,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = category);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Text(
                    _localizations.getCategoryName(category),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 3: PREVIEW ====================

  Widget _buildStep3Preview() {
    return SingleChildScrollView(
      key: const ValueKey('step3'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _localizations.preview,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _localizations.thisIsHowYourPostWillAppear,
            style: TextStyle(color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 24),

          // Preview Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 400,
                color: Colors.grey[900],
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background
                    _buildStep3MediaBackground(),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),

                    // Category badge
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _localizations
                              .getCategoryName(_selectedCategory)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    // Content
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.secondary,
                                child: Text(
                                  widget.currentUser.displayName.isNotEmpty
                                      ? widget.currentUser.displayName[0]
                                            .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.currentUser.displayName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${_localizations.justNow}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _captionController.document
                                    .toPlainText()
                                    .trim()
                                    .isNotEmpty
                                ? ''
                                : _localizations.yourCaptionWillAppearHere,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          if (_captionController.document
                              .toPlainText()
                              .trim()
                              .isNotEmpty)
                            _buildRichPreview(
                              controller: _captionController,
                              focusNode: _captionPreviewFocusNode,
                              scrollController: _captionPreviewScrollController,
                              maxHeight: 96,
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          if (_contentController.document
                              .toPlainText()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildRichPreview(
                              controller: _contentController,
                              focusNode: _contentPreviewFocusNode,
                              scrollController: _contentPreviewScrollController,
                              maxHeight: 68,
                              textStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Edit button
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.edit),
              label: Text(_localizations.editContent),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== NAVIGATION BUTTONS ====================

  Widget _buildNavigationButtons() {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardVisible && _currentStep == 1) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _localizations.back,
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              )
            else
              const Spacer(),

            if (_currentStep > 0) const SizedBox(width: 16),

            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : (_currentStep == 2 ? _submitPost : _nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _isUploadingMedia
                                  ? _localizations.uploadingPercent(
                                      (_uploadProgress * 100).toStringAsFixed(
                                        0,
                                      ),
                                    )
                                  : '${_localizations.submitting} '
                                        '${(_submitProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _currentStep == 2
                            ? _localizations.submitForReview
                            : _localizations.next,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichPreview({
    required quill.QuillController controller,
    required FocusNode focusNode,
    required ScrollController scrollController,
    required double maxHeight,
    required TextStyle textStyle,
  }) {
    final previewController = quill.QuillController(
      document: quill.Document.fromDelta(controller.document.toDelta()),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    return DefaultTextStyle(
      style: textStyle,
      child: SizedBox(
        height: maxHeight,
        child: IgnorePointer(
          child: _withQuillLocalizations(
            quill.QuillEditor(
              controller: previewController,
              focusNode: focusNode,
              scrollController: scrollController,
              config: const quill.QuillEditorConfig(
                showCursor: false,
                expands: false,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
