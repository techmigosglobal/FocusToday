/// User Roles in EagleTV
enum UserRole {
  admin,
  reporter,
  publicUser,
}

/// Extension to convert UserRole to/from string
extension UserRoleExtension on UserRole {
  String toStr() {
    return toString().split('.').last;
  }

  static UserRole fromString(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'reporter':
        return UserRole.reporter;
      case 'publicUser':
        return UserRole.publicUser;
      default:
        return UserRole.publicUser;
    }
  }
}

/// User Model
class User {
  final String id;
  final String phoneNumber;
  final String displayName;
  final String? profilePicture;
  final String? bio;
  final UserRole role;
  final bool isSubscribed;
  final DateTime createdAt;
  final String preferredLanguage; // 'en' or 'te'
  
  // Subscription fields
  final String? subscriptionPlanType; // 'free', 'premium', 'elite'
  final DateTime? subscriptionExpiresAt;

  // Stats (can be computed on the fly)
  final int postsCount;
  final int followersCount;
  final int followingCount;

  User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.profilePicture,
    this.bio,
    required this.role,
    this.isSubscribed = false,
    required this.createdAt,
    this.preferredLanguage = 'en',
    this.subscriptionPlanType,
    this.subscriptionExpiresAt,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  /// Convert User to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'display_name': displayName,
      'profile_picture': profilePicture,
      'bio': bio,
      'role': role.toStr(),
      'is_subscribed': isSubscribed ? 1 : 0,
      'preferred_language': preferredLanguage,
      'subscription_plan_type': subscriptionPlanType,
      'subscription_expires_at': subscriptionExpiresAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create User from database Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      phoneNumber: map['phone_number'],
      displayName: map['display_name'],
      profilePicture: map['profile_picture'],
      bio: map['bio'],
      role: UserRoleExtension.fromString(map['role']),
      isSubscribed: map['is_subscribed'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      preferredLanguage: map['preferred_language'] ?? 'en',
      subscriptionPlanType: map['subscription_plan_type'],
      subscriptionExpiresAt: map['subscription_expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['subscription_expires_at'])
          : null,
    );
  }

  /// Copy with method for updating user properties
  User copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? profilePicture,
    String? bio,
    UserRole? role,
    bool? isSubscribed,
    DateTime? createdAt,
    String? preferredLanguage,
    String? subscriptionPlanType,
    DateTime? subscriptionExpiresAt,
    int? postsCount,
    int? followersCount,
    int? followingCount,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      profilePicture: profilePicture ?? this.profilePicture,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      createdAt: createdAt ?? this.createdAt,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      subscriptionPlanType: subscriptionPlanType ?? this.subscriptionPlanType,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }

  /// Check if user can upload content
  bool get canUploadContent => role == UserRole.admin || role == UserRole.reporter;

  /// Check if user can moderate content
  bool get canModerate => role == UserRole.admin;

  /// Check if user has access to latest content
  bool get hasLatestContentAccess => 
      role == UserRole.admin || role == UserRole.reporter || isSubscribed;
  
  /// Check if user has active subscription
  bool get hasActiveSubscription {
    if (subscriptionExpiresAt == null) return false;
    return DateTime.now().isBefore(subscriptionExpiresAt!);
  }
  
  /// Get subscription badge text
  String? get subscriptionBadge {
    if (!hasActiveSubscription) return null;
    if (subscriptionPlanType == 'elite') return 'Elite';
    if (subscriptionPlanType == 'premium') return 'Premium';
    return null;
  }
}
