import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/meeting.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../meetings/data/repositories/meeting_repository.dart';
import '../screens/meeting_detail_screen.dart';

/// Public screen to view the list of upcoming meetings.
class MeetingsListScreen extends StatefulWidget {
  final User currentUser;

  const MeetingsListScreen({super.key, required this.currentUser});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen> {
  final MeetingRepository _repo = MeetingRepository();
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  final Set<int> _interestInFlight = <int>{};

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    // Admins can query full paginated listings; other roles use public active feed.
    if (widget.currentUser.canModerate) {
      final result = await _repo.getAllMeetings(
        page: 1,
        limit: 50,
        status: null,
      );
      if (!mounted) return;
      setState(() {
        _meetings = result.meetings;
        _isLoading = false;
      });
      return;
    }

    final meetings = await _repo.getUpcomingMeetings(widget.currentUser.id);
    if (!mounted) return;
    setState(() {
      _meetings = meetings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(
      AppLanguage.fromCode(Localizations.localeOf(context).languageCode),
    );
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(localizations.allMeetings),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadMeetings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _meetings.length,
                itemBuilder: (ctx, i) =>
                    _buildMeetingCard(_meetings[i], localizations),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget.noMeetings();
  }

  Widget _buildMeetingCard(Meeting meeting, AppLocalizations localizations) {
    // Reusing logic from MeetingPopup or creating a consistent card
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          SmoothPageRoute(
            builder: (_) => MeetingDetailScreen.forUser(
              meeting: meeting,
              currentUser: widget.currentUser,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meeting.imageUrl != null && meeting.imageUrl!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 168,
                child: CachedNetworkImage(
                  imageUrl: meeting.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: AppColors.surfaceOf(context),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.surfaceOf(context),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: meeting.isToday ? AppColors.accent : AppColors.primary,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.onPrimaryOf(context),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    meeting.formattedDate,
                    style: TextStyle(
                      color: AppColors.onPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (meeting.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      meeting.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                          meeting.venue,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _interestInFlight.contains(meeting.id)
                            ? null
                            : () => _toggleInterest(meeting),
                        icon: Icon(
                          meeting.isInterested
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          meeting.isInterested
                              ? localizations.interested
                              : localizations.interestedQuestion,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: meeting.isInterested
                              ? AppColors.primary
                              : null,
                          foregroundColor: meeting.isInterested
                              ? AppColors.onPrimaryOf(context)
                              : null,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _interestInFlight.contains(meeting.id)
                            ? null
                            : () => _toggleNotInterested(meeting),
                        icon: Icon(
                          meeting.isNotInterested
                              ? Icons.thumb_down_rounded
                              : Icons.thumb_down_alt_outlined,
                          size: 18,
                        ),
                        label: Text(localizations.notInterestedLabel),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: meeting.isNotInterested
                              ? AppColors.destructiveFgOf(context)
                              : AppColors.textSecondaryOf(context),
                          side: BorderSide(
                            color: meeting.isNotInterested
                                ? AppColors.destructiveFgOf(
                                    context,
                                  ).withValues(alpha: 0.45)
                                : AppColors.dividerOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        localizations.interestedCountLabel(
                          meeting.interestCount,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      Text(
                        localizations.notInterestedCountLabel(
                          meeting.notInterestedCount,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleInterest(Meeting meeting) async {
    HapticFeedback.selectionClick();
    final index = _meetings.indexWhere((m) => m.id == meeting.id);
    if (index < 0) return;
    final previous = _meetings[index];
    final optimistic = previous.isInterested
        ? _applyInterestState(
            previous,
            isInterested: false,
            isNotInterested: false,
          )
        : _applyInterestState(
            previous,
            isInterested: true,
            isNotInterested: false,
          );

    setState(() {
      _interestInFlight.add(meeting.id);
      _meetings[index] = optimistic;
    });

    final result = await _repo.toggleInterest(
      meeting.id,
      widget.currentUser.id,
    );
    if (!mounted) return;
    setState(() {
      _interestInFlight.remove(meeting.id);
      if (!result.isSuccess) {
        _meetings[index] = previous;
      } else {
        _meetings[index] = _applyFromResult(previous, result.state);
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
    HapticFeedback.selectionClick();
    final index = _meetings.indexWhere((m) => m.id == meeting.id);
    if (index < 0) return;
    final previous = _meetings[index];
    final optimistic = previous.isNotInterested
        ? _applyInterestState(
            previous,
            isInterested: false,
            isNotInterested: false,
          )
        : _applyInterestState(
            previous,
            isInterested: false,
            isNotInterested: true,
          );

    setState(() {
      _interestInFlight.add(meeting.id);
      _meetings[index] = optimistic;
    });

    final result = await _repo.toggleNotInterested(
      meeting.id,
      widget.currentUser.id,
    );
    if (!mounted) return;
    setState(() {
      _interestInFlight.remove(meeting.id);
      if (!result.isSuccess) {
        _meetings[index] = previous;
      } else {
        _meetings[index] = _applyFromResult(previous, result.state);
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

  Meeting _applyFromResult(Meeting base, MeetingInterestState state) {
    switch (state) {
      case MeetingInterestState.interested:
        return _applyInterestState(
          base,
          isInterested: true,
          isNotInterested: false,
        );
      case MeetingInterestState.notInterested:
        return _applyInterestState(
          base,
          isInterested: false,
          isNotInterested: true,
        );
      case MeetingInterestState.none:
        return _applyInterestState(
          base,
          isInterested: false,
          isNotInterested: false,
        );
      case MeetingInterestState.failed:
        return base;
    }
  }

  Meeting _applyInterestState(
    Meeting base, {
    required bool isInterested,
    required bool isNotInterested,
  }) {
    final nextInterestedCount =
        (base.interestCount -
                (base.isInterested ? 1 : 0) +
                (isInterested ? 1 : 0))
            .clamp(0, 1 << 30);
    final nextNotInterestedCount =
        (base.notInterestedCount -
                (base.isNotInterested ? 1 : 0) +
                (isNotInterested ? 1 : 0))
            .clamp(0, 1 << 30);
    return base.copyWith(
      isInterested: isInterested,
      isNotInterested: isNotInterested,
      interestCount: nextInterestedCount,
      notInterestedCount: nextNotInterestedCount,
    );
  }
}
