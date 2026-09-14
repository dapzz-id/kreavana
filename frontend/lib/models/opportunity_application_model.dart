class OpportunityApplicantModel {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? subRole;
  final double rating;

  OpportunityApplicantModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.subRole,
    this.rating = 5.0,
  });

  factory OpportunityApplicantModel.fromJson(Map<String, dynamic> json) {
    return OpportunityApplicantModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      subRole: json['sub_role'],
      rating: json['rating'] != null ? (double.tryParse(json['rating'].toString()) ?? 5.0) : 5.0,
    );
  }
}

class OpportunityApplicationModel {
  final String id;
  final String opportunityId;
  final OpportunityApplicantModel? creator;
  final String subRoleSlug;
  final String pitchMessage;
  final String? questionsNotes;
  final double? bidPrice;
  final String status;
  final String? rejectionReason;
  final String? reviewedAt;
  final String? createdAt;

  OpportunityApplicationModel({
    required this.id,
    required this.opportunityId,
    this.creator,
    required this.subRoleSlug,
    required this.pitchMessage,
    this.questionsNotes,
    this.bidPrice,
    this.status = 'pending',
    this.rejectionReason,
    this.reviewedAt,
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get subRoleLabel {
    switch (subRoleSlug) {
      case 'tukang_kendang':
        return '🥁 Tukang Kendang';
      case 'photographer':
        return '📸 Fotografer';
      case 'videographer':
        return '🎥 Videografer';
      case 'mc':
        return '🎤 Master of Ceremony';
      default:
        return subRoleSlug;
    }
  }

  factory OpportunityApplicationModel.fromJson(Map<String, dynamic> json) {
    return OpportunityApplicationModel(
      id: json['id']?.toString() ?? '',
      opportunityId: json['opportunity_id']?.toString() ?? '',
      creator: json['creator'] != null ? OpportunityApplicantModel.fromJson(json['creator']) : null,
      subRoleSlug: json['sub_role_slug'] ?? '',
      pitchMessage: json['pitch_message'] ?? '',
      questionsNotes: json['questions_notes'],
      bidPrice: json['bid_price'] != null ? double.tryParse(json['bid_price'].toString()) : null,
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      reviewedAt: json['reviewed_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
