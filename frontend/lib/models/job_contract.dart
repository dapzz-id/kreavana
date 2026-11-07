class JobContract {
  final String id;
  final String clientId;
  final String creatorId;
  final String? opportunityId;
  final String? creatorServiceId;
  final String title;
  final String? description;
  final String? terms;
  final List<String> dynamicTerms;
  final String? contractNumber;
  final String? creatorSignature;
  final DateTime? creatorSignedAt;
  final String? clientSignature;
  final DateTime? clientSignedAt;
  final String? adminName;
  final String? adminSignatureUrl;
  final DateTime? adminSignedAt;
  final double agreedPrice;
  final double escrowAmount;
  String contractStatus;
  String workStatus;
  final DateTime? scheduledStartDate;
  final DateTime? scheduledEndDate;
  final DateTime? deadline;
  bool creatorApproved;
  bool clientApproved;
  bool escrowPaid;
  bool workSubmitted;
  bool disputeOpened;
  String? disputeGroupId;
  String? cancelReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Optional nested relationships & parties
  final Map<String, dynamic>? creator;
  final Map<String, dynamic>? client;
  final Map<String, dynamic>? partyClient;
  final Map<String, dynamic>? partyCreator;
  final Map<String, dynamic>? partyAdmin;

  JobContract({
    required this.id,
    required this.clientId,
    required this.creatorId,
    this.opportunityId,
    this.creatorServiceId,
    required this.title,
    this.description,
    this.terms,
    this.dynamicTerms = const [],
    this.contractNumber,
    this.creatorSignature,
    this.creatorSignedAt,
    this.clientSignature,
    this.clientSignedAt,
    this.adminName,
    this.adminSignatureUrl,
    this.adminSignedAt,
    required this.agreedPrice,
    required this.escrowAmount,
    required this.contractStatus,
    required this.workStatus,
    this.scheduledStartDate,
    this.scheduledEndDate,
    this.deadline,
    this.creatorApproved = false,
    this.clientApproved = false,
    this.escrowPaid = false,
    this.workSubmitted = false,
    this.disputeOpened = false,
    this.disputeGroupId,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
    this.creator,
    this.client,
    this.partyClient,
    this.partyCreator,
    this.partyAdmin,
  });

  factory JobContract.fromJson(Map<String, dynamic> json) {
    List<String> parsedTerms = [];
    if (json['dynamic_terms'] is List) {
      parsedTerms = (json['dynamic_terms'] as List).map((e) => e.toString()).toList();
    }

    return JobContract(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      creatorId: json['creator_id']?.toString() ?? '',
      opportunityId: json['opportunity_id']?.toString(),
      creatorServiceId: json['creator_service_id']?.toString(),
      title: json['title'] ?? '',
      description: json['description'],
      terms: json['terms'],
      dynamicTerms: parsedTerms,
      contractNumber: json['contract_number']?.toString(),
      creatorSignature: json['creator_signature']?.toString() ?? json['party_creator']?['signature']?.toString(),
      creatorSignedAt: json['creator_signed_at'] != null
          ? DateTime.tryParse(json['creator_signed_at'].toString())
          : (json['party_creator']?['signed_at'] != null
              ? DateTime.tryParse(json['party_creator']['signed_at'].toString())
              : null),
      clientSignature: json['client_signature']?.toString() ?? json['party_client']?['signature']?.toString(),
      clientSignedAt: json['client_signed_at'] != null
          ? DateTime.tryParse(json['client_signed_at'].toString())
          : (json['party_client']?['signed_at'] != null
              ? DateTime.tryParse(json['party_client']['signed_at'].toString())
              : null),
      adminName: json['admin_name']?.toString() ?? json['party_admin']?['name']?.toString(),
      adminSignatureUrl: json['admin_signature_url']?.toString() ?? json['party_admin']?['signature_url']?.toString(),
      adminSignedAt: json['admin_signed_at'] != null
          ? DateTime.tryParse(json['admin_signed_at'].toString())
          : (json['party_admin']?['signed_at'] != null
              ? DateTime.tryParse(json['party_admin']['signed_at'].toString())
              : null),
      agreedPrice:
          double.tryParse(json['agreed_price']?.toString() ?? '0') ?? 0.0,
      escrowAmount:
          double.tryParse(json['escrow_amount']?.toString() ?? '0') ?? 0.0,
      contractStatus: json['contract_status'] ?? 'pending',
      workStatus: json['work_status'] ?? 'pending',
      scheduledStartDate: json['scheduled_start_date'] != null
          ? DateTime.tryParse(json['scheduled_start_date'])
          : null,
      scheduledEndDate: json['scheduled_end_date'] != null
          ? DateTime.tryParse(json['scheduled_end_date'])
          : null,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'])
          : null,
      creatorApproved: json['creator_approved'] ?? false,
      clientApproved: json['client_approved'] ?? false,
      escrowPaid: json['escrow_paid'] ?? false,
      workSubmitted: json['work_submitted'] ?? false,
      disputeOpened: json['dispute_opened'] ?? false,
      disputeGroupId: json['dispute_group_id']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      creator: json['creator'],
      client: json['client'],
      partyClient: json['party_client'],
      partyCreator: json['party_creator'],
      partyAdmin: json['party_admin'],
    );
  }

  // Legacy UI Getters
  double get amount => agreedPrice;
  String get creatorName => creator?['name'] ?? 'Kreator';
  String get clientName => client?['name'] ?? 'Klien';
  String get status => contractStatus;
  bool get isCompleted =>
      contractStatus.toLowerCase() == 'completed' ||
      workStatus.toLowerCase() == 'completed';

  bool get isPastDeadline {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!);
  }

  bool get isPastOneWeekDeadline {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!.add(const Duration(days: 7)));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'creator_id': creatorId,
      'opportunity_id': opportunityId,
      'creator_service_id': creatorServiceId,
      'title': title,
      'description': description,
      'terms': terms,
      'agreed_price': agreedPrice,
      'escrow_amount': escrowAmount,
      'contract_status': contractStatus,
      'work_status': workStatus,
      'creator_approved': creatorApproved,
      'client_approved': clientApproved,
      'escrow_paid': escrowPaid,
      'work_submitted': workSubmitted,
      'dispute_opened': disputeOpened,
      'dispute_group_id': disputeGroupId,
      'cancel_reason': cancelReason,
    };
  }
}
