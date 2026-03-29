import '../../../../shared/models/user.dart';

enum MeetingDetailMode { attendee, adminOps }

MeetingDetailMode resolveMeetingDetailMode(UserRole role) {
  switch (role) {
    case UserRole.admin:
    case UserRole.superAdmin:
      return MeetingDetailMode.adminOps;
    case UserRole.reporter:
    case UserRole.publicUser:
      return MeetingDetailMode.attendee;
  }
}
