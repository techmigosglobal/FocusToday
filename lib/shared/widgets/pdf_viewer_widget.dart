import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

/// PDF Viewer Widget
/// Displays PDF documents with Syncfusion PDF Viewer
class PDFViewerWidget extends StatelessWidget {
  final String pdfPath;
  final bool showFullScreen;

  const PDFViewerWidget({
    super.key,
    required this.pdfPath,
    this.showFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PDF Document'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                // Future: Implement download functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download feature coming soon!'),
                  ),
                );
              },
            ),
          ],
        ),
        body: _buildPDFViewer(),
      );
    }

    return _buildPDFViewer();
  }

  Widget _buildPDFViewer() {
    // Normalize file path
    String normalizedPath = pdfPath;
    if (normalizedPath.startsWith('file://')) {
      normalizedPath = normalizedPath.replaceFirst('file://', '');
    }

    // Check if it's a network URL
    final bool isNetworkUrl =
        normalizedPath.startsWith('http://') ||
        normalizedPath.startsWith('https://');

    if (isNetworkUrl) {
      // Load PDF from network
      try {
        return Container(
          color: Colors.grey[200],
          child: SfPdfViewer.network(
            normalizedPath,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              // Show error message
              debugPrint('PDF load failed: ${details.error}');
            },
          ),
        );
      } catch (e) {
        return _buildErrorView(
          'Failed to load PDF from network: ${e.toString()}',
        );
      }
    }

    // Load PDF from local file
    final file = File(normalizedPath);

    if (!file.existsSync()) {
      return _buildErrorView(
        'PDF file not found at:\n$normalizedPath\n\nPlease ensure the file exists.',
      );
    }

    // Check file size
    try {
      final fileSize = file.lengthSync();
      if (fileSize == 0) {
        return _buildErrorView('PDF file is empty');
      }
    } catch (e) {
      return _buildErrorView('Cannot read PDF file: ${e.toString()}');
    }

    // Load the PDF
    try {
      return Container(
        color: Colors.grey[200],
        child: SfPdfViewer.file(
          file,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            debugPrint('PDF load failed: ${details.error}');
          },
        ),
      );
    } catch (e) {
      return _buildErrorView('Error loading PDF: ${e.toString()}');
    }
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Cannot Display PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// PDF Preview Widget for Feed
/// Shows first page of PDF with overlay
class PDFPreviewWidget extends StatelessWidget {
  final String pdfPath;
  final VoidCallback onTap;

  const PDFPreviewWidget({
    super.key,
    required this.pdfPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // PDF Preview
          PDFViewerWidget(pdfPath: pdfPath),

          // Overlay with tap hint
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),

          // Icon and text
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(Icons.picture_as_pdf, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'Tap to Read PDF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
