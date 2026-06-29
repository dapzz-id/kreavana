class WalletTransactionModel {
  final int id;
  final int userId;
  final String type; // 'topup', 'transfer_send', 'transfer_receive'
  final double amount;
  final double fee;
  final String paymentMethod;
  final String? paymentProvider;
  final String status; // 'pending', 'completed', 'failed'
  final String referenceNumber;
  final String? description;
  final String createdAt;

  WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.fee,
    required this.paymentMethod,
    this.paymentProvider,
    required this.status,
    required this.referenceNumber,
    this.description,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      type: json['type'] ?? '',
      amount: json['amount'] != null ? double.parse(json['amount'].toString()) : 0.0,
      fee: json['fee'] != null ? double.parse(json['fee'].toString()) : 0.0,
      paymentMethod: json['payment_method'] ?? '',
      paymentProvider: json['payment_provider'],
      status: json['status'] ?? 'pending',
      referenceNumber: json['reference_number'] ?? '',
      description: json['description'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'fee': fee,
      'payment_method': paymentMethod,
      'payment_provider': paymentProvider,
      'status': status,
      'reference_number': referenceNumber,
      'description': description,
      'created_at': createdAt,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'topup':
        return 'Isi Saldo';
      case 'transfer_send':
        return 'Kirim Saldo';
      case 'transfer_receive':
        return 'Terima Saldo';
      case 'withdrawal':
        return 'Tarik Saldo';
      default:
        return 'Transaksi';
    }
  }

  bool get isCredit => type == 'topup' || type == 'transfer_receive';
}
