import '../../../models/opportunity_model.dart';
import '../../../services/api_service.dart';

class DashboardService {
  /// Ambil stats dashboard berdasarkan subRole dan role
  static Future<List<Map<String, String>>> getStats({
    required String subRole,
    required String roleType,
  }) async {
    final result = await ApiService.get(
      'dashboard/stats',
      queryParams: {'sub_role_slug': subRole, 'role_type': roleType},
    );

    if (result['status'] == true && result['data'] != null) {
      final List<dynamic> data = result['data'];
      return data
          .map(
            (item) => {
              'label': (item['label'] ?? item['stat_label'] ?? '').toString(),
              'value': (item['value'] ?? item['stat_value'] ?? '').toString(),
              'icon': (item['icon'] ?? item['stat_icon'] ?? '').toString(),
            },
          )
          .toList();
    }

    return [];
  }

  static Future<Map<String, dynamic>> getClientDashboardOverview({
    required String roleType,
  }) async {
    final result = await ApiService.get(
      'client-dashboard/overview',
      queryParams: {'role_type': roleType},
    );

    if (result['status'] == true && result['data'] != null) {
      return result['data'] as Map<String, dynamic>;
    }

    return {
      'summary': {
        'active_needs': 0,
        'proposals_count': 0,
        'running_projects': 0,
        'estimated_expenses': 'Rp 0',
        'total_projects': 0,
        'active_projects': 0,
        'total_payments': 'Rp 0',
        'pending_payments': 'Rp 0',
        'favorites': 0,
      },
      'client_types': [],
      'activity_feed': [],
      'vendor_recommendations': [],
      'project_needs': [],
      'agenda': [],
      'project_assets': [],
    };
  }

  /// Ambil statistik untuk semua kategori subRole sekaligus
  static Future<Map<String, List<Map<String, String>>>> getAllSubRoleStats({
    required List<String> subRoleSlugs,
    required String roleType,
  }) async {
    final results = await Future.wait(
      subRoleSlugs.map((slug) => getStats(subRole: slug, roleType: roleType)),
    );

    return {
      for (var i = 0; i < subRoleSlugs.length; i++) subRoleSlugs[i]: results[i],
    };
  }

  /// Parse nilai statistik ke angka untuk grafik
  static double parseStatNumeric(String raw) {
    var s = raw.replaceAll('%', '').trim();
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }

  /// Ambil peluang/opportunities berdasarkan subRole
  static Future<List<OpportunityModel>> getOpportunities({
    required String subRole,
    int limit = 5,
  }) async {
    final result = await ApiService.get(
      'dashboard/opportunities',
      queryParams: {'sub_role_slug': subRole, 'limit': limit.toString()},
    );

    if (result['status'] == true && result['data'] != null) {
      final List<dynamic> data = result['data'];
      if (data.isNotEmpty) {
        return data.map((item) => OpportunityModel.fromJson(item)).toList();
      }
    }

    return [];
  }
}
