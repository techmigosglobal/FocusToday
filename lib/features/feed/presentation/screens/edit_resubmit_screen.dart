import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../data/repositories/post_repository.dart';
import '../utils/post_form_validation.dart';

/// Edit & Resubmit Screen — Reporter edits a rejected post and resubmits for review
class EditResubmitScreen extends StatefulWidget {
  final Post post;
  final User currentUser;

  const EditResubmitScreen({
    super.key,
    required this.post,
    required this.currentUser,
  });

  @override
  State<EditResubmitScreen> createState() => _EditResubmitScreenState();
}

class _EditResubmitScreenState extends State<EditResubmitScreen> {
  late quill.QuillController _captionController;
  late quill.QuillController _articleContentController;
  final MediaPickerService _mediaPicker = MediaPickerService();
  final PostRepository _postRepo = PostRepository();
  final PermissionService _permissionService = PermissionService();

  final FocusNode _captionFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _captionEditorScrollController = ScrollController();
  final ScrollController _contentEditorScrollController = ScrollController();

  late String _selectedCategory;
  File? _selectedMedia;
  late ContentType _contentType;
  String? _currentMediaUrl;
  bool _isSubmitting = false;
  bool _isUploadingMedia = false;
  double _submitProgress = 0.0;
  late final String _initialCaption;
  late final String _initialDescription;
  late final String _initialCategory;
  late final ContentType _initialContentType;
  late final String? _initialMediaUrl;

  final List<String> _categories = [
    'News',
    'Articles',
    'Stories',
    'Poetry',
    'Sports',
    'Politics',
    'Technology',
    'Health',
    'Business',
    'Education',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _captionController = _buildControllerFromDelta(
      widget.post.captionDelta,
      fallbackText: _normalizeLegacy(widget.post.caption),
    );
    _articleContentController = _buildControllerFromDelta(
      widget.post.articleContentDelta,
      fallbackText: _normalizeLegacy(widget.post.articleContent ?? ''),
    );
    _selectedCategory = widget.post.category;
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = _categories.first;
    }
    _contentType = widget.post.contentType;
    _currentMediaUrl = widget.post.mediaUrl ?? widget.post.pdfFilePath;
    _initialCaption = _plainText(_captionController);
    _initialDescription = _plainText(_articleContentController);
    _initialCategory = _selectedCategory;
    _initialContentType = _contentType;
    _initialMediaUrl = _currentMediaUrl;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _articleContentController.dispose();
    _captionFocusNode.dispose();
    _contentFocusNode.dispose();
    _captionEditorScrollController.dispose();
    _contentEditorScrollController.dispose();
    super.dispose();
  }

  quill.QuillController _buildController(String text) {
    final doc = quill.Document()..insert(0, text);
    return quill.QuillController(
      document: doc,
      selection: TextSelection.collapsed(
        offset: (doc.length - 1).clamp(0, 1 << 20),
      ),
    );
  }

  quill.QuillController _buildControllerFromDelta(
    List<dynamic>? delta, {
    required String fallbackText,
  }) {
    if (delta != null && delta.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(List<dynamic>.from(delta));
        return quill.QuillController(
          document: doc,
          selection: TextSelection.collapsed(
            offset: (doc.length - 1).clamp(0, 1 << 20),
          ),
        );
      } catch (_) {}
    }
    return _buildController(fallbackText);
  }

  String _normalizeLegacy(String raw) {
    return raw;
  }

  String _plainText(quill.QuillController controller) {
    return controller.document.toPlainText().trim();
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

  Widget _buildToolbar(quill.QuillController controller) {
    return _withQuillLocalizations(
      quill.QuillSimpleToolbar(
        controller: controller,
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
    );
  }

  Widget _buildEditor({
    required quill.QuillController controller,
    required FocusNode focusNode,
    required ScrollController scrollController,
    required String placeholder,
    required double minHeight,
    required double maxHeight,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      decoration: BoxDecoration(
        color:
            Theme.of(context).inputDecorationTheme.fillColor ??
            Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focusNode.hasFocus ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: _withQuillLocalizations(
        quill.QuillEditor(
          controller: controller,
          focusNode: focusNode,
          scrollController: scrollController,
          config: quill.QuillEditorConfig(placeholder: placeholder),
        ),
      ),
    );
  }

  Future<void> _pickMedia(ContentType type) async {
    final hasPermission = await _permissionService.requestStoragePermission(
      context,
    );
    if (!hasPermission || !mounted) return;

    File? file;
    if (type == ContentType.image) {
      file = await _mediaPicker.pickImageFromGallery();
      if (file != null && mounted) {
        try {
          final croppedFile = await _mediaPicker.cropImage(file);
          file = croppedFile ?? file;
        } catch (_) {}
      }
    } else if (type == ContentType.video) {
      file = await _mediaPicker.pickVideoFromGallery();
    } else if (type == ContentType.pdf) {
      file = await _mediaPicker.pickPdfFile();
    }

    if (file != null && mounted) {
      setState(() {
        _selectedMedia = file;
        _contentType = type;
        _currentMediaUrl = null;
      });
    }
  }

  void _removeMedia() {
    setState(() {
      _selectedMedia = null;
      _currentMediaUrl = null;
      _contentType = ContentType.none;
    });
  }

  String _fileNameFromPathOrUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    final withoutQuery = normalized.split('?').first;
    if (withoutQuery.contains('/')) {
      final encoded = withoutQuery.split('/').last;
      return Uri.decodeComponent(encoded);
    }
    return normalized;
  }

  Widget _buildMediaPreview(AppLocalizations l) {
    final hasLocal = _selectedMedia != null;
    final hasRemote = _currentMediaUrl != null && _currentMediaUrl!.isNotEmpty;
    if (!hasLocal && !hasRemote) return const SizedBox.shrink();

    final fileName = hasLocal
        ? _fileNameFromPathOrUrl(_selectedMedia!.path)
        : _fileNameFromPathOrUrl(_currentMediaUrl!);

    Widget child;
    if (_contentType == ContentType.image) {
      child = hasLocal
          ? Image.file(_selectedMedia!, fit: BoxFit.cover)
          : CachedNetworkImage(
              imageUrl: _currentMediaUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  const Icon(Icons.broken_image, size: 64),
            );
    } else if (_contentType == ContentType.video) {
      child = Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
              const SizedBox(height: 10),
              if (fileName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      child = Container(
        color: Colors.red.withValues(alpha: 0.08),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 10),
              Text(
                l.pdfLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (fileName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            onPressed: _removeMedia,
          ),
        ),
      ],
    );
  }

  Future<void> _resubmit() async {
    final l = AppLocalizations(
      AppLanguage.fromCode(widget.currentUser.preferredLanguage),
    );
    if (_isSubmitting) return;
    if (!_hasUnsavedChanges) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.noChangesToResubmit)));
      return;
    }
    final caption = _plainText(_captionController);
    final description = _plainText(_articleContentController);
    final validation = PostFormValidator.validate(
      contentType: _contentType,
      caption: caption,
      category: _selectedCategory,
      hasMedia: _selectedMedia != null || _currentMediaUrl != null,
      bodyContent: description,
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
      _submitProgress = _selectedMedia != null ? 0.05 : 0.45;
    });

    try {
      String? newMediaUrl = _currentMediaUrl;

      if (_selectedMedia != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedMedia!.path.split('/').last}';
        final destination = 'posts/$fileName';
        newMediaUrl = await _postRepo.uploadMedia(
          _selectedMedia!.path,
          destination,
          userId: widget.currentUser.id,
          onSendProgress: (sent, total) {
            if (!mounted || total <= 0) return;
            setState(() {
              _submitProgress = ((sent / total) * 0.7).clamp(0.05, 0.7);
            });
          },
        );
        if (mounted) {
          setState(() {
            _isUploadingMedia = false;
            _submitProgress = 0.8;
          });
        }
      }

      if (mounted && !_isUploadingMedia) {
        setState(
          () => _submitProgress = _submitProgress < 0.7 ? 0.7 : _submitProgress,
        );
      }
      final success = await _postRepo.resubmitPost(
        postId: widget.post.id,
        caption: caption,
        captionDelta: _captionController.document.toDelta().toJson(),
        mediaUrl: newMediaUrl,
        contentType: _contentType,
        category: _selectedCategory,
        articleContent: description,
        articleContentDelta: _articleContentController.document
            .toDelta()
            .toJson(),
        authorId: widget.post.authorId,
      );
      if (mounted) {
        setState(() => _submitProgress = 1.0);
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.failedToResubmitPost),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.errorLabel}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingMedia = false;
          _submitProgress = 0.0;
        });
      }
    }
  }

  bool get _hasUnsavedChanges {
    return _plainText(_captionController) != _initialCaption ||
        _plainText(_articleContentController) != _initialDescription ||
        _selectedCategory != _initialCategory ||
        _contentType != _initialContentType ||
        _selectedMedia != null ||
        _currentMediaUrl != _initialMediaUrl;
  }

  String _validationMessage(PostFormIssue? issue) {
    final l = AppLocalizations(
      AppLanguage.fromCode(widget.currentUser.preferredLanguage),
    );
    switch (issue) {
      case PostFormIssue.captionMissing:
      case PostFormIssue.captionTooShort:
        return l.atLeast3CharactersRequired;
      case PostFormIssue.textContentMissing:
        return l.contentRequiredForTextPosts;
      case PostFormIssue.mediaMissing:
        return l.pleaseAddMedia;
      case PostFormIssue.categoryMissing:
        return l.categoryRequired;
      case null:
        return l.pleaseVerifyPostDetails;
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    final l = AppLocalizations(
      AppLanguage.fromCode(widget.currentUser.preferredLanguage),
    );
    if (!_hasUnsavedChanges || _isSubmitting) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.discardChangesQuestion),
        content: Text(l.unsavedEditsForPost),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.discard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(
      AppLanguage.fromCode(widget.currentUser.preferredLanguage),
    );
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
        appBar: AppBar(
          title: Text(l.editAndResubmitTitle),
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
              TextButton.icon(
                onPressed: _resubmit,
                icon: const Icon(Icons.send, size: 18),
                label: Text(
                  l.resubmit.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_isSubmitting) _buildSubmissionProgress(l),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.post.rejectionReason != null &&
                          widget.post.rejectionReason!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.previousRejectionReason,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.post.rejectionReason!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.makeChangesAndResubmitInfo,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Text(
                        l.caption,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildToolbar(_captionController),
                      _buildEditor(
                        controller: _captionController,
                        focusNode: _captionFocusNode,
                        scrollController: _captionEditorScrollController,
                        placeholder: l.enterPostCaption,
                        minHeight: 96,
                        maxHeight: 180,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: l.category,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(l.getCategoryName(c)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<ContentType>(
                        initialValue: _contentType,
                        decoration: InputDecoration(
                          labelText: l.contentTypeLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ContentType.none,
                            child: Text(l.textLabel),
                          ),
                          DropdownMenuItem(
                            value: ContentType.image,
                            child: Text(l.imageLabel),
                          ),
                          DropdownMenuItem(
                            value: ContentType.video,
                            child: Text(l.videoLabel),
                          ),
                          DropdownMenuItem(
                            value: ContentType.pdf,
                            child: Text(l.pdfLabel),
                          ),
                          DropdownMenuItem(
                            value: ContentType.article,
                            child: Text(l.articleLabel),
                          ),
                          DropdownMenuItem(
                            value: ContentType.story,
                            child: Text(l.storyLabel),
                          ),
                          DropdownMenuItem(
                            value: ContentType.poetry,
                            child: Text(l.poetryLabel),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _contentType = v;
                              if (v.isTextBased) {
                                _selectedMedia = null;
                                _currentMediaUrl = null;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        l.contentDescription,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildToolbar(_articleContentController),
                      _buildEditor(
                        controller: _articleContentController,
                        focusNode: _contentFocusNode,
                        scrollController: _contentEditorScrollController,
                        placeholder: _contentType.isTextBased
                            ? l.writeYourContentHere
                            : l.addDescriptionStoryContext,
                        minHeight: 140,
                        maxHeight: _contentType.isTextBased ? 320 : 200,
                      ),
                      const SizedBox(height: 16),

                      if (_contentType.requiresMedia) ...[
                        Text(
                          l.mediaLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedMedia != null || _currentMediaUrl != null)
                          _buildMediaPreview(l)
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickMedia(ContentType.image),
                                  icon: const Icon(Icons.image),
                                  label: Text(l.addImage),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickMedia(ContentType.video),
                                  icon: const Icon(Icons.videocam),
                                  label: Text(l.addVideo),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickMedia(ContentType.pdf),
                                  icon: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                  ),
                                  label: Text(l.uploadPdf),
                                ),
                              ),
                            ],
                          ),
                      ],

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting ? null : _resubmit,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _isSubmitting
                                ? '${l.resubmit} '
                                      '${(_submitProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                                : l.resubmitForReview,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionProgress(AppLocalizations l) {
    final percent = (_submitProgress * 100).clamp(0, 100).toStringAsFixed(0);
    final label = _isUploadingMedia
        ? l.uploadingPercent(percent)
        : '${l.resubmit} $percent%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
}
