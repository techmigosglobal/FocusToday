import 'package:equatable/equatable.dart';

/// User Roles in Focus Today
enum UserRole { superAdmin, admin, reporter, publicUser }

/// Extension to convert UserRole to/from string.
/// Handles both camelCase (frontend) and snake_case (backend) formats.
extension UserRoleExtension on UserRole {
  /// CamelCase string for local storage
  String toStr() {
    return toString().split('.').last;
  }

  /// Display-friendly name
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.reporter:
        return 'Reporter';
      case UserRole.publicUser:
        return 'Public User';
    }
  }

  /// API role string for backend communication.
  String toApiString() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.reporter:
        return 'reporter';
      case UserRole.publicUser:
        return 'public_user';
    }
  }

  /// Parse role from any format (camelCase, snake_case, display name).
  /// Returns publicUser for unknown/null values.
  static UserRole fromString(String? role) {
    if (role == null || role.isEmpty) return UserRole.publicUser;
    switch (role.toLowerCase().replaceAll(' ', '').replaceAll('_', '')) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'reporter':
        return UserRole.reporter;
      case 'publicuser':
        return UserRole.publicUser;
      default:
        return UserRole.publicUser;
    }
  }
}

/// Immutable User Model with value equality via Equatable.
class User extends Equatable {
  final String id;
  final String phoneNumber; // Can contain phone number or email
  final String? email; // Email address (for email/password auth)
  final String displayName;
  final String? profilePicture;
  final String? bio;
  final String? area;
  final String? district;
  final String? state;
  final UserRole role;
  final DateTime createdAt;
  final String preferredLanguage; // 'en', 'te', or 'hi'
  final bool isSubscribed;
  final String? subscriptionPlanType;

  // Stats (can be computed on the fly)
  final int postsCount;

  const User({
    required this.id,
    required this.phoneNumber,
    this.email,
    required this.displayName,
    this.profilePicture,
    this.bio,
    this.area,
    this.district,
    this.state,
    required this.role,
    required this.createdAt,
    this.preferredLanguage = 'en',
    this.isSubscribed = false,
    this.subscriptionPlanType,
    this.postsCount = 0,
  });

  @override
  List<Object?> get props => [
    id,
    phoneNumber,
    email,
    displayName,
    role,
    createdAt,
    isSubscribed,
    subscriptionPlanType,
  ];

  /// Convert User to Map for database storage
  /// Note: SQLite doesn't support bool, so we convert to int (0/1)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'email': email,
      'display_name': displayName,
      'profile_picture': profilePicture,
      'bio': bio,
      'area': area,
      'district': district,
      'state': state,
      'role': role.toStr(),
      'preferred_language': preferredLanguage,
      'is_subscribed': isSubscribed ? 1 : 0,
      'subscription_plan_type': subscriptionPlanType,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Convert to JSON for API communication (snake_case keys)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      if (email != null) 'email': email,
      'display_name': displayName,
      if (profilePicture != null) 'profile_picture': profilePicture,
      if (bio != null) 'bio': bio,
      if (area != null) 'area': area,
      if (district != null) 'district': district,
      if (state != null) 'state': state,
      'role': role.toApiString(),
      'created_at': createdAt.toIso8601String(),
      'preferred_language': preferredLanguage,
      'is_subscribed': isSubscribed,
      if (subscriptionPlanType != null)
        'subscription_plan_type': subscriptionPlanType,
    };
  }

  /// Create User from database Map or API JSON.
  /// Handles both snake_case and camelCase keys.
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: (map['id'] ?? map['user_id'] ?? '').toString(),
      phoneNumber: (map['phone_number'] ?? map['phoneNumber'] ?? '').toString(),
      email: map['email']?.toString(),
      displayName: (map['display_name'] ?? map['displayName'] ?? 'Unknown')
          .toString(),
      profilePicture:
          map['profile_picture']?.toString() ??
          map['profilePicture']?.toString(),
      bio: map['bio']?.toString(),
      area: map['area']?.toString(),
      district: map['district']?.toString(),
      state: map['state']?.toString(),
      role: UserRoleExtension.fromString(
        (map['role'] ?? 'publicUser').toString(),
      ),
      createdAt: map['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.tryParse(
                  (map['created_at'] ?? map['createdAt'] ?? '').toString(),
                ) ??
                DateTime.now(),
      preferredLanguage:
          (map['preferred_language'] ?? map['preferredLanguage'] ?? 'en')
              .toString(),
      isSubscribed:
          map['is_subscribed'] == true ||
          map['is_subscribed'] == 1 ||
          map['isSubscribed'] == true,
      subscriptionPlanType:
          map['subscription_plan_type']?.toString() ??
          map['subscriptionPlanType']?.toString(),
    );
  }

  /// Alias for fromMap — JSON deserialization
  factory User.fromJson(Map<String, dynamic> json) => User.fromMap(json);

  /// Copy with method for updating user properties
  User copyWith({
    String? id,
    String? phoneNumber,
    String? email,
    String? displayName,
    String? profilePicture,
    String? bio,
    String? area,
    String? district,
    String? state,
    UserRole? role,
    DateTime? createdAt,
    String? preferredLanguage,
    bool? isSubscribed,
    String? subscriptionPlanType,
    int? postsCount,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profilePicture: profilePicture ?? this.profilePicture,
      bio: bio ?? this.bio,
      area: area ?? this.area,
      district: district ?? this.district,
      state: state ?? this.state,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionPlanType: subscriptionPlanType ?? this.subscriptionPlanType,
      postsCount: postsCount ?? this.postsCount,
    );
  }

  /// Check if user is a super admin
  bool get isSuperAdmin => role == UserRole.superAdmin;

  /// Check if user can upload content
  bool get canUploadContent =>
      role == UserRole.superAdmin ||
      role == UserRole.admin ||
      role == UserRole.reporter;

  /// Check if user can moderate content
  bool get canModerate => role == UserRole.superAdmin || role == UserRole.admin;

  /// Check if user has access to latest content
  bool get hasLatestContentAccess =>
      role == UserRole.superAdmin ||
      role == UserRole.admin ||
      role == UserRole.reporter;
}
