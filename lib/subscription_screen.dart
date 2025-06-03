// lib/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_screen.dart';

class SubscriptionPreferences {
  static const String prefUserSubscriptionTier = 'user_subscription_tier_global_v2';
  static const String prefUserSubscriptionExpiry = 'user_subscription_expiry_global_v2';
  static const String prefUserCredit = 'user_credit_global_v2';
}

enum SubscriptionTier { none, standard, premium }

class SubscriptionPlan {
  final String id;
  final String name;
  final SubscriptionTier tier;
  final double price;
  final String displayPrice;
  final List<String> features;
  final Color highlightColor;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.tier,
    required this.price,
    required this.displayPrice,
    required this.features,
    required this.highlightColor,
  });
}

final List<SubscriptionPlan> subscriptionPlans = [
  SubscriptionPlan(
    id: 'standard_monthly',
    name: 'Standard Plan',
    tier: SubscriptionTier.standard,
    price: 50.0,
    displayPrice: '50 Credits / Month',
    features: [
      'Access to many songs (standard quality)',
      'Download 10 songs per month',
      'Ad-free listening (if ads exist)',
    ],
    highlightColor: Colors.blueAccent[200]!,
  ),
  SubscriptionPlan(
    id: 'premium_monthly',
    name: 'Premium Plan (VIP)',
    tier: SubscriptionTier.premium,
    price: 150.0,
    displayPrice: '150 Credits / Month',
    features: [
      'Access ALL songs (highest quality)',
      'Unlimited downloads',
      'Ad-free listening',
      'Early access to new releases',
    ],
    highlightColor: Colors.purpleAccent[100]!,
  ),
];

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionTier _currentUserTierUI = SubscriptionTier.none;
  DateTime? _subscriptionExpiryUI;
  SharedPreferences? _prefs;
  bool _hasSubscriptionChanged = false; // برای ردیابی تغییرات

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscriptionStatus();
  }

  Future<void> _loadCurrentSubscriptionStatus() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserTierUI = SubscriptionTier.values[
      _prefs!.getInt(SubscriptionPreferences.prefUserSubscriptionTier) ?? SubscriptionTier.none.index];
      final expiryMillis = _prefs!.getInt(SubscriptionPreferences.prefUserSubscriptionExpiry);
      _subscriptionExpiryUI = expiryMillis != null ? DateTime.fromMillisecondsSinceEpoch(expiryMillis) : null;

      if (_currentUserTierUI != SubscriptionTier.none &&
          _subscriptionExpiryUI != null &&
          _subscriptionExpiryUI!.isBefore(DateTime.now())) {
        _currentUserTierUI = SubscriptionTier.none;
        // اگر اشتراک منقضی شده، بهتر است از SharedPreferences هم پاک شود
        // _prefs!.remove(SubscriptionPreferences.prefUserSubscriptionTier);
        // _prefs!.remove(SubscriptionPreferences.prefUserSubscriptionExpiry);
      }
    });
  }

  Future<void> _subscribeToPlan(BuildContext context, SubscriptionPlan plan) async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();

    bool isActiveAndEqualOrHigher = _currentUserTierUI.index >= plan.tier.index &&
        (_subscriptionExpiryUI != null && _subscriptionExpiryUI!.isAfter(DateTime.now()));

    if (isActiveAndEqualOrHigher) {
      if (_currentUserTierUI == plan.tier) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You are already subscribed to ${plan.name}.')));
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You currently have a higher plan. To choose ${plan.name}, please cancel your current plan first.')));
        return;
      }
    }

    final paymentSuccessful = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: plan.price,
          itemName: "Subscription: ${plan.name}",
        ),
      ),
    );

    if (paymentSuccessful == true && mounted) {
      final newExpiryDate = DateTime.now().add(const Duration(days: 30));
      await _prefs!.setInt(SubscriptionPreferences.prefUserSubscriptionTier, plan.tier.index);
      await _prefs!.setInt(SubscriptionPreferences.prefUserSubscriptionExpiry, newExpiryDate.millisecondsSinceEpoch);
      _hasSubscriptionChanged = true; // تغییر رخ داده

      setState(() {
        _currentUserTierUI = plan.tier;
        _subscriptionExpiryUI = newExpiryDate;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully subscribed to ${plan.name}!')));
      // اینجا pop نمی‌کنیم تا کاربر بتواند نتیجه را ببیند، WillPopScope هندل می‌کند
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription payment failed or was cancelled.')));
    }
  }

  Future<void> _cancelSubscription() async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();

    bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Subscription'),
          content: const Text('Are you sure you want to cancel your current subscription? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Yes, Cancel'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmCancel == true && mounted) {
      await _prefs!.remove(SubscriptionPreferences.prefUserSubscriptionTier);
      await _prefs!.remove(SubscriptionPreferences.prefUserSubscriptionExpiry);
      _hasSubscriptionChanged = true; // تغییر رخ داده

      setState(() {
        _currentUserTierUI = SubscriptionTier.none;
        _subscriptionExpiryUI = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your subscription has been cancelled.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool isSubscriptionActiveAndNotExpired =
        _currentUserTierUI != SubscriptionTier.none &&
            (_subscriptionExpiryUI != null && _subscriptionExpiryUI!.isAfter(DateTime.now()));

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasSubscriptionChanged);
        return true; // اجازه بده صفحه بسته شود
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose Subscription'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasSubscriptionChanged),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: subscriptionPlans.length,
                  itemBuilder: (context, index) {
                    final plan = subscriptionPlans[index];
                    final bool isThisTheCurrentPlan = (isSubscriptionActiveAndNotExpired && _currentUserTierUI == plan.tier);

                    Widget actionButton;

                    if (isThisTheCurrentPlan) {
                      actionButton = ElevatedButton.icon(
                        icon: Icon(Icons.cancel_outlined, color: theme.colorScheme.onErrorContainer),
                        label: Text('Cancel Subscription', style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _cancelSubscription,
                      );
                    } else {
                      bool canChooseThisPlan = true;
                      String buttonText = 'Choose Plan';
                      Color buttonColor = plan.highlightColor;

                      // اگر کاربر اشتراک فعالی دارد که بالاتر از این پلن است، دکمه را غیرفعال کن
                      if (isSubscriptionActiveAndNotExpired && _currentUserTierUI.index > plan.tier.index) {
                        buttonText = 'Choose Plan'; // یا پیام دیگری مثل 'Downgrade not directly supported'
                        canChooseThisPlan = false; // دکمه غیرفعال می‌شود
                        buttonColor = Colors.grey[600]!;
                      }

                      actionButton = ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          disabledBackgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.grey[500],
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: canChooseThisPlan ? () => _subscribeToPlan(context, plan) : null,
                        child: Text(buttonText),
                      );
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(
                          color: isThisTheCurrentPlan ? plan.highlightColor : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(plan.name,
                                style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: plan.highlightColor)),
                            const SizedBox(height: 8),
                            Text(plan.displayPrice,
                                style: textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            Text('Features:',
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            ...plan.features.map((feature) => Padding(
                              padding: const EdgeInsets.only(top: 6.0, left: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 18, color: Colors.green[400]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(feature,
                                          style: textTheme.bodyMedium?.copyWith(
                                              color: colorScheme.onSurface.withOpacity(0.9)))),
                                ],
                              ),
                            )),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: actionButton,
                            ),
                            if (isThisTheCurrentPlan && _subscriptionExpiryUI != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Center(
                                  child: Text(
                                    "Active until: ${_subscriptionExpiryUI!.day}/${_subscriptionExpiryUI!.month}/${_subscriptionExpiryUI!.year}",
                                    style: textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // دکمه لغو کلی که قبلا اضافه کرده بودیم، با منطق جدید در کارت‌ها دیگر لازم نیست
              // مگر اینکه بخواهید یک دکمه لغو کلی جداگانه هم داشته باشید.
              // if (isSubscriptionActiveAndNotExpired)
              //   Padding(
              //     padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              //     child: OutlinedButton.icon(
              //       icon: Icon(Icons.cancel_outlined, color: colorScheme.error),
              //       label: Text("Cancel Current Subscription", style: TextStyle(color: colorScheme.error)),
              //       style: OutlinedButton.styleFrom(
              //         side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
              //         padding: const EdgeInsets.symmetric(vertical: 12.0),
              //       ),
              //       onPressed: _cancelSubscription,
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}