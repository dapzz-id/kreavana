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
  final String? rawCreatorId;
  final String subRoleSlug;
  final String pitchMessage;
  final String? questionsNotes;
  final double? bidPrice;
  final double? counterOfferPrice;
  final String? counterOfferNotes;
  final String? counterOfferStatus; // 'pending', 'accepted', 'declined'
  final String? counterOfferBy; // 'client' or 'creator'
  final String paymentScheme; // 'full_at_end' | 'term'
  final List<Map<String, dynamic>> paymentTerms;
  final double paidAmount;
  final String paymentStatus; // 'unpaid' | 'partially_paid' | 'paid'
  final int workerProgress; // 0 - 100
  final String workerStatus; // 'assigned' | 'in_progress' | 'submitted' | 'completed'
  final List<Map<String, dynamic>> submittedDeliverables;
  final String? gracePeriodDeadline;
  final String? autoReleasedAt;
  final String status;
  final String? rejectionReason;
  final String? reviewedAt;
  final String? createdAt;
  final List<Map<String, dynamic>> submittedDocuments;
  final String? creatorSignature;
  final String? creatorSignedAt;
  final List<String> dynamicTerms;

  OpportunityApplicationModel({
    required this.id,
    required this.opportunityId,
    this.creator,
    this.rawCreatorId,
    required this.subRoleSlug,
    required this.pitchMessage,
    this.questionsNotes,
    this.bidPrice,
    this.counterOfferPrice,
    this.counterOfferNotes,
    this.counterOfferStatus,
    this.counterOfferBy,
    this.paymentScheme = 'full_at_end',
    this.paymentTerms = const [],
    this.paidAmount = 0.0,
    this.paymentStatus = 'unpaid',
    this.workerProgress = 0,
    this.workerStatus = 'assigned',
    this.submittedDeliverables = const [],
    this.gracePeriodDeadline,
    this.autoReleasedAt,
    this.status = 'pending',
    this.rejectionReason,
    this.reviewedAt,
    this.createdAt,
    this.submittedDocuments = const [],
    this.creatorSignature,
    this.creatorSignedAt,
    this.dynamicTerms = const [],
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isConsideration => status == 'under_consideration';
  bool get isCreatorSigned => creatorSignedAt != null && creatorSignedAt!.isNotEmpty;
  bool get isCounterOfferByCreator => counterOfferBy == 'creator';
  bool get isCounterOfferByClient => counterOfferBy != 'creator';
  bool get isTermPayment => paymentScheme == 'term';
  bool get isFullyPaid => paymentStatus == 'paid' || (bidPrice != null && paidAmount >= (counterOfferPrice ?? bidPrice!));
  double get agreedFee => counterOfferPrice ?? bidPrice ?? 0.0;
  double get remainingUnpaidFee => (agreedFee - paidAmount).clamp(0.0, double.infinity);
  String get creatorId => (rawCreatorId != null && rawCreatorId!.isNotEmpty) ? rawCreatorId! : (creator?.id ?? '');

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
      for (final e in (json['submitted_documents'] as List)) {
        if (e is Map) {
          docs.add(Map<String, dynamic>.from(e));
        } else if (e is String && e.isNotEmpty) {
          docs.add({'name': e.split('/').last, 'url': e});
        }
      }
    }

    List<Map<String, dynamic>> terms = [];
    if (json['payment_terms'] is List) {
      for (final e in (json['payment_terms'] as List)) {
        if (e is Map) {
          terms.add(Map<String, dynamic>.from(e));
        }
      }
    }

    List<Map<String, dynamic>> deliverables = [];
    if (json['submitted_deliverables'] is List) {
      for (final e in (json['submitted_deliverables'] as List)) {
        if (e is Map) {
          deliverables.add(Map<String, dynamic>.from(e));
        }
      }
    }

    return OpportunityApplicationModel(
      id: json['id']?.toString() ?? '',
      opportunityId: json['opportunity_id']?.toString() ?? '',
      creator: json['creator'] != null ? OpportunityApplicantModel.fromJson(json['creator']) : null,
      rawCreatorId: json['creator_id']?.toString() ??
          (json['creator'] is Map ? json['creator']['id']?.toString() : null),
      subRoleSlug: json['sub_role_slug'] ?? '',
      pitchMessage: json['pitch_message'] ?? '',
      questionsNotes: json['questions_notes'],
      bidPrice: json['bid_price'] != null ? double.tryParse(json['bid_price'].toString()) : null,
      counterOfferPrice: json['counter_offer_price'] != null ? double.tryParse(json['counter_offer_price'].toString()) : null,
      counterOfferNotes: json['counter_offer_notes']?.toString(),
      counterOfferStatus: json['counter_offer_status']?.toString(),
      counterOfferBy: json['counter_offer_by']?.toString() ?? 'client',
      paymentScheme: json['payment_scheme']?.toString() ?? 'full_at_end',
      paymentTerms: terms,
      paidAmount: json['paid_amount'] != null ? (double.tryParse(json['paid_amount'].toString()) ?? 0.0) : 0.0,
      paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
      workerProgress: json['worker_progress'] != null ? (int.tryParse(json['worker_progress'].toString()) ?? 0) : 0,
      workerStatus: json['worker_status']?.toString() ?? 'assigned',
      submittedDeliverables: deliverables,
      gracePeriodDeadline: json['grace_period_deadline']?.toString(),
      autoReleasedAt: json['auto_released_at']?.toString(),
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      reviewedAt: json['reviewed_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      submittedDocuments: docs,
      creatorSignature: json['creator_signature']?.toString(),
      creatorSignedAt: json['creator_signed_at']?.toString(),
      dynamicTerms: json['dynamic_terms'] is List
          ? (json['dynamic_terms'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}
