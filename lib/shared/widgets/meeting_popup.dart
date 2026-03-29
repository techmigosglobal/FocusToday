import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/language_service.dart';
import 'page_transitions.dart';
import '../models/meeting.dart';
import '../models/user.dart';
import '../../features/meetings/data/repositories/meeting_repository.dart';
import '../../features/meetings/presentation/screens/meetings_list_screen.dart';

/// Meeting Popup — Hybrid Option C
///
/// 1 meeting  → Single rich card with auto-close after 5s
/// 2-4 meetings → Swipeable PageView with auto-close after 8s
/// 5+ meetings → Compact list with "View All" and auto-close after 12s
///
/// "Interested" button tracks engagement.
/// Marks all displayed meetings as "seen" so popup won't re-show.
class MeetingPopup {
  static final MeetingRepository _repo = MeetingRepository();

  /// Show the meeting popup if there are unseen upcoming meetings.
  /// Call this from FeedScreen after initial data loads.
  static Future<void> showIfNeeded(
    BuildContext context, {
    required User currentUser,
    required String langCode,
  }) async {
    try {
      final meetings = await _repo.getUnseenMeetings(currentUser.id);
      if (meetings.isEmpty) return;
      if (!context.mounted) return;

      // Mark as seen immediately
      final meetingIds = meetings.map((m) => m.id).toList();
      _repo.markAsSeen(meetingIds, currentUser.id);

      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Meeting Popup',
        barrierColor: AppColors.overlayStrongOf(context),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (ctx, anim1, anim2) {
          return _MeetingPopupContent(
            meetings: meetings,
            currentUser: currentUser,
            langCode: langCode,
          );
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curve = CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          );
          return ScaleTransition(
            scale: curve,
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
      );
    } catch (e) {
      debugPrint('[MeetingPopup] Error: $e');
    }
  }
}

class _MeetingPopupContent extends StatefulWidget {
  final List<Meeting> meetings;
  final User currentUser;
  final String langCode;

  const _MeetingPopupContent({
    required this.meetings,
    required this.currentUser,
    required this.langCode,
  });

  @override
  State<_MeetingPopupContent> createState() => _MeetingPopupContentState();
}

class _MeetingPopupContentState extends State<_MeetingPopupContent> {
  late Timer _autoCloseTimer;
  late int _autoCloseDuration;
  late int _remainingSeconds;
  final MeetingRepository _repo = MeetingRepository();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Track interest state locally for immediate UI feedback
  late Map<int, bool> _interestedMap;
  late Map<int, bool> _notInterestedMap;
  late Map<int, int> _interestCounts;
  late Map<int, int> _notInterestedCounts;
  final Set<int> _inFlightIds = <int>{};

  @override
  void initState() {
    super.initState();
    _interestedMap = {for (final m in widget.meetings) m.id: m.isInterested};
    _notInterestedMap = {
      for (final m in widget.meetings) m.id: m.isNotInterested,
    };
    _interestCounts = {for (final m in widget.meetings) m.id: m.interestCount};
    _notInterestedCounts = {
      for (final m in widget.meetings) m.id: m.notInterestedCount,
    };

    // Auto-close durations based on count
    if (widget.meetings.length == 1) {
      _autoCloseDuration = 5;
    } else if (widget.meetings.length <= 4) {
      _autoCloseDuration = 8;
    } else {
      _autoCloseDuration = 12;
    }
    _remainingSeconds = _autoCloseDuration;

    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleInterest(Meeting meeting) async {
    if (_inFlightIds.contains(meeting.id)) return;
    HapticFeedback.mediumImpact();
    final previousInterested = _interestedMap[meeting.id] ?? false;
    final previousNotInterested = _notInterestedMap[meeting.id] ?? false;
    final previousInterestedCount = _interestCounts[meeting.id] ?? 0;
    final previousNotInterestedCount = _notInterestedCounts[meeting.id] ?? 0;
    final targetInterested = !previousInterested;
    final targetNotInterested = false;

    setState(() {
      _inFlightIds.add(meeting.id);
      _applyUiState(
        meeting.id,
        isInterested: targetInterested,
        isNotInterested: targetNotInterested,
      );
    });

    final result = await _repo.toggleInterest(
      meeting.id,
      widget.currentUser.id,
    );
    if (!mounted) return;
    setState(() {
      _inFlightIds.remove(meeting.id);
      if (!result.isSuccess) {
        _interestedMap[meeting.id] = previousInterested;
        _notInterestedMap[meeting.id] = previousNotInterested;
        _interestCounts[meeting.id] = previousInterestedCount;
        _notInterestedCounts[meeting.id] = previousNotInterestedCount;
      } else {
        _applyUiStateFromResult(meeting.id, result.state);
      }
    });
    if (!result.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update interest. Please try again.'),
        ),
      );
    }
  }

  Future<void> _toggleNotInterested(Meeting meeting) async {
    if (_inFlightIds.contains(meeting.id)) return;
    HapticFeedback.mediumImpact();
    final previousInterested = _interestedMap[meeting.id] ?? false;
    final previousNotInterested = _notInterestedMap[meeting.id] ?? false;
    final previousInterestedCount = _interestCounts[meeting.id] ?? 0;
    final previousNotInterestedCount = _notInterestedCounts[meeting.id] ?? 0;
    final targetNotInterested = !previousNotInterested;
    final targetInterested = false;

    setState(() {
      _inFlightIds.add(meeting.id);
      _applyUiState(
        meeting.id,
        isInterested: targetInterested,
        isNotInterested: targetNotInterested,
      );
    });

    final result = await _repo.toggleNotInterested(
      meeting.id,
      widget.currentUser.id,
    );
    if (!mounted) return;
    setState(() {
      _inFlightIds.remove(meeting.id);
      if (!result.isSuccess) {
        _interestedMap[meeting.id] = previousInterested;
        _notInterestedMap[meeting.id] = previousNotInterested;
        _interestCounts[meeting.id] = previousInterestedCount;
        _notInterestedCounts[meeting.id] = previousNotInterestedCount;
      } else {
        _applyUiStateFromResult(meeting.id, result.state);
      }
    });
    if (!result.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update response. Please try again.'),
        ),
      );
    }
  }

  void _applyUiStateFromResult(int meetingId, MeetingInterestState state) {
    switch (state) {
      case MeetingInterestState.interested:
        _applyUiState(meetingId, isInterested: true, isNotInterested: false);
        break;
      case MeetingInterestState.notInterested:
        _applyUiState(meetingId, isInterested: false, isNotInterested: true);
        break;
      case MeetingInterestState.none:
        _applyUiState(meetingId, isInterested: false, isNotInterested: false);
        break;
      case MeetingInterestState.failed:
        break;
    }
  }

  void _applyUiState(
    int meetingId, {
    required bool isInterested,
    required bool isNotInterested,
  }) {
    final oldInterested = _interestedMap[meetingId] ?? false;
    final oldNotInterested = _notInterestedMap[meetingId] ?? false;
    final nextInterestedCount =
        ((_interestCounts[meetingId] ?? 0) -
                (oldInterested ? 1 : 0) +
                (isInterested ? 1 : 0))
            .clamp(0, 1 << 30);
    final nextNotInterestedCount =
        ((_notInterestedCounts[meetingId] ?? 0) -
                (oldNotInterested ? 1 : 0) +
                (isNotInterested ? 1 : 0))
            .clamp(0, 1 << 30);

    _interestedMap[meetingId] = isInterested;
    _notInterestedMap[meetingId] = isNotInterested;
    _interestCounts[meetingId] = nextInterestedCount;
    _notInterestedCounts[meetingId] = nextNotInterestedCount;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.meetings.length;
    final width = MediaQuery.of(context).size.width;

    return Center(
      child: Material(
        color: AppColors.backgroundOf(context).withValues(alpha: 0),
        child: Container(
          width: width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.overlayStrongOf(context),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),

              // Content based on meeting count
              if (count == 1)
                _buildSingleCard(widget.meetings.first)
              else if (count <= 4)
                _buildSwipeableCards()
              else
                _buildCompactList(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_rounded,
              color: AppColors.toastText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations(
                    AppLanguage.fromCode(widget.langCode),
                  ).upcomingMeetings,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                Text(
                  '${widget.meetings.length} ${AppLocalizations(AppLanguage.fromCode(widget.langCode)).eventsComingUp}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          // Auto-close countdown
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: _remainingSeconds / _autoCloseDuration,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textSecondaryOf(context).withValues(alpha: 0.3),
                    ),
                    backgroundColor: AppColors.backgroundOf(
                      context,
                    ).withValues(alpha: 0),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Single Card (1 Meeting) ====================
  Widget _buildSingleCard(Meeting meeting) {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _MeetingCard(
          meeting: meeting,
          langCode: widget.langCode,
          isInterested: _interestedMap[meeting.id] ?? false,
          isNotInterested: _notInterestedMap[meeting.id] ?? false,
          interestCount: _interestCounts[meeting.id] ?? 0,
          notInterestedCount: _notInterestedCounts[meeting.id] ?? 0,
          onToggleInterest: () => _toggleInterest(meeting),
          onToggleNotInterested: () => _toggleNotInterested(meeting),
          isBusy: _inFlightIds.contains(meeting.id),
          isExpanded: true,
        ),
      ),
    );
  }

  // ==================== Swipeable (2-4 Meetings) ====================
  Widget _buildSwipeableCards() {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 260,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.meetings.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _currentPage = i);
              },
              itemBuilder: (ctx, i) {
                final meeting = widget.meetings[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MeetingCard(
                    meeting: meeting,
                    langCode: widget.langCode,
                    isInterested: _interestedMap[meeting.id] ?? false,
                    isNotInterested: _notInterestedMap[meeting.id] ?? false,
                    interestCount: _interestCounts[meeting.id] ?? 0,
                    notInterestedCount: _notInterestedCounts[meeting.id] ?? 0,
                    onToggleInterest: () => _toggleInterest(meeting),
                    onToggleNotInterested: () => _toggleNotInterested(meeting),
                    isBusy: _inFlightIds.contains(meeting.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.meetings.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? AppColors.primary
                      : AppColors.textSecondaryOf(
                          context,
                        ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Compact List (5+ Meetings) ====================
  Widget _buildCompactList() {
    final displayList = widget.meetings.take(4).toList();
    final remaining = widget.meetings.length - 4;

    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayList.length + (remaining > 0 ? 1 : 0),
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: AppColors.dividerOf(context)),
        itemBuilder: (ctx, i) {
          if (i == displayList.length) {
            // "View All" row
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      SmoothPageRoute(
                        builder: (_) =>
                            MeetingsListScreen(currentUser: widget.currentUser),
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_note_rounded, size: 18),
                  label: Text(
                    '${AppLocalizations(AppLanguage.fromCode(widget.langCode)).viewAll} $remaining ${AppLocalizations(AppLanguage.fromCode(widget.langCode)).more}',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            );
          }

          final meeting = displayList[i];
          return _CompactMeetingRow(
            meeting: meeting,
            langCode: widget.langCode,
            isInterested: _interestedMap[meeting.id] ?? false,
            isNotInterested: _notInterestedMap[meeting.id] ?? false,
            onToggleInterest: () => _toggleInterest(meeting),
            onToggleNotInterested: () => _toggleNotInterested(meeting),
            isBusy: _inFlightIds.contains(meeting.id),
          );
        },
      ),
    );
  }
}

// ==================== Meeting Card Widget ====================
class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final String langCode;
  final bool isInterested;
  final bool isNotInterested;
  final int interestCount;
  final int notInterestedCount;
  final VoidCallback onToggleInterest;
  final VoidCallback onToggleNotInterested;
  final bool isBusy;
  final bool isExpanded;

  const _MeetingCard({
    required this.meeting,
    required this.langCode,
    required this.isInterested,
    required this.isNotInterested,
    required this.interestCount,
    required this.notInterestedCount,
    required this.onToggleInterest,
    required this.onToggleNotInterested,
    this.isBusy = false,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDarkElevated
            : AppColors.surfaceTier2Of(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: meeting.isToday
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.dividerOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: meeting.isToday
                    ? [
                        AppColors.accent,
                        AppColors.accent.withValues(alpha: 0.8),
                      ]
                    : [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.onPrimaryOf(context),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  meeting.isToday
                      ? AppLocalizations(AppLanguage.fromCode(langCode)).today
                      : meeting.isTomorrow
                      ? AppLocalizations(
                          AppLanguage.fromCode(langCode),
                        ).tomorrow
                      : meeting.formattedDate,
                  style: TextStyle(
                    color: AppColors.onPrimaryOf(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time_rounded,
                  color: AppColors.onPrimaryOf(context).withValues(alpha: 0.8),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  meeting.formattedTime,
                  style: TextStyle(
                    color: AppColors.onPrimaryOf(
                      context,
                    ).withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.localizedTitle(langCode),
                  style: TextStyle(
                    fontSize: isExpanded ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: isExpanded ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (meeting.localizedDescription(langCode) != null &&
                    meeting.localizedDescription(langCode)!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    meeting.localizedDescription(langCode)!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                      height: 1.4,
                    ),
                    maxLines: isExpanded ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Venue
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        meeting.localizedVenue(langCode),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Interested/Not Interested buttons + counts
                Row(
                  children: [
                    _InterestButton(
                      isInterested: isInterested,
                      onTap: isBusy ? null : onToggleInterest,
                    ),
                    const SizedBox(width: 8),
                    _NotInterestButton(
                      isNotInterested: isNotInterested,
                      onTap: isBusy ? null : onToggleNotInterested,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$interestCount ${AppLocalizations(AppLanguage.fromCode(langCode)).interested}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$notInterestedCount not interested',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const Spacer(),
                    if (meeting.daysUntil > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${meeting.daysUntil}d away',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Interest Button ====================
class _InterestButton extends StatelessWidget {
  final bool isInterested;
  final VoidCallback? onTap;

  const _InterestButton({required this.isInterested, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isInterested
              ? AppColors.primary
              : AppColors.textSecondaryOf(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: isInterested
              ? null
              : Border.all(
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.3),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInterested ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 16,
              color: isInterested
                  ? AppColors.onPrimaryOf(context)
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 4),
            Text(
              isInterested
                  ? AppLocalizations(
                      AppLanguage.fromCode(
                        Localizations.localeOf(context).languageCode,
                      ),
                    ).interested
                  : '${AppLocalizations(AppLanguage.fromCode(Localizations.localeOf(context).languageCode)).interested}?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isInterested
                    ? AppColors.onPrimaryOf(context)
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotInterestButton extends StatelessWidget {
  final bool isNotInterested;
  final VoidCallback? onTap;

  const _NotInterestButton({
    required this.isNotInterested,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isNotInterested
              ? AppColors.destructiveFgOf(context)
              : AppColors.textSecondaryOf(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: isNotInterested
              ? null
              : Border.all(
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.3),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNotInterested
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_alt_outlined,
              size: 16,
              color: isNotInterested
                  ? AppColors.onPrimaryOf(context)
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 4),
            Text(
              'Not interested',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isNotInterested
                    ? AppColors.onPrimaryOf(context)
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Compact Meeting Row (5+ meetings) ====================
class _CompactMeetingRow extends StatelessWidget {
  final Meeting meeting;
  final String langCode;
  final bool isInterested;
  final bool isNotInterested;
  final VoidCallback onToggleInterest;
  final VoidCallback onToggleNotInterested;
  final bool isBusy;

  const _CompactMeetingRow({
    required this.meeting,
    required this.langCode,
    required this.isInterested,
    required this.isNotInterested,
    required this.onToggleInterest,
    required this.onToggleNotInterested,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Date chip
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: meeting.isToday
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : isDark
                  ? AppColors.primaryOf(context).withValues(alpha: 0.28)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  meeting.isToday
                      ? AppLocalizations(AppLanguage.fromCode(langCode)).today
                      : '${meeting.meetingDate.day}',
                  style: TextStyle(
                    fontSize: meeting.isToday ? 8 : 18,
                    fontWeight: FontWeight.bold,
                    color: meeting.isToday
                        ? AppColors.accent
                        : isDark
                        ? AppColors.onPrimaryOf(context)
                        : AppColors.primary,
                  ),
                ),
                if (!meeting.isToday)
                  Text(
                    [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec',
                    ][meeting.meetingDate.month - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.onPrimaryOf(context)
                          : AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.localizedTitle(langCode),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${meeting.formattedTime} • ${meeting.localizedVenue(langCode)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isBusy ? null : onToggleInterest,
            child: Icon(
              isInterested ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isInterested
                  ? AppColors.accent
                  : AppColors.textSecondaryOf(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isBusy ? null : onToggleNotInterested,
            child: Icon(
              isNotInterested
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_alt_outlined,
              color: isNotInterested
                  ? AppColors.destructiveFgOf(context)
                  : AppColors.textSecondaryOf(context),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
