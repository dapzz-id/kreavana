class RecommendationCreatorModel {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? subRole;
  final double performanceBoost;
  final int positiveMarketplaceReviewsCount;
  final int positiveContractReviewsCount;
  final double rating;
  final List<String> serviceCategories;

  RecommendationCreatorModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.subRole,
    this.performanceBoost = 1.0,
    this.positiveMarketplaceReviewsCount = 0,
    this.positiveContractReviewsCount = 0,
    this.rating = 0.0,
    this.serviceCategories = const [],
  });

  factory RecommendationCreatorModel.fromJson(Map<String, dynamic> json) {
    return RecommendationCreatorModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      subRole: json['sub_role']?.toString(),
      performanceBoost: json['performance_boost'] != null
          ? double.tryParse(json['performance_boost'].toString()) ?? 1.0
          : 1.0,
      positiveMarketplaceReviewsCount:
          json['positive_marketplace_reviews_count'] != null
          ? int.tryParse(
                  json['positive_marketplace_reviews_count'].toString(),
                ) ??
                0
          : 0,
      positiveContractReviewsCount:
          json['positive_contract_reviews_count'] != null
          ? int.tryParse(json['positive_contract_reviews_count'].toString()) ??
                0
          : 0,
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString()) ?? 0.0
          : 0.0,
      serviceCategories:
          json['service_categories'] != null &&
              json['service_categories'] is List
          ? (json['service_categories'] as List)
                .map((e) => e.toString())
                .toList()
          : [],
    );
  }
}
