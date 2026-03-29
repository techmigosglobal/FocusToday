import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/meeting.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/slice_surface.dart';
import '../../data/repositories/meeting_repository.dart';
import '../models/meeting_detail_mode.dart';
import 'meetings_management_screen.dart';

/// Role-aware Meeting Detail screen.
/// - Attendee mode (public/reporter): RSVP + interest actions.
/// - AdminOps mode (admin/superAdmin): analytics + participant lists + status actions.
class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;
  final User currentUser;
  final MeetingDetailMode mode;
  final MeetingRepository? repository;

  const MeetingDetailScreen({
    super.key,
    required this.meeting,
    required this.currentUser,
    required this.mode,
    this.repository,
  });

  factory MeetingDetailScreen.forUser({
    Key? key,
    required Meeting meeting,
    required User currentUser,
    MeetingRepository? repository,
  }) {
    return MeetingDetailScreen(
      key: key,
      meeting: meeting,
      currentUser: currentUser,
      mode: resolveMeetingDetailMode(currentUser.role),
      repository: repository,
    );
  }

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  late final MeetingRepository _repo;

  late Meeting _meeting;
  late final TextEditingController _attendeeNameController;
  late final TextEditingController _attendeePhoneController;
  late final TextEditingController _attendeeDetailsController;

  // Attendee mode state
  String? _myRsvp; // 'going' | 'maybe' | 'not_going' | null
  final Map<String, int> _rsvpCounts = {};
  bool _isLoadingRsvp = true;
  bool _isSavingRsvp = false;
  bool _isInterested = false;
  int _interestCount = 0;
  bool _isInterestSaving = false;

  // Admin mode state
  MeetingAdminEngagementData _adminData =
      const MeetingAdminEngagementData.empty();
  bool _isLoadingAdminData = true;
  bool _isStatusSaving = false;

  bool get _isAdminMode => widget.mode == MeetingDetailMode.adminOps;
  bool get _isAttendeeMode => widget.mode == MeetingDetailMode.attendee;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MeetingRepository();
    _meeting = widget.meeting;
    _attendeeNameController = TextEditingController(
      text: widget.currentUser.displayName,
    );
    _attendeePhoneController = TextEditingController(
      text: widget.currentUser.phoneNumber,
    );
    _attendeeDetailsController = TextEditingController();
    _isInterested = widget.meeting.isInterested;
    _interestCount = widget.meeting.interestCount;

    if (_isAdminMode) {
      _loadAdminDashboard();
    } else {
      _loadAttendeeRsvp();
    }
  }

  @override
  void dispose() {
    _attendeeNameController.dispose();
    _attendeePhoneController.dispose();
    _attendeeDetailsController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendeeRsvp() async {
    final rsvpPayload = await _repo.getUserRsvpPayload(
      _meeting.id,
      widget.currentUser.id,
    );
    if (!mounted) return;

    setState(() {
      _myRsvp = rsvpPayload?['response']?.toString();
      _attendeeNameController.text =
          (rsvpPayload?['attendee_name']?.toString().trim().isNotEmpty ?? false)
          ? rsvpPayload!['attendee_name'].toString()
          : widget.currentUser.displayName;
      _attendeePhoneController.text =
          (rsvpPayload?['attendee_phone']?.toString().trim().isNotEmpty ??
              false)
          ? rsvpPayload!['attendee_phone'].toString()
          : widget.currentUser.phoneNumber;
      _attendeeDetailsController.text =
          rsvpPayload?['attendee_details']?.toString() ?? '';
      _isLoadingRsvp = false;
    });
  }

  Future<void> _loadAdminDashboard() async {
    setState(() => _isLoadingAdminData = true);
    final dashboard = await _repo.getAdminEngagementDashboard(_meeting.id);
    if (!mounted) return;
    setState(() {
      _adminData = dashboard;
      _isLoadingAdminData = false;
    });
  }

  Future<void> _onRsvp(String response) async {
    if (_isSavingRsvp || !_isAttendeeMode) return;
    HapticFeedback.selectionClick();
    final newRsvp = _myRsvp == response ? null : response;
    setState(() {
      _isSavingRsvp = true;
      _myRsvp = newRsvp;
    });

    if (newRsvp != null) {
      await _repo.submitRsvp(
        _meeting.id,
        widget.currentUser.id,
        newRsvp,
        attendeeName: _attendeeNameController.text,
        attendeePhone: _attendeePhoneController.text,
        attendeeDetails: _attendeeDetailsController.text,
      );
    }

    if (mounted) {
      setState(() {
        _isSavingRsvp = false;
      });
    }
  }

  Future<void> _onToggleInterest() async {
    if (_isInterestSaving || !_isAttendeeMode) return;
    HapticFeedback.selectionClick();
    final wasInterested = _isInterested;
    final previousCount = _interestCount;
    setState(() {
      _isInterestSaving = true;
      _isInterested = !_isInterested;
      _interestCount += _isInterested ? 1 : -1;
    });

    final result = await _repo.toggleInterest(
      _meeting.id,
      widget.currentUser.id,
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        _isInterested = wasInterested;
        _interestCount = previousCount;
        _isInterestSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update interest. Please try again.'),
        ),
      );
      return;
    }

    final normalized = _normalizedCountForState(
      previousCount,
      wasInterested,
      result.state,
    );
    setState(() {
      _isInterestSaving = false;
      _isInterested = result.state == MeetingInterestState.interested;
      _interestCount = normalized;
    });
  }

  int _normalizedCountForState(
    int previousCount,
    bool wasInterested,
    MeetingInterestState state,
  ) {
    final previous = previousCount - (wasInterested ? 1 : 0);
    final next = previous + (state == MeetingInterestState.interested ? 1 : 0);
    return next.clamp(0, 1 << 30);
  }

  Future<void> _updateMeetingStatus(MeetingStatus status) async {
    if (_isStatusSaving || !widget.currentUser.canModerate) return;
    setState(() => _isStatusSaving = true);

    final ok = await _repo.updateMeeting({
      'id': _meeting.id,
      'status': status.toStr(),
    });
    if (!mounted) return;

    if (ok) {
      setState(() {
        _meeting = _meeting.copyWith(status: status);
      });
      await _loadAdminDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update meeting status. Please try again.'),
        ),
      );
    }

    if (mounted) {
      setState(() => _isStatusSaving = false);
    }
  }

  void _openManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingsManagementScreen(
          currentUser: widget.currentUser,
          currentLanguage: AppLanguage.fromCode(
            Localizations.localeOf(context).languageCode,
          ),
          initialEditMeetingId: _meeting.id,
        ),
      ),
    );
  }

  void _showInterestedUsersSheet(AppLocalizations localizations) {
    final users = _adminData.interestedUsers;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    final displayName = (u['display_name'] ?? 'Unknown')
                        .toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondary.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        displayName,
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
                        _dateOnlyText(u['interested_at']),
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

  void _showRsvpUsersSheet(AppLocalizations localizations) {
    final counts = <String, int>{
      'going': _adminData.goingUsers.length,
      'maybe': _adminData.maybeUsers.length,
      'not_going': _adminData.notGoingUsers.length,
    };

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
              _dateOnlyText(u['updated_at']),
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
                _meeting.title,
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
                    buildUserList(
                      _adminData.goingUsers,
                      AppColors.successOf(context),
                    ),
                    buildUserList(
                      _adminData.maybeUsers,
                      AppColors.warningOf(context),
                    ),
                    buildUserList(
                      _adminData.notGoingUsers,
                      AppColors.destructiveFgOf(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateOnlyText(dynamic value) {
    if (value == null) return '';
    final raw = value.toString();
    return raw.split(' ').first;
  }

  String _prettyRoleLabel(String role) {
    final normalized = role.trim().toLowerCase().replaceAll('_', '');
    switch (normalized) {
      case 'reporter':
        return 'Reporter';
      case 'publicuser':
        return 'Public User';
      case 'admin':
        return 'Admin';
      case 'superadmin':
        return 'Super Admin';
      default:
        return 'Public User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(
      AppLanguage.fromCode(Localizations.localeOf(context).languageCode),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SliceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      localizations.meetingDetails,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                  children: [
                    if (_meeting.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: _meeting.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            height: 200,
                            color: AppColors.primary.withValues(alpha: 0.08),
                          ),
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildMeetingOverviewCard(localizations),
                    const SizedBox(height: 12),
                    _buildVenueCard(localizations),
                    const SizedBox(height: 12),
                    if (_meeting.creatorName != null) ...[
                      _buildOrganiserCard(localizations),
                      const SizedBox(height: 12),
                    ],
                    if (_isAttendeeMode) ...[
                      _buildAttendeeRsvpCard(localizations),
                      const SizedBox(height: 12),
                      _buildAttendeeInterestCard(localizations),
                    ] else ...[
                      _buildAdminMetricsCard(localizations),
                      const SizedBox(height: 12),
                      _buildAdminParticipantsCard(localizations),
                      const SizedBox(height: 12),
                      _buildAdminActionsCard(localizations),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingOverviewCard(AppLocalizations localizations) {
    return SliceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(
                icon: Icons.calendar_month_rounded,
                label: _meeting.formattedDate,
                color: _meeting.isToday ? AppColors.accent : AppColors.primary,
              ),
              const SizedBox(width: 8),
              _Badge(
                icon: Icons.access_time_rounded,
                label: _meeting.formattedTime,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _Badge(
                icon: Icons.info_outline_rounded,
                label: _meeting.status.toStr().toUpperCase(),
                color: _statusColor(_meeting.status, context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _meeting.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          if (_meeting.description != null &&
              _meeting.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _meeting.description!,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVenueCard(AppLocalizations localizations) {
    return SliceCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.venue,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _meeting.venue,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganiserCard(AppLocalizations localizations) {
    return SliceCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_rounded, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.organiser,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _meeting.creatorName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeRsvpCard(AppLocalizations localizations) {
    return SliceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                localizations.rsvpLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (_isLoadingRsvp) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            localizations.rsvpDescription,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _attendeeNameController,
            decoration: InputDecoration(
              labelText: localizations.nameLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _attendeePhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: localizations.phoneLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _attendeeDetailsController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: localizations.detailsOptionalLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RsvpButton(
                label: localizations.going,
                icon: Icons.check_circle_rounded,
                color: AppColors.successOf(context),
                selected: _myRsvp == 'going',
                onTap: () => _onRsvp('going'),
                count: _rsvpCounts['going'] ?? 0,
              ),
              const SizedBox(width: 8),
              _RsvpButton(
                label: localizations.maybe,
                icon: Icons.help_rounded,
                color: AppColors.warningOf(context),
                selected: _myRsvp == 'maybe',
                onTap: () => _onRsvp('maybe'),
                count: _rsvpCounts['maybe'] ?? 0,
              ),
              const SizedBox(width: 8),
              _RsvpButton(
                label: localizations.noLabel,
                icon: Icons.cancel_rounded,
                color: AppColors.destructiveFgOf(context),
                selected: _myRsvp == 'not_going',
                onTap: () => _onRsvp('not_going'),
                count: _rsvpCounts['not_going'] ?? 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeInterestCard(AppLocalizations localizations) {
    return SliceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.interested,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (_interestCount > 0)
                  Text(
                    localizations.interestedPeople(_interestCount),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isInterestSaving ? null : _onToggleInterest,
            icon: Icon(
              _isInterested ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
            ),
            label: Text(
              _isInterested
                  ? localizations.interested
                  : localizations.markInterest,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInterested ? AppColors.primary : null,
              foregroundColor: _isInterested
                  ? AppColors.onPrimaryOf(context)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMetricsCard(AppLocalizations localizations) {
    return SliceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Engagement',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (_isLoadingAdminData) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricTile(
                label: localizations.interested,
                count: _adminData.interestedCount,
                color: AppColors.primary,
              ),
              _MetricTile(
                label: localizations.notInterestedLabel,
                count: _adminData.notInterestedCount,
                color: AppColors.destructiveFgOf(context),
              ),
              _MetricTile(
                label: localizations.going,
                count: _adminData.goingCount,
                color: AppColors.successOf(context),
              ),
              _MetricTile(
                label: localizations.maybe,
                count: _adminData.maybeCount,
                color: AppColors.warningOf(context),
              ),
              _MetricTile(
                label: localizations.noLabel,
                count: _adminData.notGoingCount,
                color: AppColors.destructiveFgOf(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminParticipantsCard(AppLocalizations localizations) {
    return SliceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participants',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingAdminData
                      ? null
                      : () => _showInterestedUsersSheet(localizations),
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: Text(localizations.viewInterestedUsers),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoadingAdminData
                      ? null
                      : () => _showRsvpUsersSheet(localizations),
                  icon: const Icon(Icons.people_alt_rounded, size: 16),
                  label: Text(localizations.viewRsvpResponses),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionsCard(AppLocalizations localizations) {
    final status = _meeting.status;
    return SliceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meeting Actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == MeetingStatus.upcoming)
                _ActionChipButton(
                  label: localizations.markAsOngoing,
                  icon: Icons.play_circle_fill_rounded,
                  color: AppColors.successOf(context),
                  busy: _isStatusSaving,
                  onTap: () => _updateMeetingStatus(MeetingStatus.ongoing),
                ),
              if (status != MeetingStatus.completed)
                _ActionChipButton(
                  label: localizations.markAsCompleted,
                  icon: Icons.check_circle_rounded,
                  color: AppColors.secondary,
                  busy: _isStatusSaving,
                  onTap: () => _updateMeetingStatus(MeetingStatus.completed),
                ),
              if (status != MeetingStatus.cancelled)
                _ActionChipButton(
                  label: localizations.cancel,
                  icon: Icons.cancel_rounded,
                  color: AppColors.destructiveFgOf(context),
                  busy: _isStatusSaving,
                  onTap: () => _updateMeetingStatus(MeetingStatus.cancelled),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isStatusSaving ? null : _openManagement,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(localizations.editMeeting),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(MeetingStatus status, BuildContext context) {
    switch (status) {
      case MeetingStatus.upcoming:
        return AppColors.primary;
      case MeetingStatus.ongoing:
        return AppColors.successOf(context);
      case MeetingStatus.completed:
        return AppColors.secondary;
      case MeetingStatus.cancelled:
        return AppColors.destructiveFgOf(context);
    }
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : AppColors.dividerOf(context),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? color : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: selected ? color : AppColors.textSecondaryOf(context),
                ),
              ),
              if (count > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? color
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }
}
