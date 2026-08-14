import 'api_service.dart';

class UserAddress {
  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final bool isDefault;

  UserAddress({
    required this.id,
    this.label = 'Rumah',
    required this.recipientName,
    required this.phone,
    required this.address,
    required this.city,
    required this.province,
    required this.postalCode,
    this.isDefault = false,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'].toString(),
      label: json['label'] ?? 'Rumah',
      recipientName: json['recipient_name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      postalCode: json['postal_code'] ?? '',
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }
}

class AddressService {
  static Future<List<UserAddress>> getAddresses() async {
    final result = await ApiService.get('user-addresses');
    if (result['status'] == true && result['data'] != null) {
      final data = result['data'];
      if (data is List) {
        return data.map((e) => UserAddress.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>> addAddress({
    String label = 'Rumah',
    required String recipientName,
    required String phone,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    bool isDefault = false,
  }) async {
    return ApiService.post('user-addresses', {
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'address': address,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'is_default': isDefault,
    });
  }

  static Future<Map<String, dynamic>> updateAddress({
    required String id,
    String? label,
    String? recipientName,
    String? phone,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    bool? isDefault,
  }) async {
    return ApiService.put('user-addresses/$id', {
      'label': ?label,
      'recipient_name': ?recipientName,
      'phone': ?phone,
      'address': ?address,
      'city': ?city,
      'province': ?province,
      'postal_code': ?postalCode,
      'is_default': ?isDefault,
    });
  }

  static Future<Map<String, dynamic>> setDefault(String id) async {
    return ApiService.put('user-addresses/$id/default', {});
  }

  static Future<Map<String, dynamic>> deleteAddress(String id) async {
    return ApiService.delete('user-addresses/$id');
  }
}
