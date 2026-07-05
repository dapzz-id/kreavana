import 'api_service.dart';

class FollowService {
  static Future<Map<String, dynamic>> follow(String userId) async {
    return await ApiService.post('follow/$userId', {});
  }

  static Future<Map<String, dynamic>> unfollow(String userId) async {
    return await ApiService.delete('follow/$userId');
  }

  static Future<Map<String, dynamic>> getFollowers(String userId, {int page = 1}) async {
    return await ApiService.get('users/$userId/followers', queryParams: {'page': page.toString()});
  }

  static Future<Map<String, dynamic>> getFollowing(String userId, {int page = 1}) async {
    return await ApiService.get('users/$userId/following', queryParams: {'page': page.toString()});
  }
}
