import 'package:kreavana/services/api_service.dart';

class StorageService {
  /// Mendapatkan riwayat penggunaan storage dan daftar file
  static Future<Map<String, dynamic>> getHistory({
    int page = 1,
    String type = 'Semua',
    String sort = 'Terbaru',
    String category = 'Semua',
  }) async {
    return ApiService.get(
      'storage/history?page=$page&type=$type&sort=$sort&category=$category',
    );
  }

  /// Menghapus file dari storage dengan memberikan alasan opsional
  static Future<Map<String, dynamic>> deleteFile(
    String id, {
    String? reason,
  }) async {
    final payload = reason != null ? {'reason': reason} : null;
    return ApiService.delete('storage/$id', data: payload);
  }

  /// Mengecek status file (apakah aktif, deleted, atau tidak ditemukan)
  static Future<Map<String, dynamic>> checkFileStatus(String idOrName) async {
    return ApiService.get('storage/file/$idOrName/status');
  }

  /// Melakukan retry clone untuk asset yang purchased tapi pending
  static Future<Map<String, dynamic>> retryPurchasedClone(String id) async {
    return ApiService.post('storage/purchased/$id/retry', {});
  }
}
