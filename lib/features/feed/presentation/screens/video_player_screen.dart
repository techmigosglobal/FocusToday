import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/media_cache_service.dart';
import '../../../../shared/models/post.dart';

/// Video Player Screen — Optimized for smooth playback
/// Uses ValueNotifier instead of setState for position updates
class VideoPlayerScreen extends StatefulWidget {
  final Post post;

  const VideoPlayerScreen({super.key, required this.post});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const double _largeScreenShortestSideDp = 600;

  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  String? _error;
  bool _appliedOrientationLock = false;

  // Use ValueNotifier for high-frequency updates to avoid full rebuilds
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _configureOrientationLock();
    });
    _initializeVideo();
  }

  Future<void> _configureOrientationLock() async {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final isLargeScreen = shortestSide >= _largeScreenShortestSideDp;
    if (isLargeScreen) {
      _appliedOrientationLock = false;
      return;
    }

    _appliedOrientationLock = true;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.post.mediaUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      setState(() => _error = 'No video URL available');
      return;
    }

    try {
      VideoPlayerController? controller;

      // Prefer cached local file if available for faster startup.
      final cachedFile = await MediaCacheService.getCachedFile(videoUrl);
      if (cachedFile != null) {
        try {
          controller = VideoPlayerController.file(
            cachedFile,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await controller.initialize();
        } catch (_) {
          await controller?.dispose();
          controller = null;
        }
      }

      controller ??= VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await _controller.initialize();
      if (!mounted) return;

      setState(() => _isInitialized = true);

      _controller.addListener(_onVideoUpdate);
      _controller.play();

      // Warm disk cache for smoother replays/reopens.
      MediaCacheService.warmInBackground(videoUrl);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load video: $e');
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    _position.value = _controller.value.position;
    _isPlaying.value = _controller.value.isPlaying;
    _isBuffering.value = _controller.value.isBuffering;
  }

  @override
  void dispose() {
    if (_appliedOrientationLock) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    if (_isInitialized) {
      _controller.removeListener(_onVideoUpdate);
      _controller.dispose();
    }
    _position.dispose();
    _isPlaying.dispose();
    _isBuffering.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video content
            if (_error != null)
              _buildErrorView()
            else if (!_isInitialized)
              _buildLoadingView()
            else
              GestureDetector(
                onTap: _toggleControls,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),

            // Buffering overlay
            if (_isInitialized)
              ValueListenableBuilder<bool>(
                valueListenable: _isBuffering,
                builder: (_, buffering, _) => buffering
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 3,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

            // Controls overlay
            if (_showControls && _isInitialized) _buildControls(),

            // Back button (always visible)
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),

            // Title overlay
            if (_showControls)
              Positioned(
                top: 8,
                left: 60,
                right: 60,
                child: Text(
                  widget.post.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Unknown error',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _error = null;
                _isInitialized = false;
              });
              _initializeVideo();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final totalMs = _controller.value.duration.inMilliseconds.toDouble();

    return Container(
      color: Colors.black38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Play/Pause button — uses ValueListenableBuilder
          ValueListenableBuilder<bool>(
            valueListenable: _isPlaying,
            builder: (_, playing, _) => GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Progress bar — uses ValueListenableBuilder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ValueListenableBuilder<Duration>(
              valueListenable: _position,
              builder: (_, pos, _) => Row(
                children: [
                  Text(
                    _formatDuration(pos),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: totalMs > 0
                          ? pos.inMilliseconds.toDouble().clamp(0.0, totalMs)
                          : 0.0,
                      max: totalMs > 0 ? totalMs : 1.0,
                      onChanged: (value) {
                        _controller.seekTo(
                          Duration(milliseconds: value.toInt()),
                        );
                      },
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.white30,
                    ),
                  ),
                  Text(
                    _formatDuration(_controller.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
