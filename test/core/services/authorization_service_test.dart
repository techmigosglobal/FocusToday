import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_today/core/services/authorization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AuthorizationService', () {
    test(
      'getCurrentUserId returns SharedPreferences user id when no Firebase user',
      () async {
        await prefs.setString('user_id', 'sp_uid');
        final service = await AuthorizationService.init();
        expect(service.getCurrentUserId(), 'sp_uid');
      },
    );

    test('isAuthenticated returns false when no user id present', () async {
      final service = await AuthorizationService.init();
      expect(service.isAuthenticated(), false);
    });

    test(
      'isAuthenticated returns true when user id in SharedPreferences',
      () async {
        await prefs.setString('user_id', 'abc');
        final service = await AuthorizationService.init();
        expect(service.isAuthenticated(), true);
      },
    );

    test('validateCurrentUser throws when not authenticated', () async {
      final service = await AuthorizationService.init();
      expect(
        () => service.validateCurrentUser('uid123', operation: 'updateProfile'),
        throwsA(isA<Exception>()),
      );
    });

    test('validateCurrentUser throws when user id does not match', () async {
      await prefs.setString('user_id', 'current');
      final service = await AuthorizationService.init();
      expect(
        () => service.validateCurrentUser('other', operation: 'deleteAccount'),
        throwsA(isA<Exception>()),
      );
    });

    test('validateCurrentUser succeeds when user id matches', () async {
      await prefs.setString('user_id', 'same');
      final service = await AuthorizationService.init();
      service.validateCurrentUser('same', operation: 'updateProfile');
    });

    test('requireAuthentication throws when unauthenticated', () async {
      final service = await AuthorizationService.init();
      expect(
        () => service.requireAuthentication(operation: 'uploadPost'),
        throwsA(isA<Exception>()),
      );
    });

    test('requireAuthentication does not throw when authenticated', () async {
      await prefs.setString('user_id', 'abc');
      final service = await AuthorizationService.init();
      service.requireAuthentication(operation: 'uploadPost');
    });
  });
}
