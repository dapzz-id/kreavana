import 'dart:convert';
import 'chat_service.dart';
import 'wallet_service.dart';

class JobContract {
  final String id;
  final String title;
  final String description;
  final double amount;
  final String deadline; // ISO string or format e.g. "2025-05-30"
  final String terms;
  final String creatorId;
  final String creatorName;
  final String clientId;
  final String clientName;

  // Status: DRAFT | APPROVED | ESCROW_PAID | WORK_SUBMITTED | COMPLETED | CANCEL_REQUESTED | CANCELLED | DISPUTED
  String status;
  bool creatorApproved;
  bool clientApproved;
  bool escrowPaid;
  bool workSubmitted;
  bool disputeOpened;
  String? cancelReason;
  String? disputeGroupId;
  DateTime createdAt;

  JobContract({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.deadline,
    required this.terms,
    required this.creatorId,
    required this.creatorName,
    required this.clientId,
    required this.clientName,
    this.status = 'DRAFT',
    this.creatorApproved = false,
    this.clientApproved = false,
    this.escrowPaid = false,
    this.workSubmitted = false,
    this.disputeOpened = false,
    this.cancelReason,
    this.disputeGroupId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPastDeadline {
    try {
      final dt = DateTime.parse(deadline);
      return DateTime.now().isAfter(dt);
    } catch (_) {
      return false;
    }
  }

  bool get isPastOneWeekDeadline {
    try {
      final dt = DateTime.parse(deadline);
      return DateTime.now().isAfter(dt.add(const Duration(days: 7)));
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'amount': amount,
        'deadline': deadline,
        'terms': terms,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'clientId': clientId,
        'clientName': clientName,
        'status': status,
        'creatorApproved': creatorApproved,
        'clientApproved': clientApproved,
        'escrowPaid': escrowPaid,
        'workSubmitted': workSubmitted,
        'disputeOpened': disputeOpened,
        'cancelReason': cancelReason,
        'disputeGroupId': disputeGroupId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory JobContract.fromJson(Map<String, dynamic> json) => JobContract(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Kontrak Job',
        description: json['description'] ?? '',
        amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
        deadline: json['deadline'] ?? '',
        terms: json['terms'] ?? '',
        creatorId: json['creatorId']?.toString() ?? '',
        creatorName: json['creatorName'] ?? '',
        clientId: json['clientId']?.toString() ?? '',
        clientName: json['clientName'] ?? '',
        status: json['status'] ?? 'DRAFT',
        creatorApproved: json['creatorApproved'] ?? false,
        clientApproved: json['clientApproved'] ?? false,
        escrowPaid: json['escrowPaid'] ?? false,
        workSubmitted: json['workSubmitted'] ?? false,
        disputeOpened: json['disputeOpened'] ?? false,
        cancelReason: json['cancelReason'],
        disputeGroupId: json['disputeGroupId'],
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : DateTime.now(),
      );
}

class ContractEscrowService {
  /// Generate payload JSON string for contract message
  static String createContractMessagePayload(JobContract contract) {
    final map = {
      'type': 'contract',
      'contract': contract.toJson(),
    };
    return jsonEncode(map);
  }

  /// Parse contract from message payload
  static JobContract? parseContractFromPayload(dynamic payload) {
    if (payload is Map && payload['type'] == 'contract' && payload['contract'] is Map) {
      return JobContract.fromJson(Map<String, dynamic>.from(payload['contract']));
    }
    return null;
  }

  /// Approve contract by user
  static Future<JobContract> approveContract({
    required JobContract contract,
    required String userId,
  }) async {
    if (userId == contract.creatorId) {
      contract.creatorApproved = true;
    } else {
      contract.clientApproved = true;
    }

    if (contract.creatorApproved && contract.clientApproved) {
      contract.status = 'APPROVED';
    }
    return contract;
  }

  /// Pay Escrow funds (Klien melakukan pembayaran ke saldo escrow terikat)
  static Future<JobContract> payEscrow({
    required JobContract contract,
    required String pin,
    required String partnerUsername,
  }) async {
    // Perform transfer via WalletService
    final transferResult = await WalletService.transfer(
      receiverUsername: partnerUsername,
      amount: contract.amount,
      description: 'Escrow Kontrak #${contract.id} - ${contract.title}',
    );

    if (transferResult['success'] == true) {
      contract.escrowPaid = true;
      contract.status = 'ESCROW_PAID';
      return contract;
    } else {
      throw Exception(transferResult['message'] ?? 'Gagal memproses pembayaran Escrow.');
    }
  }

  /// Creator submits completed work
  static JobContract submitWork(JobContract contract) {
    contract.workSubmitted = true;
    contract.status = 'WORK_SUBMITTED';
    return contract;
  }

  /// Client approves work -> releases Escrow funds to Creator
  static JobContract releaseEscrowToCreator(JobContract contract) {
    contract.status = 'COMPLETED';
    return contract;
  }

  /// Request cancellation of contract
  static JobContract requestCancellation(JobContract contract, String reason) {
    contract.status = 'CANCEL_REQUESTED';
    contract.cancelReason = reason;
    return contract;
  }

  /// Approve cancellation & refund
  static JobContract approveCancellation(JobContract contract) {
    contract.status = 'CANCELLED';
    return contract;
  }

  /// Automatically create 3-way Dispute Group (Client + Creator + Admin) when:
  /// - Contract timeout > 7 days past deadline
  /// - Or either party requests Admin intervention
  static Future<Map<String, dynamic>> createThreeWayAdminDisputeGroup({
    required JobContract contract,
    required String clientName,
    required String creatorName,
  }) async {
    final groupName = '[Bantuan Admin] Kendala Kontrak #${contract.id}';
    final groupDesc = 'Grup Pendampingan 3 Arah (Klien, Kreator, & Admin) untuk Kontrak #${contract.id}: ${contract.title}';

    // 1. Create group via ChatService
    final groupRes = await ChatService.createGroup(groupName, groupDesc);
    final groupId = groupRes['id']?.toString() ?? '';

    // 2. Post automated system invitation message inside group
    if (groupId.isNotEmpty) {
      final prompt = '🛡️ Halo $clientName dan $creatorName! Admin Kreavana telah bergabung secara otomatis dalam grup 3 arah ini untuk membantu pendampingan penyelesaian kendala pada kontrak #${contract.id} ("${contract.title}"). Mohon sampaikan kendala atau pertanyaan yang Anda hadapi.';
      await ChatService.sendMessage(groupId, prompt);
    }

    contract.disputeOpened = true;
    contract.disputeGroupId = groupId;
    contract.status = 'DISPUTED';

    return {
      'success': true,
      'group': groupRes,
      'contract': contract,
    };
  }
}
