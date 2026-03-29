import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/shared/models/user.dart';

void main() {
  group('UserRoleExtension.fromString', () {
    test('parses snake_case from backend', () {
      expect(UserRoleExtension.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRoleExtension.fromString('admin'), UserRole.admin);
      expect(UserRoleExtension.fromString('reporter'), UserRole.reporter);
      expect(UserRoleExtension.fromString('public_user'), UserRole.publicUser);
    });

    test('parses camelCase from frontend', () {
      expect(UserRoleExtension.fromString('superAdmin'), UserRole.superAdmin);
      expect(UserRoleExtension.fromString('publicUser'), UserRole.publicUser);
    });

    test('handles display names with spaces', () {
      expect(UserRoleExtension.fromString('Super Admin'), UserRole.superAdmin);
      expect(UserRoleExtension.fromString('Public User'), UserRole.publicUser);
    });

    test('handles null and empty', () {
      expect(UserRoleExtension.fromString(null), UserRole.publicUser);
      expect(UserRoleExtension.fromString(''), UserRole.publicUser);
    });

    test('handles unknown values — defaults to publicUser', () {
      expect(UserRoleExtension.fromString('unknown'), UserRole.publicUser);
      expect(UserRoleExtension.fromString('moderator'), UserRole.publicUser);
      expect(UserRoleExtension.fromString('xyz'), UserRole.publicUser);
    });

    test('is case-insensitive', () {
      expect(UserRoleExtension.fromString('SUPER_ADMIN'), UserRole.superAdmin);
      expect(UserRoleExtension.fromString('ADMIN'), UserRole.admin);
      expect(UserRoleExtension.fromString('Reporter'), UserRole.reporter);
    });
  });

  group('UserRole extensions', () {
    test('toStr returns camelCase', () {
      expect(UserRole.superAdmin.toStr(), 'superAdmin');
      expect(UserRole.admin.toStr(), 'admin');
      expect(UserRole.reporter.toStr(), 'reporter');
      expect(UserRole.publicUser.toStr(), 'publicUser');
    });

    test('toApiString returns snake_case', () {
      expect(UserRole.superAdmin.toApiString(), 'super_admin');
      expect(UserRole.admin.toApiString(), 'admin');
      expect(UserRole.reporter.toApiString(), 'reporter');
      expect(UserRole.publicUser.toApiString(), 'public_user');
    });

    test('displayName returns human-readable', () {
      expect(UserRole.superAdmin.displayName, 'Super Admin');
      expect(UserRole.admin.displayName, 'Admin');
      expect(UserRole.reporter.displayName, 'Reporter');
      expect(UserRole.publicUser.displayName, 'Public User');
    });
  });

  group('User.fromMap / fromJson', () {
    test('parses complete JSON with snake_case keys', () {
      final json = {
        'id': '123',
        'phone_number': '+919876543210',
        'display_name': 'Test User',
        'email': 'test@example.com',
        'role': 'super_admin',
        'bio': 'Hello world',
        'area': 'Downtown',
        'district': 'Central',
        'state': 'Telangana',
        'created_at': '2024-01-01T00:00:00.000Z',
        'preferred_language': 'te',
      };

      final user = User.fromJson(json);

      expect(user.id, '123');
      expect(user.phoneNumber, '+919876543210');
      expect(user.displayName, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.role, UserRole.superAdmin);
      expect(user.bio, 'Hello world');
      expect(user.district, 'Central');
      expect(user.state, 'Telangana');
      expect(user.preferredLanguage, 'te');
    });

    test('handles missing optional fields', () {
      final json = {
        'id': '1',
        'phone_number': '+91',
        'display_name': 'Min User',
        'role': 'publicUser',
      };

      final user = User.fromJson(json);

      expect(user.email, isNull);
      expect(user.bio, isNull);
      expect(user.profilePicture, isNull);
      expect(user.area, isNull);
      expect(user.role, UserRole.publicUser);
      expect(user.preferredLanguage, 'en'); // default
    });

    test('handles camelCase keys', () {
      final json = {
        'id': '5',
        'phoneNumber': '+91123',
        'displayName': 'CamelUser',
        'role': 'admin',
        'createdAt': '2024-06-15T12:00:00Z',
        'preferredLanguage': 'hi',
      };

      final user = User.fromJson(json);
      expect(user.displayName, 'CamelUser');
      expect(user.phoneNumber, '+91123');
      expect(user.preferredLanguage, 'hi');
    });

    test('handles integer created_at (milliseconds)', () {
      final timestamp = DateTime(2024, 1, 1).millisecondsSinceEpoch;
      final json = {
        'id': '1',
        'phone_number': '+91',
        'display_name': 'User',
        'role': 'admin',
        'created_at': timestamp,
      };

      final user = User.fromMap(json);
      expect(user.createdAt.year, 2024);
      expect(user.createdAt.month, 1);
    });

    test('handles user_id key', () {
      final json = {
        'user_id': '42',
        'phone_number': '+91',
        'display_name': 'User',
        'role': 'reporter',
      };

      final user = User.fromJson(json);
      expect(user.id, '42');
    });
  });

  group('User.toJson', () {
    test('serializes correctly with snake_case', () {
      final user = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'Test',
        role: UserRole.superAdmin,
        createdAt: DateTime(2024, 1, 1),
      );

      final json = user.toJson();
      expect(json['role'], 'super_admin');
      expect(json['display_name'], 'Test');
      expect(json['phone_number'], '+91');
      expect(json['id'], '1');
    });

    test('excludes null optional fields', () {
      final user = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'Minimal',
        role: UserRole.publicUser,
        createdAt: DateTime(2024),
      );

      final json = user.toJson();
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('bio'), isFalse);
      expect(json.containsKey('profile_picture'), isFalse);
      expect(json.containsKey('area'), isFalse);
    });

    test('includes non-null optional fields', () {
      final user = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'Full',
        email: 'test@test.com',
        bio: 'My bio',
        role: UserRole.admin,
        createdAt: DateTime(2024),
      );

      final json = user.toJson();
      expect(json['email'], 'test@test.com');
      expect(json['bio'], 'My bio');
    });
  });

  group('User.toMap', () {
    test('serializes for SQLite', () {
      final user = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'Test',
        role: UserRole.admin,
        createdAt: DateTime(2024, 1, 1),
      );

      final map = user.toMap();
      expect(map['role'], 'admin'); // camelCase for local storage
      expect(map['created_at'], isA<int>()); // milliseconds for SQLite
    });
  });

  group('User.copyWith', () {
    final user = User(
      id: '1',
      phoneNumber: '+91',
      displayName: 'Original',
      role: UserRole.publicUser,
      createdAt: DateTime(2024),
      bio: 'Original bio',
    );

    test('preserves unchanged fields', () {
      final updated = user.copyWith(displayName: 'Updated');
      expect(updated.displayName, 'Updated');
      expect(updated.id, '1');
      expect(updated.role, UserRole.publicUser);
      expect(updated.bio, 'Original bio');
    });

    test('can change role', () {
      final promoted = user.copyWith(role: UserRole.reporter);
      expect(promoted.role, UserRole.reporter);
      expect(promoted.displayName, 'Original');
    });

    test('can change multiple fields', () {
      final updated = user.copyWith(
        displayName: 'New Name',
        bio: 'New bio',
        role: UserRole.admin,
      );
      expect(updated.displayName, 'New Name');
      expect(updated.bio, 'New bio');
      expect(updated.role, UserRole.admin);
      expect(updated.id, '1');
    });

    test('can update stats', () {
      final updated = user.copyWith(postsCount: 10);
      expect(updated.postsCount, 10);
    });
  });

  group('User equality (Equatable)', () {
    test('equal users are equal', () {
      final u1 = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'A',
        role: UserRole.admin,
        createdAt: DateTime(2024),
      );
      final u2 = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'A',
        role: UserRole.admin,
        createdAt: DateTime(2024),
      );
      expect(u1, equals(u2));
      expect(u1.hashCode, equals(u2.hashCode));
    });

    test('different id means not equal', () {
      final u1 = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'A',
        role: UserRole.admin,
        createdAt: DateTime(2024),
      );
      final u2 = User(
        id: '2',
        phoneNumber: '+91',
        displayName: 'A',
        role: UserRole.admin,
        createdAt: DateTime(2024),
      );
      expect(u1, isNot(equals(u2)));
    });

    test('different role means not equal', () {
      final u1 = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'A',
        role: UserRole.admin,
        createdAt: DateTime(2024),
      );
      final u2 = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'A',
        role: UserRole.reporter,
        createdAt: DateTime(2024),
      );
      expect(u1, isNot(equals(u2)));
    });
  });

  group('User computed properties', () {
    test('isSuperAdmin', () {
      final sa = User(
        id: '1',
        phoneNumber: '+91',
        displayName: 'SA',
        role: UserRole.superAdmin,
        createdAt: DateTime(2024),
      );
      final admin = User(
        id: '2',
        phoneNumber: '+91',
        displayName: 'A',
        role: UserRole.admin,
        createdAt: DateTime(2024),
      );
      expect(sa.isSuperAdmin, isTrue);
      expect(admin.isSuperAdmin, isFalse);
    });

    test('canUploadContent', () {
      expect(
        User(
          id: '1',
          phoneNumber: '+91',
          displayName: 'X',
          role: UserRole.superAdmin,
          createdAt: DateTime(2024),
        ).canUploadContent,
        isTrue,
      );
      expect(
        User(
          id: '1',
          phoneNumber: '+91',
          displayName: 'X',
          role: UserRole.admin,
          createdAt: DateTime(2024),
        ).canUploadContent,
        isTrue,
      );
      expect(
        User(
          id: '1',
          phoneNumber: '+91',
          displayName: 'X',
          role: UserRole.reporter,
          createdAt: DateTime(2024),
        ).canUploadContent,
        isTrue,
      );
      expect(
        User(
          id: '1',
          phoneNumber: '+91',
          displayName: 'X',
          role: UserRole.publicUser,
          createdAt: DateTime(2024),
        ).canUploadContent,
        isFalse,
      );
    });

    test('canModerate', () {
      expect(
        User(
          id: '1',
          phoneNumber: '+91',
          displayName: 'X',
          role: UserRole.superAdmin,
          createdAt: DateTime(2024),
        ).canModerate,
        isTrue,
      );
      expect(
        User(
          id: '1',
          phoneNumber: '+91',
          displayName: 'X',
          role: UserRole.reporter,
          createdAt: DateTime(2024),
        ).canModerate,
        isFalse,
      );
    });
  });
}
