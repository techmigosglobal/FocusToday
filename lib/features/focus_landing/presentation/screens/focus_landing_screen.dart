import 'package:flutter/material.dart';
import 'dart:async';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/ux_telemetry_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/optimized_image.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../meetings/presentation/screens/meetings_list_screen.dart';
import '../../data/models/focus_landing_content.dart';
import '../../data/repositories/focus_landing_repository.dart';
import 'landing_content_management_screen.dart';

class FocusLandingScreen extends StatefulWidget {
  final User currentUser;
  final AppLanguage currentLanguage;
  final bool autoMode;
  final bool showSkipButton;
  final int autoCloseSeconds;

  const FocusLandingScreen({
    super.key,
    required this.currentUser,
    required this.currentLanguage,
    this.autoMode = false,
    this.showSkipButton = false,
    this.autoCloseSeconds = 4,
  });

  @override
  State<FocusLandingScreen> createState() => _FocusLandingScreenState();
}

class _FocusLandingScreenState extends State<FocusLandingScreen> {
  final FocusLandingRepository _repo = FocusLandingRepository();
  final UxTelemetryService _telemetry = UxTelemetryService.instance;

  FocusLandingContent _content = FocusLandingContent.defaults();
  bool _isLoading = true;
  Timer? _autoDismissTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoMode) {
      _startAutoDismissTimer();
    }
    _loadContent();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startAutoDismissTimer() {
    final seconds = widget.autoCloseSeconds.clamp(3, 15);
    _secondsLeft = seconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
      }
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 60));
    });
    _autoDismissTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  Future<void> _loadContent({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final content = await _repo.getContent(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _content = content;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLanguage);

    final contentBody = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _loadContent(forceRefresh: true),
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                widget.autoMode ? 76 : 16,
                16,
                16,
              ),
              children: [
                ..._buildSectionLayout(context),
                const SizedBox(height: 12),
                _animatedEntry(
                  index: 50,
                  child: _buildInteractiveCtaCard(context, localizations),
                ),
                const SizedBox(height: 18),
                _animatedEntry(
                  index: 51,
                  child: _buildMaintainedByFooter(context),
                ),
              ],
            ),
          );

    if (widget.autoMode) {
      return Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.28),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundOf(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(child: contentBody),
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          children: [
                            if (_secondsLeft > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceTier2Of(context),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.dividerOf(context),
                                  ),
                                ),
                                child: Text(
                                  'Auto close in $_secondsLeft s',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            if (widget.showSkipButton)
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.skip_next_rounded),
                                label: const Text('Skip'),
                              ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Focus Today'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
      ),
      body: SafeArea(child: contentBody),
    );
  }

  Widget _animatedEntry({required int index, required Widget child}) {
    final delayMs = index * 80;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + delayMs),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, c) {
        final dy = (1 - value) * 14;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, dy), child: c),
        );
      },
      child: child,
    );
  }

  Widget _buildHero(BuildContext context) {
    final shouldShowImage =
        _content.showHeroImage && _content.heroImageUrl.trim().isNotEmpty;

    if (!shouldShowImage) {
      return _fallbackHero(context, height: 186);
    }

    return _AdaptiveLandingImage(
      imageUrl: _content.heroImageUrl,
      cacheBuster: _content.updatedAt?.millisecondsSinceEpoch.toString(),
      heroTag: 'landing_hero',
      height: 212,
      fallback: _fallbackHero(context, height: 186),
      surfaceColor: AppColors.surfaceOf(context),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return _contentCard(
      context: context,
      title: _content.localizedIntroTitle(widget.currentLanguage),
      body: _content.localizedIntroBody(widget.currentLanguage),
      icon: Icons.waving_hand_rounded,
    );
  }

  Widget _buildSecondaryCard(BuildContext context) {
    final hasImage = _content.secondaryImageUrl.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contentCard(
          context: context,
          title: _content.localizedSecondaryTitle(widget.currentLanguage),
          body: _content.localizedSecondaryBody(widget.currentLanguage),
          icon: Icons.explore_rounded,
        ),
        if (hasImage) ...[
          const SizedBox(height: 12),
          _AdaptiveLandingImage(
            imageUrl: _content.secondaryImageUrl,
            cacheBuster: _content.updatedAt?.millisecondsSinceEpoch.toString(),
            heroTag: 'landing_secondary',
            height: 178,
            fallback: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surfaceTier2Of(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.dividerOf(context)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            surfaceColor: AppColors.surfaceOf(context),
          ),
        ],
      ],
    );
  }

  Widget _buildTertiaryCard(BuildContext context) {
    final hasImage = _content.tertiaryImageUrl.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contentCard(
          context: context,
          title: _content.localizedTertiaryTitle(widget.currentLanguage),
          body: _content.localizedTertiaryBody(widget.currentLanguage),
          icon: Icons.layers_rounded,
        ),
        if (hasImage) ...[
          const SizedBox(height: 12),
          _AdaptiveLandingImage(
            imageUrl: _content.tertiaryImageUrl,
            cacheBuster: _content.updatedAt?.millisecondsSinceEpoch.toString(),
            heroTag: 'landing_tertiary',
            height: 178,
            fallback: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surfaceTier2Of(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.dividerOf(context)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            surfaceColor: AppColors.surfaceOf(context),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildSectionLayout(BuildContext context) {
    final widgets = <Widget>[];
    if (_content.showHeroImage) {
      widgets.add(_animatedEntry(index: 0, child: _buildHero(context)));
      widgets.add(const SizedBox(height: 16));
      widgets.add(_animatedEntry(index: 1, child: _buildIntroCard(context)));
    }
    if (_content.showSecondarySection) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
      widgets.add(
        _animatedEntry(index: 2, child: _buildSecondaryCard(context)),
      );
    }
    if (_content.showTertiarySection) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
      widgets.add(_animatedEntry(index: 3, child: _buildTertiaryCard(context)));
    }
    if (widgets.isEmpty) {
      widgets.add(
        _animatedEntry(index: 0, child: _fallbackHero(context, height: 186)),
      );
    }
    return widgets;
  }

  Widget _buildInteractiveCtaCard(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final isModerator = widget.currentUser.canModerate;
    final title = isModerator
        ? localizations.manageLandingContent
        : localizations.upcomingEvents;
    final subtitle = isModerator
        ? 'Edit landing sections, images, and regional language copy instantly.'
        : 'Explore civic events and public meetings happening near you.';
    final icon = isModerator ? Icons.edit_rounded : Icons.event_rounded;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.accent.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => isModerator
              ? _openLandingContentManagement()
              : _openUpcomingEvents(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryOf(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primaryOf(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLandingContentManagement() async {
    await _telemetry.trackNavigation(
      user: widget.currentUser,
      screen: 'focus_landing',
      destination: 'landing_content_management',
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) => LandingContentManagementScreen(
          currentUser: widget.currentUser,
          currentLanguage: widget.currentLanguage,
        ),
      ),
    );
    _loadContent(forceRefresh: true);
  }

  Future<void> _openUpcomingEvents() async {
    await _telemetry.trackNavigation(
      user: widget.currentUser,
      screen: 'focus_landing',
      destination: 'upcoming_events',
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) => MeetingsListScreen(currentUser: widget.currentUser),
      ),
    );
  }

  Widget _contentCard({
    required BuildContext context,
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryOf(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackHero(BuildContext context, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.public_rounded,
        color: AppColors.onPrimaryOf(context),
        size: 46,
      ),
    );
  }

  Widget _buildMaintainedByFooter(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceTier2Of(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.dividerOf(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceOf(context),
                border: Border.all(color: AppColors.dividerOf(context)),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/TMFT.png',
                  width: 9,
                  height: 9,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.verified_rounded,
                    size: 9,
                    color: AppColors.primaryOf(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Maintained by TechMigos',
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdaptiveLandingImage extends StatefulWidget {
  final String imageUrl;
  final String? cacheBuster;
  final String heroTag;
  final double height;
  final Widget fallback;
  final Color surfaceColor;

  const _AdaptiveLandingImage({
    required this.imageUrl,
    this.cacheBuster,
    required this.heroTag,
    required this.height,
    required this.fallback,
    required this.surfaceColor,
  });

  @override
  State<_AdaptiveLandingImage> createState() => _AdaptiveLandingImageState();
}

class _AdaptiveLandingImageState extends State<_AdaptiveLandingImage> {
  static const double _defaultAspectRatio = 16 / 9;
  static const double _minAspectRatio = 0.65;
  static const double _maxAspectRatio = 2.4;
  static const double _minCardHeight = 140;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveImageRatio();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveLandingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheBuster != widget.cacheBuster) {
      _aspectRatio = null;
      _resolveImageRatio();
    }
  }

  bool _looksLikeLogo(String value) {
    final url = value.toLowerCase();
    return url.contains('logo') ||
        url.contains('icon') ||
        url.contains('brand') ||
        url.contains('tmft');
  }

  Future<void> _resolveImageRatio() async {
    if (_looksLikeLogo(widget.imageUrl)) {
      if (!mounted) return;
      setState(() => _aspectRatio = 1);
      return;
    }

    final provider = NetworkImage(
      OptimizedImage.resolveUrl(
        widget.imageUrl,
        cacheBuster: widget.cacheBuster,
      ),
    );
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo image, bool _) {
        final width = image.image.width.toDouble();
        final height = image.image.height.toDouble();
        final ratio = height == 0 ? _defaultAspectRatio : width / height;

        final boundedRatio = ratio.clamp(_minAspectRatio, _maxAspectRatio);

        if (mounted) {
          setState(() {
            _aspectRatio = boundedRatio;
          });
        }
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (mounted) {
          setState(() => _aspectRatio = _defaultAspectRatio);
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = (_aspectRatio ?? _defaultAspectRatio).clamp(
      _minAspectRatio,
      _maxAspectRatio,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openImageViewer(context),
        child: Container(
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dividerOf(context)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Hero(
                  tag: widget.heroTag,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth =
                          constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : MediaQuery.sizeOf(context).width - 32;
                      final dynamicHeight = (availableWidth / aspectRatio)
                          .clamp(_minCardHeight, widget.height + 120);
                      return SizedBox(
                        height: dynamicHeight,
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: OptimizedImage(
                            imageUrl: widget.imageUrl,
                            cacheBuster: widget.cacheBuster,
                            fit: BoxFit.contain,
                            width: availableWidth,
                            height: dynamicHeight,
                            placeholder: Container(
                              color: widget.surfaceColor,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: widget.fallback,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openImageViewer(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close image preview',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Hero(
                    tag: widget.heroTag,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: OptimizedImage(
                        imageUrl: widget.imageUrl,
                        cacheBuster: widget.cacheBuster,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: widget.fallback,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}
