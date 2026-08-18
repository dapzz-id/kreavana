import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/recommendation_creator_model.dart';

void main() {
  group('RecommendationCreatorModel Parsing', () {
    test('Handles complete data correctly', () {
      final json = {
        "id": "uuid-1",
        "name": "John Doe",
        "username": "johndoe",
        "sub_role": "event_organizer",
        "performance_boost": 12.50,
        "positive_marketplace_reviews_count": 18,
        "positive_contract_reviews_count": 11,
        "rating": 4.8,
        "service_categories": ["wedding", "corporate"],
      };

      final model = RecommendationCreatorModel.fromJson(json);

      expect(model.id, 'uuid-1');
      expect(model.name, 'John Doe');
      expect(model.subRole, 'event_organizer');
      expect(model.performanceBoost, 12.50);
      expect(model.positiveMarketplaceReviewsCount, 18);
      expect(model.positiveContractReviewsCount, 11);
      expect(model.rating, 4.8);
      expect(model.serviceCategories, ["wedding", "corporate"]);
    });

    test('Handles empty optional fields', () {
      final json = {"id": "uuid-2", "name": "Jane", "username": "jane"};

      final model = RecommendationCreatorModel.fromJson(json);

      expect(model.id, 'uuid-2');
      expect(model.subRole, null);
      expect(model.performanceBoost, 1.0);
      expect(model.positiveMarketplaceReviewsCount, 0);
      expect(model.positiveContractReviewsCount, 0);
      expect(model.rating, 0.0);
      expect(model.serviceCategories, []);
    });
  });
}
