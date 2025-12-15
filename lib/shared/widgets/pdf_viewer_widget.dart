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
                  const SnackBar(content: Text('Download feature coming soon!')),
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
    // Check if file exists
    final file = File(pdfPath);
    
    if (!file.existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'PDF Document',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to view full document',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[200],
      child: SfPdfViewer.file(
        file,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
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
                const Icon(
                  Icons.picture_as_pdf,
                  size: 48,
                  color: Colors.white,
                ),
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
