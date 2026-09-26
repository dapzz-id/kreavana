import '../services/api_service.dart';

/// Data model for one subscription plan (received from backend).
class SubscriptionPlan {
  final String tier;
  final String name;
  final int price; // in IDR cents (e.g. 69999)
  final String label; // display string e.g. "Rp 69.999 / bln"
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
      tier: json['tier']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Paket',
      price: (json['price'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? 'Hubungi kami',
      features: (json['features'] as List<dynamic>? ?? [])
          .map((feature) => feature.toString())
          .toList(),
      isPopular: json['is_popular'] == true,
      isFree: ((json['price'] as num?)?.toInt() ?? 0) == 0,
    );
  }
  SubscriptionPlan copyWith({
    String? tier,
    String? name,
    int? price,
    String? label,
    List<String>? features,
    bool? isPopular,
    bool? isFree,
  }) {
    return SubscriptionPlan(
      tier: tier ?? this.tier,
      name: name ?? this.name,
      price: price ?? this.price,
      label: label ?? this.label,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      isFree: isFree ?? this.isFree,
    );
  }
}

class SubscriptionService {
  /// Fetch all available plans from the backend.
  /// Prices come from the server whenever it is reachable.
  static Future<List<SubscriptionPlan>> getPlans({String? role}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (role != null) {
        queryParams['role'] = role;
      }
      final response = await ApiService.get(
        'subscription/plans',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response['status'] == false) {
        throw Exception(response['message'] ?? 'Gagal memuat paket');
      }

      final rawData = response['data'];
      if (rawData is! List) {
        throw Exception('Format data paket tidak valid');
      }

      final plans = rawData
          .whereType<Map>()
          .map((plan) => SubscriptionPlan.fromJson(
                Map<String, dynamic>.from(plan),
              ))
          .toList();
      return plans.isEmpty ? fallbackPlans(role: role) : plans;
    } catch (_) {
      return fallbackPlans(role: role);
    }
  }

  static List<SubscriptionPlan> fallbackPlans({String? role}) {
    final isCreator = role?.toLowerCase() == 'creator';
    List<String> features(List<String> values) => isCreator
        ? values
        : values.where((feature) => !feature.contains('Boost')).toList();

    return [
      const SubscriptionPlan(
        tier: 'basic',
        name: 'Basic',
        price: 0,
        label: 'Saat ini',
        features: ['Durasi call standar', 'Storage bawaan'],
        isPopular: false,
        isFree: true,
      ),
      SubscriptionPlan(
        tier: 'plus',
        name: 'Plus',
        price: 69999,
        label: 'Rp 69.999 / bln',
        features: features([
          'Boost akun 1.5x',
          'Voice call: 80 menit',
          'Video call: 45 menit',
          'Storage 3 GB',
          'Rekomendasi AI',
        ]),
        isPopular: false,
      ),
      SubscriptionPlan(
        tier: 'pro',
        name: 'Pro',
        price: 199999,
        label: 'Rp 199.999 / bln',
        features: features([
          'Boost akun 2x',
          'Voice call: 100 menit',
          'Video call: 60 menit',
          'Storage 10 GB',
          'Fitur AI & Rekomendasi Pintar',
        ]),
        isPopular: true,
      ),
      SubscriptionPlan(
        tier: 'super',
        name: 'Super',
        price: 379999,
        label: 'Rp 379.999 / bln',
        features: features([
          'Boost akun 5x',
          'Voice call: 120 menit',
          'Video call: 75 menit',
          'Storage 20 GB',
          'Fitur AI & Rekomendasi Pintar',
          'Layanan Prioritas',
        ]),
        isPopular: false,
      ),
    ];
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
