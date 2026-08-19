import 'package:flutter/material.dart';
import '../services/contract_escrow_service.dart';
import '../models/job_contract.dart';

class ContractCardWidget extends StatelessWidget {
  final JobContract contract;
  final String currentUserId;
  final Function(JobContract updatedContract) onContractUpdated;
  final VoidCallback onOpenDisputeGroup;

  const ContractCardWidget({
    super.key,
    required this.contract,
    required this.currentUserId,
    required this.onContractUpdated,
    required this.onOpenDisputeGroup,
  });

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isCreator = currentUserId == contract.creatorId;
    final isClient = currentUserId == contract.clientId;

    Color statusColor = Colors.grey;
    String statusText = 'Draft';

    if (contract.contractStatus == 'active' &&
        contract.workStatus == 'pending') {
      statusColor = const Color(0xFF3B82F6);
      statusText = 'Disetujui kedua pihak';
    } else if (contract.contractStatus == 'active' &&
        contract.workStatus == 'in_progress') {
      statusColor = const Color(0xFF10B981);
      statusText = 'Escrow Terisi - Pekerjaan Berlangsung';
    } else if (contract.contractStatus == 'active' &&
        contract.workStatus == 'submitted') {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Hasil Pekerjaan Dikirim';
    } else if (contract.contractStatus == 'completed') {
      statusColor = const Color(0xFF10B981);
      statusText = 'Selesai & Dana Dicairkan';
    } else if (contract.contractStatus == 'proposed') {
      statusColor = const Color(0xFFEF4444);
      statusText = 'Pengajuan Pembatalan';
    } else if (contract.contractStatus == 'cancelled') {
      statusColor = Colors.grey;
      statusText = 'Dibatalkan';
    } else if (contract.contractStatus == 'disputed') {
      statusColor = const Color(0xFF8B5CF6);
      statusText = 'Dalam Pendampingan Admin';
    } else {
      statusColor = const Color(0xFF6366F1);
      statusText = 'Draft / Menunggu Persetujuan';
    }

    return Container(
      width: 340,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kontrak #${contract.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contract.description ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nilai Kontrak',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            'Rp ${_formatAmount(contract.amount)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tenggat Waktu',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            contract.deadline?.toIso8601String() ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (contract.isPastDeadline &&
                    contract.contractStatus != 'completed' &&
                    contract.contractStatus != 'cancelled') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            contract.isPastOneWeekDeadline
                                ? 'Tenggat waktu lewat 7 hari! Admin siap mendampingi di grup 3 arah.'
                                : '⚠️ Tenggat waktu telah terlampaui.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Interactive Action Buttons
                _buildActionButtons(context, isCreator, isClient),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isCreator,
    bool isClient,
  ) {
    if (contract.contractStatus == 'draft') {
      final hasMyApproval =
          (isCreator && contract.creatorApproved) ||
          (isClient && contract.clientApproved);

      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: hasMyApproval
                  ? null
                  : () async {
                      final updated =
                          await ContractEscrowService.approveContract(
                            contract: contract,
                            userId: currentUserId,
                          );
                      onContractUpdated(updated);
                    },
              icon: Icon(
                hasMyApproval ? Icons.check_circle : Icons.check,
                size: 16,
              ),
              label: Text(
                hasMyApproval ? 'Sudah Anda Setujui' : 'Setujui Kontrak',
                style: const TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (contract.contractStatus == 'active' &&
        contract.workStatus == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isClient)
            ElevatedButton.icon(
              onPressed: () => _promptPayEscrow(context),
              icon: const Icon(Icons.shield_outlined, size: 16),
              label: Text(
                'Bayar Escrow (Rp ${_formatAmount(contract.amount)})',
                style: const TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
            )
          else
            const Text(
              'Menunggu pembayaran Escrow dari Klien...',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
        ],
      );
    }

    if (contract.contractStatus == 'active' &&
            contract.workStatus == 'in_progress' ||
        contract.contractStatus == 'active' &&
            contract.workStatus == 'submitted') {
      return Column(
        children: [
          if (isCreator &&
              contract.contractStatus == 'active' &&
              contract.workStatus == 'in_progress')
            ElevatedButton.icon(
              onPressed: () {
                final updated = ContractEscrowService.submitWork(contract);
                onContractUpdated(updated);
              },
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text(
                'Kirim Hasil Pekerjaan',
                style: TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          if (isClient &&
              (contract.contractStatus == 'active' &&
                      contract.workStatus == 'submitted' ||
                  contract.contractStatus == 'active' &&
                      contract.workStatus == 'in_progress'))
            ElevatedButton.icon(
              onPressed: () {
                final updated = ContractEscrowService.releaseEscrowToCreator(
                  contract,
                );
                onContractUpdated(updated);
              },
              icon: const Icon(Icons.verified, size: 16),
              label: const Text(
                'Setujui Pekerjaan & Cairkan Dana',
                style: TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _promptCancellation(context),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 14,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Ajukan Pembatalan',
                    style: TextStyle(fontSize: 10, color: Colors.red),
                  ),
                ),
              ),
              if (contract.isPastOneWeekDeadline || contract.disputeOpened) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOpenDisputeGroup,
                    icon: const Icon(Icons.group, size: 14),
                    label: const Text(
                      'Grup + Admin',
                      style: TextStyle(fontSize: 10),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    if (contract.contractStatus == 'proposed') {
      return Column(
        children: [
          Text(
            'Alasan: ${contract.cancelReason ?? "-"}',
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final updated = ContractEscrowService.approveCancellation(
                      contract,
                    );
                    onContractUpdated(updated);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Setujui Pembatalan & Refund',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (contract.contractStatus == 'disputed') {
      return ElevatedButton.icon(
        onPressed: onOpenDisputeGroup,
        icon: const Icon(Icons.groups, size: 16),
        label: const Text(
          'Buka Grup Pendampingan Admin (3 Arah)',
          style: TextStyle(fontSize: 11),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 36),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _promptPayEscrow(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pembayaran Escrow'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfer Rp ${_formatAmount(contract.amount)} ke saldo Escrow terikat. Dana tidak akan dicairkan sampai Anda menyetujui hasil pekerjaan.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Masukkan PIN Transaksi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final updated = await ContractEscrowService.payEscrow(
                  contract: contract,
                  pin: pinController.text.trim(),
                  partnerUsername: contract.creatorName,
                );
                onContractUpdated(updated);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
  }

  void _promptCancellation(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajukan Pembatalan Kontrak'),
        content: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alasan Pembatalan',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final updated = ContractEscrowService.requestCancellation(
                contract,
                reasonController.text.trim(),
              );
              onContractUpdated(updated);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim Pengajuan'),
          ),
        ],
      ),
    );
  }
}
