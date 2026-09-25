import 'package:kreavana/services/api_service.dart';

class StorageService {
  /// Mendapatkan riwayat penggunaan storage dan daftar file (aktif atau tempat sampah)
  static Future<Map<String, dynamic>> getHistory({
    int page = 1,
    String type = 'Semua',
    String sort = 'Terbaru',
    String category = 'Semua',
    bool isTrash = false,
  }) async {
    final trashParam = isTrash ? '&trash=1' : '';
    return ApiService.get(
      'storage/history?page=$page&type=$type&sort=$sort&category=$category$trashParam',
    );
  }

  /// Memindahkan file ke tempat sampah (soft delete, kuota tetap terpakai)
  static Future<Map<String, dynamic>> deleteFile(
    String id, {
    String? reason,
  }) async {
    final payload = reason != null ? {'reason': reason} : null;
    return ApiService.delete('storage/$id', data: payload);
  }

  /// Memindahkan banyak file sekaligus ke tempat sampah
  static Future<Map<String, dynamic>> deleteFiles(
    List<String> ids, {
    String? reason,
  }) async {
    return ApiService.post('storage/batch-delete', {
      'ids': ids,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  /// Memulihkan file dari tempat sampah ke file aktif
  static Future<Map<String, dynamic>> restoreFile(String id) async {
    return ApiService.post('storage/$id/restore', {});
  }

  /// Memulihkan banyak file sekaligus dari tempat sampah
  static Future<Map<String, dynamic>> restoreFiles(List<String> ids) async {
    return ApiService.post('storage/batch-restore', {
      'ids': ids,
    });
  }

  /// Menghapus file secara permanen dan membebaskan kuota storage
  static Future<Map<String, dynamic>> permanentDeleteFile(String id) async {
    return ApiService.delete('storage/$id/permanent');
  }

  /// Menghapus banyak file sekaligus secara permanen dan membebaskan kuota storage
  static Future<Map<String, dynamic>> permanentDeleteFiles(
    List<String> ids,
  ) async {
    return ApiService.post('storage/batch-permanent-delete', {
      'ids': ids,
    });
  }

  /// Mengosongkan tempat sampah (hapus permanen semua item di trash dan membebaskan kuota)
  static Future<Map<String, dynamic>> clearTrash() async {
    return ApiService.post('storage/clear-trash', {});
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
