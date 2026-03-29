import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/features/auth/data/repositories/auth_repository.dart';
import 'package:focus_today/shared/models/user.dart';

void main() {
  group('AuthResult', () {
    test('success can carry authenticated user and diagnostics', () {
      final user = User(
        id: 'u_1',
        phoneNumber: '+919999999999',
        displayName: 'Test User',
        role: UserRole.publicUser,
        createdAt: DateTime(2026, 1, 1),
      );

      final result = AuthResult.success(
        user: user,
        diagnostics: const {'total_ms': 1200},
      );

      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.user?.id, 'u_1');
      expect(result.diagnostics?['total_ms'], 1200);
    });

    test('failure preserves existing error contract', () {
      final result = AuthResult.failure('Verification failed');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Verification failed');
      expect(result.user, isNull);
    });
  });
}
