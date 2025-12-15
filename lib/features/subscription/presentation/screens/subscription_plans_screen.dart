import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/subscription_plan.dart';
import '../../../../core/services/subscription_service.dart';
import 'subscription_payment_screen.dart';

/// Helper to convert hex color string to Color
Color _colorFromHex(String hexColor) {
  final buffer = StringBuffer();
  if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
  buffer.write(hexColor.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// Subscription Plans Screen
/// Displays available subscription tiers for users to select
class SubscriptionPlansScreen extends StatefulWidget {
  final String userId;

  const SubscriptionPlansScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  late SubscriptionService _subscriptionService;
  SubscriptionPlan? _currentPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
  }

  Future<void> _loadCurrentPlan() async {
    _subscriptionService = await SubscriptionService.init();
    final plan = await _subscriptionService.getCurrentPlan();
    setState(() {
      _currentPlan = plan;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Unlock Premium Features',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the perfect plan for you',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Plan Cards
                  _buildPlanCard(
                    context,
                    SubscriptionPlans.free,
                    isCurrentPlan: _currentPlan?.type == SubscriptionPlanType.free,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    context,
                    SubscriptionPlans.premium,
                    isCurrentPlan: _currentPlan?.type == SubscriptionPlanType.premium,
                    isPopular: true,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    context,
                    SubscriptionPlans.elite,
                    isCurrentPlan: _currentPlan?.type == SubscriptionPlanType.elite,
                  ),

                  const SizedBox(height: 32),

                  // Benefits Section
                  const Text(
                    'Why Subscribe?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitItem(Icons.bookmark, 'Unlimited bookmarks'),
                  _buildBenefitItem(Icons.block, 'Ad-free experience'),
                  _buildBenefitItem(Icons.access_time, 'Early access to content'),
                  _buildBenefitItem(Icons.star, 'Premium badge'),
                  _buildBenefitItem(Icons.support_agent, 'Priority support'),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan, {
    bool isCurrentPlan = false,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrentPlan
              ? AppColors.primary
              : isPopular
                  ? AppColors.secondary
                  : Colors.grey.shade300,
          width: isCurrentPlan || isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: isCurrentPlan
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.white,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan Name & Badge
                Row(
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _colorFromHex(plan.badgeColor),
                      ),
                    ),
                    if (isCurrentPlan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.formattedPrice,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (plan.price > 0) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '/month',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Features
                ...plan.features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: _colorFromHex(plan.badgeColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),

                // Button
                if (!isCurrentPlan)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _selectPlan(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPopular
                            ? AppColors.secondary
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        plan.price > 0 ? 'Subscribe Now' : 'Select Free Plan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Popular Badge
          if (isPopular)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _selectPlan(SubscriptionPlan plan) {
    if (plan.price == 0) {
      // Free plan - just go back
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the Free plan')),
      );
    } else {
      // Navigate to payment screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionPaymentScreen(
            plan: plan,
            userId: widget.userId,
          ),
        ),
      );
    }
  }
}
