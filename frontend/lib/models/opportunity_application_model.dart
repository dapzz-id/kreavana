class OpportunityApplicantModel {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? subRole;
  final double rating;
  final String subscriptionTier;
  final bool isVerified;
  final int completedProjectsCount;

  OpportunityApplicantModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.subRole,
    this.rating = 5.0,
    this.subscriptionTier = 'free',
    this.isVerified = false,
    this.completedProjectsCount = 0,
  });

  bool get isUpgraded =>
      subscriptionTier.toLowerCase() == 'plus' ||
      subscriptionTier.toLowerCase() == 'pro' ||
      subscriptionTier.toLowerCase() == 'super';

  factory OpportunityApplicantModel.fromJson(Map<String, dynamic> json) {
    return OpportunityApplicantModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      subRole: json['sub_role'],
      rating: json['rating'] != null ? (double.tryParse(json['rating'].toString()) ?? 5.0) : 5.0,
      subscriptionTier: json['subscription_tier']?.toString() ?? 'free',
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      completedProjectsCount: json['completed_projects_count'] != null
          ? int.tryParse(json['completed_projects_count'].toString()) ?? 0
          : 0,
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
  final List<Map<String, dynamic>> submittedDocuments;

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
    this.submittedDocuments = const [],
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  String get creatorId => creator?.id ?? '';

  String get subRoleLabel {
    switch (subRoleSlug) {
      case 'tukang_kendang':
        return '🥁 Tukang Kendang';
      case 'photographer':
      case 'fotografi':
        return '📸 Fotografer';
      case 'videographer':
      case 'videografi':
        return '🎥 Videografer';
      case 'editor':
        return '✂️ Editor';
      case 'mc':
        return '🎤 Master of Ceremony';
      case 'event_organizer':
        return '🎪 Event Organizer';
      case 'wedding_organizer':
        return '💍 Wedding Organizer';
      case 'makeup_artist':
        return '💄 MUA';
      case 'desain-grafis':
      case 'designer':
        return '🎨 Desainer';
      default:
        return subRoleSlug.replaceAll('_', ' ').replaceAll('-', ' ');
    }
  }

  factory OpportunityApplicationModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> docs = [];
    if (json['submitted_documents'] is List) {
      docs = (json['submitted_documents'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

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
      submittedDocuments: docs,
    );
  }
}
