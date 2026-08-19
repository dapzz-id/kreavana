import 'dart:convert';
import 'chat_service.dart';
import 'wallet_service.dart';

import '../models/job_contract.dart';

class ContractEscrowService {
  /// Generate payload JSON string for contract message
  static String createContractMessagePayload(JobContract contract) {
    final map = {'type': 'contract', 'contract': contract.toJson()};
    return jsonEncode(map);
  }

  /// Parse contract from message payload
  static JobContract? parseContractFromPayload(dynamic payload) {
    if (payload is Map &&
        payload['type'] == 'contract' &&
        payload['contract'] is Map) {
      return JobContract.fromJson(
        Map<String, dynamic>.from(payload['contract']),
      );
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
      contract.contractStatus = 'active';
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
      contract.workStatus = 'in_progress';
      return contract;
    } else {
      throw Exception(
        transferResult['message'] ?? 'Gagal memproses pembayaran Escrow.',
      );
    }
  }

  /// Creator submits completed work
  static JobContract submitWork(JobContract contract) {
    contract.workSubmitted = true;
    contract.workStatus = 'submitted';
    return contract;
  }

  /// Client approves work -> releases Escrow funds to Creator
  static JobContract releaseEscrowToCreator(JobContract contract) {
    contract.contractStatus = 'completed';
    contract.workStatus = 'done';
    return contract;
  }

  /// Request cancellation of contract
  static JobContract requestCancellation(JobContract contract, String reason) {
    contract.contractStatus = 'proposed';
    contract.cancelReason = reason;
    return contract;
  }

  /// Approve cancellation & refund
  static JobContract approveCancellation(JobContract contract) {
    contract.contractStatus = 'cancelled';
    contract.workStatus = 'cancelled'; // If work was started
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
    final groupDesc =
        'Grup Pendampingan 3 Arah (Klien, Kreator, & Admin) untuk Kontrak #${contract.id}: ${contract.title}';

    // 1. Create group via ChatService
    final groupRes = await ChatService.createGroup(groupName, groupDesc);
    final groupId = groupRes['id']?.toString() ?? '';

    // 2. Post automated system invitation message inside group
    if (groupId.isNotEmpty) {
      final prompt =
          '🛡️ Halo $clientName dan $creatorName! Admin Kreavana telah bergabung secara otomatis dalam grup 3 arah ini untuk membantu pendampingan penyelesaian kendala pada kontrak #${contract.id} ("${contract.title}"). Mohon sampaikan kendala atau pertanyaan yang Anda hadapi.';
      await ChatService.sendMessage(groupId, prompt);
    }

    contract.disputeOpened = true;
    contract.disputeGroupId = groupId;
    contract.contractStatus = 'disputed';

    return {'success': true, 'group': groupRes, 'contract': contract};
  }
}
