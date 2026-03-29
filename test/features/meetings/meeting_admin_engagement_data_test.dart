import 'package:focus_today/features/meetings/data/repositories/meeting_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeetingAdminEngagementData', () {
    test('builds counts from grouped users', () {
      final data = MeetingAdminEngagementData.fromGroupedUsers(
        interestedUsers: const [
          {'id': 'u1'},
          {'id': 'u2'},
        ],
        goingUsers: const [
          {'id': 'u1'},
        ],
        maybeUsers: const [
          {'id': 'u2'},
          {'id': 'u3'},
        ],
        notGoingUsers: const [
          {'id': 'u4'},
        ],
      );

      expect(data.interestedCount, 2);
      expect(data.goingCount, 1);
      expect(data.maybeCount, 2);
      expect(data.notGoingCount, 1);
      expect(data.notInterestedCount, 1);
    });

    test('empty constructor is all zero', () {
      const data = MeetingAdminEngagementData.empty();
      expect(data.interestedCount, 0);
      expect(data.notInterestedCount, 0);
      expect(data.goingCount, 0);
      expect(data.maybeCount, 0);
      expect(data.notGoingCount, 0);
      expect(data.interestedUsers, isEmpty);
      expect(data.goingUsers, isEmpty);
      expect(data.maybeUsers, isEmpty);
      expect(data.notGoingUsers, isEmpty);
    });
  });
}
