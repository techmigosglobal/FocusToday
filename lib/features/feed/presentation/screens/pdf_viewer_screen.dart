import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/media_cache_service.dart';

/// PDF Viewer Screen
/// Full-screen PDF viewer for viewing PDF content
class PdfViewerScreen extends StatefulWidget {
  final Post post;
  final AppLanguage currentLanguage;

  const PdfViewerScreen({
    super.key,
    required this.post,
    required this.currentLanguage,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  String? _cachedPdfPath;
  bool _showControls = false;

  Color _iconChipBg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.primaryOf(context).withValues(alpha: 0.28)
        : AppColors.primary.withValues(alpha: 0.1);
  }

  Color _iconChipFg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.onPrimaryOf(context) : AppColors.primary;
  }

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _prepareCache();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _getLocalizedTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Page indicator
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          // Download/Share button
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations(widget.currentLanguage).shareComingSoon,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // PDF Viewer
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showControls = !_showControls),
              child: _buildPdfViewer(),
            ),
          ),

          // Bottom controls
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildBottomControls(),
            crossFadeState: _showControls
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Future<void> _prepareCache() async {
    final pdfUrl = widget.post.pdfFilePath ?? widget.post.mediaUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) return;
    if (!pdfUrl.startsWith('http://') && !pdfUrl.startsWith('https://')) {
      return;
    }

    final cached = await MediaCacheService.getCachedFile(pdfUrl);
    if (cached != null && mounted) {
      setState(() => _cachedPdfPath = cached.path);
    }

    // Warm cache in background for future opens.
    MediaCacheService.warmInBackground(pdfUrl);
  }

  Widget _buildPdfViewer() {
    final pdfUrl = widget.post.pdfFilePath ?? widget.post.mediaUrl;

    if (pdfUrl == null || pdfUrl.isEmpty) {
      return _buildNoContentView();
    }

    // Check if it's a URL or local/asset file path
    if (_cachedPdfPath != null) {
      return SfPdfViewer.file(
        File(_cachedPdfPath!),
        controller: _pdfController,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (details) {
          setState(() {
            _currentPage = details.newPageNumber;
          });
        },
        onDocumentLoadFailed: (details) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${AppLocalizations(widget.currentLanguage).failedToLoadPdf}: ${details.description}',
                ),
              ),
            );
          }
        },
      );
    }

    if (pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://')) {
      return SfPdfViewer.network(
        pdfUrl,
        controller: _pdfController,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (details) {
          setState(() {
            _currentPage = details.newPageNumber;
          });
        },
        onDocumentLoadFailed: (details) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${AppLocalizations(widget.currentLanguage).failedToLoadPdf}: ${details.description}',
                ),
              ),
            );
          }
        },
      );
    } else if (pdfUrl.startsWith('assets/')) {
      // Handle Asset path
      return SfPdfViewer.asset(
        pdfUrl,
        controller: _pdfController,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (details) {
          setState(() {
            _currentPage = details.newPageNumber;
          });
        },
        onDocumentLoadFailed: (details) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${AppLocalizations(widget.currentLanguage).failedToLoadPdf}: ${details.description}',
                ),
              ),
            );
          }
        },
      );
    } else if (pdfUrl.startsWith('/') || pdfUrl.startsWith('file://')) {
      final normalizedPath = pdfUrl.startsWith('file://')
          ? pdfUrl.replaceFirst('file://', '')
          : pdfUrl;
      return SfPdfViewer.file(
        File(normalizedPath),
        controller: _pdfController,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (details) {
          setState(() {
            _currentPage = details.newPageNumber;
          });
        },
        onDocumentLoadFailed: (details) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${AppLocalizations(widget.currentLanguage).failedToLoadPdf}: ${details.description}',
                ),
              ),
            );
          }
        },
      );
    } else {
      return _buildNoContentView();
    }
  }

  String _getLocalizedTitle() {
    String languageCode;
    switch (widget.currentLanguage) {
      case AppLanguage.telugu:
        languageCode = 'te';
        break;
      case AppLanguage.hindi:
        languageCode = 'hi';
        break;
      default:
        languageCode = 'en';
    }
    return widget.post.getLocalizedCaption(languageCode);
  }

  Widget _buildNoContentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 80,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No PDF available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'This is a demo post',
            style: TextStyle(color: AppColors.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.first_page,
            label: 'First',
            onTap: () => _pdfController.jumpToPage(1),
          ),
          _buildControlButton(
            icon: Icons.navigate_before,
            label: 'Previous',
            onTap: () => _pdfController.previousPage(),
          ),
          _buildControlButton(
            icon: Icons.navigate_next,
            label: 'Next',
            onTap: () => _pdfController.nextPage(),
          ),
          _buildControlButton(
            icon: Icons.last_page,
            label: 'Last',
            onTap: () => _pdfController.jumpToPage(_totalPages),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _iconChipBg(),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _iconChipFg()),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
