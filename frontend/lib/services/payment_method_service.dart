import 'api_service.dart';

class PaymentMethod {
  final String id;
  final String type; // bank | ewallet
  final String provider;
  final String accountName;
  final String accountNumber;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.provider,
    required this.accountName,
    required this.accountNumber,
    this.isDefault = false,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'].toString(),
      type: json['type'] ?? 'bank',
      provider: json['provider'] ?? '',
      accountName: json['account_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }
}

class PaymentMethodService {
  static Future<List<PaymentMethod>> getMethods() async {
    final result = await ApiService.get('payment-methods');
    if (result['status'] == true && result['data'] != null) {
      final data = result['data'];
      if (data is List) {
        return data
            .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>> addMethod({
    required String type,
    required String provider,
    required String accountName,
    required String accountNumber,
    bool isDefault = false,
  }) async {
    return ApiService.post('payment-methods', {
      'type': type,
      'provider': provider,
      'account_name': accountName,
      'account_number': accountNumber,
      'is_default': isDefault,
    });
  }

  static Future<Map<String, dynamic>> updateMethod({
    required String id,
    String? type,
    String? provider,
    String? accountName,
    String? accountNumber,
    bool? isDefault,
  }) async {
    return ApiService.put('payment-methods/$id', {
      'type': ?type,
      'provider': ?provider,
      'account_name': ?accountName,
      'account_number': ?accountNumber,
      'is_default': ?isDefault,
    });
  }

  static Future<Map<String, dynamic>> setDefault(String id) async {
    return ApiService.put('payment-methods/$id/default', {});
  }

  static Future<Map<String, dynamic>> deleteMethod(String id) async {
    return ApiService.delete('payment-methods/$id');
  }
}
