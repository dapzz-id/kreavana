import '../services/api_service.dart';

/// Data model for one subscription plan (received from backend).
class SubscriptionPlan {
  final String tier;
  final String name;
  final int price;        // in IDR cents (e.g. 69999)
  final String label;     // display string e.g. "Rp 69.999 / bln"
  final List<String> features;
  final bool isPopular;
  final bool isFree;

  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.price,
    required this.label,
    required this.features,
    required this.isPopular,
    this.isFree = false,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      tier:       json['tier'] as String,
      name:       json['name'] as String,
      price:      (json['price'] as num).toInt(),
      label:      json['label'] as String,
      features:   List<String>.from(json['features'] ?? []),
      isPopular:  json['is_popular'] == true,
      isFree:     (json['price'] as num).toInt() == 0,
    );
  }
}

class SubscriptionService {
  /// Fetch all available plans from the backend.
  /// Prices come from the server — never hardcode them in the UI.
  static Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final response = await ApiService.get('subscription/plans');
      final List<dynamic> data = response['data'] ?? [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Purchase a plan by tier name. Sends only the identifier + wallet PIN.
  /// The backend verifies the PIN and looks up the correct price server-side.
  static Future<Map<String, dynamic>?> purchase(
    String tier, {
    required String pin,
    bool autoRenew = false,
  }) {
    return ApiService.post('subscription/purchase', {
      'tier': tier,
      'pin': pin,
      'auto_renew': autoRenew,
    });
  }
}
