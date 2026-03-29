import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/media_thumbnail_service.dart';

/// PDF thumbnail using a cached first-page image for low-lag feed rendering.
class PdfThumbnail extends StatefulWidget {
  final String pdfUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String label;

  const PdfThumbnail({
    super.key,
    required this.pdfUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.label = 'PDF',
  });

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  static final Map<String, File?> _resolvedCache = <String, File?>{};
  static final Map<String, Future<File?>> _futureCache =
      <String, Future<File?>>{};

  late Future<File?> _thumbFuture;
  // Track the URL the future was built for so we can detect real changes.
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.pdfUrl;
    final cached = _resolvedCache[_currentUrl];
    if (cached != null) {
      _thumbFuture = SynchronousFuture<File?>(cached);
    } else {
      _thumbFuture = _loadThumbnail(widget.pdfUrl);
    }
  }

  @override
  void didUpdateWidget(covariant PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfUrl != widget.pdfUrl) {
      _currentUrl = widget.pdfUrl;
      // Call setState so the FutureBuilder gets a new future and rebuilds.
      setState(() {
        final cached = _resolvedCache[_currentUrl];
        _thumbFuture = cached != null
            ? SynchronousFuture<File?>(cached)
            : _loadThumbnail(widget.pdfUrl);
      });
    }
  }

  Future<File?> _loadThumbnail(String url) {
    final existingFuture = _futureCache[url];
    if (existingFuture != null) return existingFuture;

    final future =
        MediaThumbnailService.getThumbnail(
          mediaUrl: url,
          type: MediaThumbnailType.pdf,
        ).then(
          (file) {
            if (file != null) {
              _resolvedCache[url] = file;
            }
            _futureCache.remove(url);
            return file;
          },
          onError: (error) {
            _futureCache.remove(url);
            throw error;
          },
        );
    _futureCache[url] = future;
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Use the URL as a key so FutureBuilder is forced to restart when
            // the URL changes — prevents stale snapshots from previous futures.
            FutureBuilder<File?>(
              key: ValueKey(_currentUrl),
              future: _thumbFuture,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file != null) {
                  return Image.file(
                    file,
                    fit: widget.fit,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    // Use a key based on file path so Image widget refreshes
                    // when a new thumbnail file is generated for the same URL.
                    key: ValueKey(file.path),
                  );
                }
                return _buildPlaceholder(
                  isLoading: snapshot.connectionState != ConnectionState.done,
                );
              },
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(230),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder({required bool isLoading}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minSide = constraints.biggest.shortestSide;
        final compact = minSide <= 130;
        final iconSize = compact ? 28.0 : 48.0;
        final circlePadding = compact ? 10.0 : 20.0;
        final badgeText = isLoading
            ? (compact ? 'PDF...' : 'Generating preview...')
            : widget.label;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE53935), Color(0xFFC62828), Color(0xFF8E0000)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _GridPatternPainter()),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(circlePadding),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          shape: BoxShape.circle,
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: iconSize,
                                height: iconSize,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: compact ? 2 : 2.5,
                                ),
                              )
                            : Icon(
                                Icons.picture_as_pdf_rounded,
                                size: iconSize,
                                color: Colors.white,
                              ),
                      ),
                      SizedBox(height: compact ? 6 : 12),
                      if (!compact)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badgeText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
