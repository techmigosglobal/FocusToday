import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/subscription_plan.dart';

/// Subscription Service
/// Manages user subscriptions (synced with Supabase)
class SubscriptionService {
  static const String _keySubscriptionType = 'subscription_type';
  static const String _keySubscriptionExpiry = 'subscription_expiry';

  final SharedPreferences _prefs;
  final SupabaseClient _supabase = Supabase.instance.client;

  SubscriptionService._(this._prefs);

  /// Initialize subscription service
  static Future<SubscriptionService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SubscriptionService._(prefs);
  }

  /// Get current subscription plan
  Future<SubscriptionPlan> getCurrentPlan() async {
    final typeStr = _prefs.getString(_keySubscriptionType);

    if (typeStr == null) {
      return SubscriptionPlans.free;
    }

    // Check if subscription has expired
    final expiryMillis = _prefs.getInt(_keySubscriptionExpiry);
    if (expiryMillis != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      if (DateTime.now().isAfter(expiry)) {
        // Subscription expired, reset to free
        await clearSubscription();
        return SubscriptionPlans.free;
      }
    }

    final type = SubscriptionPlanTypeExtension.fromString(typeStr);
    return SubscriptionPlans.getByType(type);
  }

  /// Subscribe to a plan
  Future<bool> subscribeToPlan(SubscriptionPlan plan, {String? userId}) async {
    try {
      // 1. Save locally
      await _prefs.setString(_keySubscriptionType, plan.type.toStr());
      final expiry = DateTime.now().add(Duration(days: plan.durationDays));
      await _prefs.setInt(
        _keySubscriptionExpiry,
        expiry.millisecondsSinceEpoch,
      );

      // 2. Sync to Supabase
      if (userId != null) {
        await _supabase
            .from('users')
            .update({
              'is_subscribed': plan.isPaid,
              'subscription_plan_type': plan.type.toStr(),
              'subscription_expires_at': expiry.toIso8601String(),
            })
            .eq('id', userId);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Check if user is subscribed to any paid plan
  Future<bool> isSubscribed() async {
    final plan = await getCurrentPlan();
    return plan.isPaid;
  }

  /// Check if user has specific plan
  Future<bool> hasPlan(SubscriptionPlanType type) async {
    final plan = await getCurrentPlan();
    return plan.type == type;
  }

  /// Get subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    final plan = await getCurrentPlan();
    final expiryMillis = _prefs.getInt(_keySubscriptionExpiry);

    DateTime? expiryDate;
    if (expiryMillis != null) {
      expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    }

    return SubscriptionStatus(
      plan: plan,
      isActive: plan.isPaid,
      expiryDate: expiryDate,
    );
  }

  /// Clear subscription (called on logout)
  Future<void> clearSubscription() async {
    await _prefs.remove(_keySubscriptionType);
    await _prefs.remove(_keySubscriptionExpiry);
  }

  /// Get days remaining in subscription
  Future<int?> getDaysRemaining() async {
    final expiryMillis = _prefs.getInt(_keySubscriptionExpiry);
    if (expiryMillis == null) return null;

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    final now = DateTime.now();

    if (now.isAfter(expiry)) return 0;

    return expiry.difference(now).inDays;
  }

  /// Check if subscription is expiring soon (within 3 days)
  Future<bool> isExpiringSoon() async {
    final daysRemaining = await getDaysRemaining();
    if (daysRemaining == null) return false;
    return daysRemaining <= 3 && daysRemaining > 0;
  }

  /// Mock payment processing
  Future<PaymentResult> processPayment({
    required SubscriptionPlan plan,
    required String paymentMethod,
    String? userId,
  }) async {
    // Mock success - always returns success for demo
    await subscribeToPlan(plan, userId: userId);
    return PaymentResult(
      success: true,
      transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      message: 'Payment successful',
    );
  }

  /// Mock payment (simplified version for UI)
  Future<bool> mockPayment(SubscriptionPlanType planType, String userId) async {
    final plan = SubscriptionPlans.getByType(planType);
    final result = await processPayment(
      plan: plan,
      paymentMethod: 'mock',
      userId: userId,
    );
    return result.success;
  }
}

/// Subscription Status Model
class SubscriptionStatus {
  final SubscriptionPlan plan;
  final bool isActive;
  final DateTime? expiryDate;

  SubscriptionStatus({
    required this.plan,
    required this.isActive,
    this.expiryDate,
  });

  bool get isFree => plan.type == SubscriptionPlanType.free;
  bool get isPremium => plan.type == SubscriptionPlanType.premium;
  bool get isElite => plan.type == SubscriptionPlanType.elite;

  String get displayName => plan.displayName;

  String get statusText {
    if (!isActive) return 'Not subscribed';
    if (expiryDate == null) return 'Active';

    final daysRemaining = expiryDate!.difference(DateTime.now()).inDays;
    if (daysRemaining <= 0) return 'Expired';
    if (daysRemaining <= 3) return 'Expiring soon ($daysRemaining days)';
    return 'Active ($daysRemaining days remaining)';
  }
}

/// Payment Result Model
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String message;

  PaymentResult({
    required this.success,
    this.transactionId,
    required this.message,
  });
}
