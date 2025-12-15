// Subscription Plan Model
// Represents different subscription tiers available in the app

enum SubscriptionPlanType { free, premium, elite }

class SubscriptionPlan {
  final SubscriptionPlanType type;
  final String name;
  final String displayName;
  final double price; // Monthly price in rupees
  final String currency;
  final List<String> features;
  final String description;
  final int durationDays;
  final bool isPopular;

  const SubscriptionPlan({
    required this.type,
    required this.name,
    required this.displayName,
    required this.price,
    this.currency = '₹',
    required this.features,
    required this.description,
    this.durationDays = 30,
    this.isPopular = false,
  });

  /// Get formatted price string
  String get formattedPrice {
    if (price == 0) {
      return 'Free';
    }
    return '$currency${price.toStringAsFixed(0)}/month';
  }

  /// Check if this is a paid plan
  bool get isPaid => price > 0;

  /// Get plan badge color
  String get badgeColor {
    switch (type) {
      case SubscriptionPlanType.free:
        return '#9E9E9E'; // Grey
      case SubscriptionPlanType.premium:
        return '#FF6B35'; // Orange (matching app primary)
      case SubscriptionPlanType.elite:
        return '#FFD700'; // Gold
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionPlan &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
}

/// Predefined subscription plans
class SubscriptionPlans {
  SubscriptionPlans._();

  static const SubscriptionPlan free = SubscriptionPlan(
    type: SubscriptionPlanType.free,
    name: 'free',
    displayName: 'Basic',
    price: 0,
    description: 'Access to basic features',
    features: [
      'View approved content',
      'Like and bookmark posts',
      'Basic search functionality',
      'Access to public content',
      'Limited to 5 bookmarks',
    ],
  );

  static const SubscriptionPlan premium = SubscriptionPlan(
    type: SubscriptionPlanType.premium,
    name: 'premium',
    displayName: 'Premium',
    price: 99,
    description: 'Enhanced experience with premium features',
    features: [
      'All Basic features',
      'Unlimited bookmarks',
      'Ad-free experience',
      'Early access to content',
      'Advanced search filters',
      'Download content offline',
      'Premium badge on profile',
    ],
    isPopular: true,
  );

  static const SubscriptionPlan elite = SubscriptionPlan(
    type: SubscriptionPlanType.elite,
    name: 'elite',
    displayName: 'Elite',
    price: 199,
    description: 'Ultimate experience with all features',
    features: [
      'All Premium features',
      'Priority content access',
      'Exclusive elite content',
      'Custom profile themes',
      'Elite badge on profile',
      'Direct messaging',
      'Monthly exclusive content',
      'Priority customer support',
    ],
  );

  /// Get all available plans
  static List<SubscriptionPlan> get allPlans => [free, premium, elite];

  /// Get plan by type
  static SubscriptionPlan getByType(SubscriptionPlanType type) {
    switch (type) {
      case SubscriptionPlanType.free:
        return free;
      case SubscriptionPlanType.premium:
        return premium;
      case SubscriptionPlanType.elite:
        return elite;
    }
  }

  /// Get plan by name
  static SubscriptionPlan? getByName(String name) {
    try {
      return allPlans.firstWhere((plan) => plan.name == name);
    } catch (e) {
      return null;
    }
  }
}

/// Extension to convert SubscriptionPlanType to/from string
extension SubscriptionPlanTypeExtension on SubscriptionPlanType {
  String toStr() {
    return toString().split('.').last;
  }

  static SubscriptionPlanType fromString(String type) {
    switch (type) {
      case 'free':
        return SubscriptionPlanType.free;
      case 'premium':
        return SubscriptionPlanType.premium;
      case 'elite':
        return SubscriptionPlanType.elite;
      default:
        return SubscriptionPlanType.free;
    }
  }
}
