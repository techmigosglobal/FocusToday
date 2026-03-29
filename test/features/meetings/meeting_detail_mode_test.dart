import 'package:focus_today/features/meetings/presentation/models/meeting_detail_mode.dart';
import 'package:focus_today/shared/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveMeetingDetailMode', () {
    test('maps public and reporter to attendee mode', () {
      expect(
        resolveMeetingDetailMode(UserRole.publicUser),
        MeetingDetailMode.attendee,
      );
      expect(
        resolveMeetingDetailMode(UserRole.reporter),
        MeetingDetailMode.attendee,
      );
    });

    test('maps admin and super admin to admin ops mode', () {
      expect(
        resolveMeetingDetailMode(UserRole.admin),
        MeetingDetailMode.adminOps,
      );
      expect(
        resolveMeetingDetailMode(UserRole.superAdmin),
        MeetingDetailMode.adminOps,
      );
    });
  });
}
