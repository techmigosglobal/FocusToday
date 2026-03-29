import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/meeting.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/utils/english_content_normalizer.dart';
import '../../data/repositories/meeting_repository.dart';

/// Admin screen to manage public meetings.
/// Supports creating, editing, deleting, changing status, and configuring display_days.
class MeetingsManagementScreen extends StatefulWidget {
  final User currentUser;
  final AppLanguage currentLanguage;
  final int? initialEditMeetingId;

  const MeetingsManagementScreen({
    super.key,
    required this.currentUser,
    required this.currentLanguage,
    this.initialEditMeetingId,
  });

  @override
  State<MeetingsManagementScreen> createState() =>
      _MeetingsManagementScreenState();
}

class _MeetingsManagementScreenState extends State<MeetingsManagementScreen> {
  final MeetingRepository _repo = MeetingRepository();
  final MediaPickerService _mediaPicker = MediaPickerService();
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  int _page = 1;
  String? _statusFilter;
  bool _handledInitialEditDeepLink = false;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final result = await _repo.getAllMeetings(
      page: _page,
      limit: 20,
      status: _statusFilter,
    );
    if (!mounted) return;
    setState(() {
      _meetings = result.meetings;
      _isLoading = false;
    });
    await _openInitialEditDeepLinkIfNeeded();
  }

  Future<void> _openInitialEditDeepLinkIfNeeded() async {
    if (_handledInitialEditDeepLink) return;
    final meetingId = widget.initialEditMeetingId;
    if (meetingId == null || meetingId <= 0) return;
    _handledInitialEditDeepLink = true;

    Meeting? target;
    for (final meeting in _meetings) {
      if (meeting.id == meetingId) {
        target = meeting;
        break;
      }
    }
    target ??= await _repo.getMeetingById(meetingId);
    if (!mounted || target == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showMeetingForm(
        meeting: target,
        localizations: AppLocalizations(widget.currentLanguage),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLanguage);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(localizations.meetingsTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
        actions: [
          // Status filter
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (val) {
              _statusFilter = val;
              _page = 1;
              _loadMeetings();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(localizations.all)),
              PopupMenuItem(
                value: 'upcoming',
                child: Text(localizations.upcoming),
              ),
              PopupMenuItem(
                value: 'ongoing',
                child: Text(localizations.ongoing),
              ),
              PopupMenuItem(
                value: 'completed',
                child: Text(localizations.completed),
              ),
              PopupMenuItem(
                value: 'cancelled',
                child: Text(localizations.cancelled),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMeetingForm(localizations: localizations),
        icon: const Icon(Icons.add),
        label: Text(localizations.createMeeting),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
          ? _buildEmptyState(localizations)
          : RefreshIndicator(
              onRefresh: _loadMeetings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _meetings.length,
                itemBuilder: (ctx, i) =>
                    _buildMeetingTile(_meetings[i], localizations),
              ),
            ),
    );
  }

  Widget _buildEmptyState(AppLocalizations localizations) {
    return EmptyStateWidget.noMeetings(
      onCreate: () => _showMeetingForm(localizations: localizations),
    );
  }

  Widget _buildMeetingTile(Meeting meeting, AppLocalizations localizations) {
    final statusColor = _statusColor(meeting.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: AppColors.overlaySoftOf(context).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.surfaceOf(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            _showMeetingForm(meeting: meeting, localizations: localizations),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meeting.status.toStr().toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Display days config
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
                      '${meeting.displayDays} ${localizations.dayWindow}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Actions
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondaryOf(context),
                      size: 20,
                    ),
                    onSelected: (val) => _handleAction(val, meeting),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(localizations.edit),
                      ),
                      if (meeting.status == MeetingStatus.upcoming)
                        PopupMenuItem(
                          value: 'ongoing',
                          child: Text(localizations.markAsOngoing),
                        ),
                      if (meeting.status != MeetingStatus.completed)
                        PopupMenuItem(
                          value: 'completed',
                          child: Text(localizations.markAsCompleted),
                        ),
                      if (meeting.status != MeetingStatus.cancelled)
                        PopupMenuItem(
                          value: 'cancelled',
                          child: Text(localizations.cancel),
                        ),
                      PopupMenuItem(
                        value: 'interested',
                        child: Text(localizations.viewInterestedUsers),
                      ),
                      PopupMenuItem(
                        value: 'rsvps',
                        child: Text(localizations.viewRsvpResponses),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          localizations.delete,
                          style: TextStyle(
                            color: AppColors.destructiveFgOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                meeting.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${meeting.formattedDate} ${localizations.atLabel} ${meeting.formattedTime}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 2),
                  Text(
                    '${meeting.interestCount}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.thumb_down_alt_outlined,
                    size: 14,
                    color: AppColors.destructiveFgOf(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${meeting.notInterestedCount}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.destructiveFgOf(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.upcoming:
        return AppColors.primary;
      case MeetingStatus.ongoing:
        return AppColors.successOf(context);
      case MeetingStatus.completed:
        return AppColors.textSecondaryOf(context);
      case MeetingStatus.cancelled:
        return AppColors.destructiveFgOf(context);
    }
  }

  void _handleAction(String action, Meeting meeting) async {
    switch (action) {
      case 'edit':
        _showMeetingForm(
          meeting: meeting,
          localizations: AppLocalizations(widget.currentLanguage),
        );
        break;
      case 'ongoing':
      case 'completed':
      case 'cancelled':
        final confirmed = await _confirmDialog(
          AppLocalizations(widget.currentLanguage).changeStatus,
          AppLocalizations(widget.currentLanguage).setMeetingStatusTo(action),
        );
        if (confirmed) {
          await _repo.updateMeeting({'id': meeting.id, 'status': action});
          _loadMeetings();
        }
        break;
      case 'interested':
        _showInterestedUsers(meeting, AppLocalizations(widget.currentLanguage));
        break;
      case 'rsvps':
        _showRsvpResponses(meeting, AppLocalizations(widget.currentLanguage));
        break;
      case 'delete':
        final currentLocalizations = AppLocalizations(widget.currentLanguage);
        final confirmed = await _confirmDialog(
          currentLocalizations.delete,
          '${currentLocalizations.deletePostMessage} "${meeting.title}"?',
        );
        if (confirmed) {
          await _repo.deleteMeeting(meeting.id);
          _loadMeetings();
        }
        break;
    }
  }

  Future<bool> _confirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations(widget.currentLanguage).cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimaryOf(context),
                ),
                child: Text(
                  AppLocalizations(widget.currentLanguage).confirmLabel,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showInterestedUsers(
    Meeting meeting,
    AppLocalizations localizations,
  ) async {
    final users = await _repo.getInterestedUsers(meeting.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.dividerOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              localizations.interestedUsersCount(users.length),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (users.isEmpty)
              Expanded(
                child: Center(child: Text(localizations.noInterestedUsersYet)),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final u = users[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondary.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          (u['display_name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        u['display_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          if ((u['phone_number'] ?? '').toString().isNotEmpty)
                            (u['phone_number'] ?? '').toString(),
                          _prettyRoleLabel((u['role'] ?? '').toString()),
                        ].join(' • '),
                      ),
                      trailing: Text(
                        u['interested_at'] != null
                            ? u['interested_at'].toString().split(' ')[0]
                            : '',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRsvpResponses(
    Meeting meeting,
    AppLocalizations localizations,
  ) async {
    final going = await _repo.getRsvpUsers(meeting.id, response: 'going');
    final maybe = await _repo.getRsvpUsers(meeting.id, response: 'maybe');
    final notGoing = await _repo.getRsvpUsers(
      meeting.id,
      response: 'not_going',
    );
    final counts = <String, int>{
      'going': going.length,
      'maybe': maybe.length,
      'not_going': notGoing.length,
    };
    if (!mounted) return;

    Widget buildUserList(List<Map<String, dynamic>> users, Color accentColor) {
      if (users.isEmpty) {
        return Center(child: Text(localizations.noResponsesYet));
      }
      return ListView.separated(
        itemCount: users.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final u = users[i];
          final displayName = (u['display_name'] ?? 'Unknown').toString();
          final phone = (u['phone_number'] ?? '').toString();
          final role = _prettyRoleLabel((u['role'] ?? '').toString());
          final attendeeName = (u['attendee_name'] ?? '').toString().trim();
          final attendeePhone = (u['attendee_phone'] ?? '').toString().trim();
          final attendeeDetails = (u['attendee_details'] ?? '')
              .toString()
              .trim();
          final updatedAt = u['updated_at'];
          String dateText = '';
          if (updatedAt != null) {
            dateText = updatedAt.toString().split(' ').first;
          }
          final attendeeMeta = <String>[
            if (attendeeName.isNotEmpty) attendeeName,
            if (attendeePhone.isNotEmpty) attendeePhone,
            if (attendeeDetails.isNotEmpty) attendeeDetails,
          ].join(' • ');
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: accentColor.withValues(alpha: 0.15),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              attendeeMeta.isNotEmpty
                  ? '${phone.isNotEmpty ? '$phone • $role\n' : '$role\n'}$attendeeMeta'
                  : (phone.isNotEmpty ? '$phone • $role' : role),
            ),
            trailing: Text(
              dateText,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          );
        },
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.dividerOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                localizations.rsvpResponsesTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meeting.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                tabs: [
                  Tab(text: localizations.goingCountTab(counts['going'] ?? 0)),
                  Tab(text: localizations.maybeCountTab(counts['maybe'] ?? 0)),
                  Tab(
                    text: localizations.notGoingCountTab(
                      counts['not_going'] ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    buildUserList(going, AppColors.successOf(context)),
                    buildUserList(maybe, AppColors.warningOf(context)),
                    buildUserList(notGoing, AppColors.destructiveFgOf(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show create/edit meeting form dialog
  void _showMeetingForm({
    Meeting? meeting,
    required AppLocalizations localizations,
  }) {
    final isEdit = meeting != null;
    final titleC = TextEditingController(text: meeting?.title ?? '');
    final descC = TextEditingController(text: meeting?.description ?? '');
    final venueC = TextEditingController(text: meeting?.venue ?? '');
    final daysC = TextEditingController(
      text: (meeting?.displayDays ?? 7).toString(),
    );
    String? imageUrl = meeting?.imageUrl;
    bool isUploadingImage = false;

    DateTime selectedDate =
        meeting?.meetingDate ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = meeting != null
        ? TimeOfDay(
            hour: int.tryParse(meeting.meetingTime.split(':')[0]) ?? 10,
            minute: int.tryParse(meeting.meetingTime.split(':')[1]) ?? 0,
          )
        : const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isEdit ? localizations.editMeeting : localizations.createMeeting,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (English - required)
                  TextField(
                    controller: titleC,
                    decoration: InputDecoration(
                      labelText: localizations.titleEn,
                      hintText: localizations.meetingTitleHint,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: descC,
                    decoration: InputDecoration(
                      labelText: localizations.descEn,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Meeting image',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 140,
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.surfaceOf(context),
                            border: Border.all(
                              color: AppColors.dividerOf(context),
                            ),
                          ),
                          child: Text(
                            'Could not load image preview',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.surfaceOf(context),
                        border: Border.all(color: AppColors.dividerOf(context)),
                      ),
                      child: Text(
                        'No image selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () async {
                                final picked = await _mediaPicker
                                    .pickImageFromGallery();
                                if (picked == null) return;
                                setDialogState(() => isUploadingImage = true);
                                final uploadResult = await _repo
                                    .uploadMeetingImage(
                                      filePath: picked.path,
                                      userId: widget.currentUser.id,
                                      meetingId: meeting?.id,
                                    );
                                final uploadedUrl = uploadResult.url;
                                if (!ctx.mounted) return;
                                setDialogState(() {
                                  isUploadingImage = false;
                                  if (uploadedUrl != null &&
                                      uploadedUrl.trim().isNotEmpty) {
                                    imageUrl = uploadedUrl;
                                  }
                                });
                                if (uploadedUrl == null && ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        uploadResult.errorMessage ??
                                            'Image upload failed. Try JPG/PNG/HEIC and keep file under 10MB.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: isUploadingImage
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_rounded, size: 16),
                        label: Text(
                          isUploadingImage ? 'Uploading...' : 'Upload Image',
                        ),
                      ),
                      if (imageUrl != null && imageUrl!.isNotEmpty)
                        TextButton.icon(
                          onPressed: isUploadingImage
                              ? null
                              : () => setDialogState(() => imageUrl = ''),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date & Time
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            selectedTime.format(ctx),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Venue
                  TextField(
                    controller: venueC,
                    decoration: InputDecoration(
                      labelText: localizations.venueEn,
                      hintText: localizations.meetingLocationHint,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display days
                  TextField(
                    controller: daysC,
                    decoration: InputDecoration(
                      labelText: localizations.displayDaysLabel,
                      hintText: localizations.displayDaysHint,
                      suffixText: localizations.language == AppLanguage.telugu
                          ? localizations.daysLabelTe
                          : localizations.daysLabel,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleC.text.trim().isEmpty || venueC.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(localizations.fieldsRequired)),
                  );
                  return;
                }
                if (!EnglishContentNormalizer.areEnglishLike([
                  titleC.text,
                  descC.text,
                  venueC.text,
                ])) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter meeting details in English only.',
                      ),
                    ),
                  );
                  return;
                }

                final dateStr =
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                final timeStr =
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00';

                final data = {
                  'title': titleC.text.trim(),
                  'description': descC.text.trim().isEmpty
                      ? null
                      : descC.text.trim(),
                  'meeting_date': dateStr,
                  'meeting_time': timeStr,
                  'venue': venueC.text.trim(),
                  'image_url': imageUrl ?? '',
                  'display_days': int.tryParse(daysC.text) ?? 7,
                  'status': (meeting?.status ?? MeetingStatus.upcoming).toStr(),
                };
                bool success;
                if (isEdit) {
                  data['id'] = meeting.id;
                  success = await _repo.updateMeeting(data);
                } else {
                  data['created_by'] = widget.currentUser.id;
                  data['creator_name'] = widget.currentUser.displayName;
                  final id = await _repo.createMeeting(data);
                  success = id != null;
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (success) {
                  _loadMeetings();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? localizations.meetingUpdated
                              : localizations.meetingCreated,
                        ),
                        backgroundColor: AppColors.successOf(context),
                      ),
                    );
                  }
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.errorLabel),
                      backgroundColor: AppColors.errorOf(context),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimaryOf(context),
              ),
              child: Text(
                isEdit ? localizations.updateLabel : localizations.createLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyRoleLabel(String rawRole) {
    final role = rawRole.trim().toLowerCase();
    if (role == 'super_admin') return 'Super Admin';
    if (role == 'admin') return 'Admin';
    if (role == 'reporter') return 'Reporter';
    return 'Public User';
  }
}
