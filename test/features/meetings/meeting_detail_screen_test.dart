import 'package:focus_today/features/meetings/data/repositories/meeting_repository.dart';
import 'package:focus_today/features/meetings/presentation/models/meeting_detail_mode.dart';
import 'package:focus_today/features/meetings/presentation/screens/meeting_detail_screen.dart';
import 'package:focus_today/shared/models/meeting.dart';
import 'package:focus_today/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMeetingRepository extends MeetingRepository {
  @override
  Future<Map<String, dynamic>?> getUserRsvpPayload(
    int meetingId,
    String userId,
  ) async {
    return const {'response': 'maybe'};
  }

  @override
  Future<bool> submitRsvp(
    int meetingId,
    String userId,
    String response, {
    String? attendeeName,
    String? attendeePhone,
    String? attendeeDetails,
  }) async {
    return true;
  }

  @override
  Future<MeetingToggleResult> toggleInterest(
    int meetingId,
    String userId,
  ) async {
    return const MeetingToggleResult(MeetingInterestState.interested);
  }

  @override
  Future<MeetingAdminEngagementData> getAdminEngagementDashboard(
    int meetingId,
  ) async {
    return MeetingAdminEngagementData.fromGroupedUsers(
      interestedUsers: const [
        {'id': 'u1'},
      ],
      goingUsers: const [
        {'id': 'u1'},
      ],
      maybeUsers: const [],
      notGoingUsers: const [
        {'id': 'u2'},
      ],
    );
  }

  @override
  Future<bool> updateMeeting(Map<String, dynamic> data) async => true;
}

void main() {
  final meeting = Meeting(
    id: 1,
    title: 'Town Hall',
    description: 'Monthly meeting',
    meetingDate: DateTime(2026, 3, 31),
    meetingTime: '10:00:00',
    venue: 'Main Center',
    createdBy: 'admin1',
    creatorName: 'Admin',
    status: MeetingStatus.upcoming,
  );

  final attendeeUser = User(
    id: 'u1',
    phoneNumber: '9999999999',
    displayName: 'Reporter One',
    role: UserRole.reporter,
    createdAt: DateTime(2026, 1, 1),
  );

  final adminUser = User(
    id: 'a1',
    phoneNumber: '8888888888',
    displayName: 'Admin One',
    role: UserRole.admin,
    createdAt: DateTime(2026, 1, 1),
  );

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('attendee mode shows RSVP and hides admin controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MeetingDetailScreen(
          meeting: meeting,
          currentUser: attendeeUser,
          mode: MeetingDetailMode.attendee,
          repository: _FakeMeetingRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RSVP'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Meeting Actions'), findsNothing);
    expect(find.text('Participants'), findsNothing);
  });

  testWidgets('admin mode shows dashboard and hides RSVP form', (tester) async {
    await tester.pumpWidget(
      wrap(
        MeetingDetailScreen(
          meeting: meeting,
          currentUser: adminUser,
          mode: MeetingDetailMode.adminOps,
          repository: _FakeMeetingRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Participants'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Participants'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Meeting Actions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Meeting Actions'), findsOneWidget);
    expect(find.text('View RSVP Responses'), findsOneWidget);
  });
}
