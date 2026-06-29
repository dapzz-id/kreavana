import 'api_service.dart';
import '../models/wallet_transaction_model.dart';

class WalletService {
  /// Mendapatkan saldo saat ini dan daftar transaksi
  static Future<Map<String, dynamic>> getWalletInfo() async {
    try {
      final response = await ApiService.get('wallet/info');

      if (response['success'] == true) {
        final data = response['data'];
        final balance = double.parse(data['balance'].toString());
        final transactionsList = data['transactions'] as List;
        final transactions = transactionsList
            .map((tx) => WalletTransactionModel.fromJson(tx))
            .toList();

        return {
          'success': true,
          'balance': balance,
          'transactions': transactions,
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Gagal mengambil informasi dompet.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  /// Membuat invoice pengisian saldo (Top Up) pending
  static Future<Map<String, dynamic>> topUp({
    required double amount,
    required String paymentMethod,
    required String paymentProvider,
  }) async {
    try {
      final body = {
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_provider': paymentProvider,
      };

      final response = await ApiService.post('wallet/topup', body);

      if (response['success'] == true) {
        final data = response['data'];
        final transaction = WalletTransactionModel.fromJson(data['transaction']);
        final paymentDetails = data['payment_details'] as Map<String, dynamic>;

        return {
          'success': true,
          'transaction': transaction,
          'payment_details': paymentDetails,
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Gagal membuat transaksi top up.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  /// Menyimulasikan pembayaran top-up sukses
  static Future<Map<String, dynamic>> simulatePayment(String referenceNumber) async {
    try {
      final body = {
        'reference_number': referenceNumber,
      };

      final response = await ApiService.post('wallet/topup/simulate', body);

      if (response['success'] == true) {
        final data = response['data'];
        final balance = double.parse(data['balance'].toString());
        final transaction = WalletTransactionModel.fromJson(data['transaction']);

        return {
          'success': true,
          'balance': balance,
          'transaction': transaction,
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Gagal memproses simulasi pembayaran.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  /// Mentransfer saldo ke pengguna lain (dikenakan pajak 5%)
  static Future<Map<String, dynamic>> transfer({
    required String receiverUsername,
    required double amount,
    String? description,
  }) async {
    try {
      final body = {
        'receiver_username': receiverUsername,
        'amount': amount,
        if (description != null) 'description': description,
      };

      final response = await ApiService.post('wallet/transfer', body);

      if (response['success'] == true) {
        final data = response['data'];
        final senderBalance = double.parse(data['sender_balance'].toString());
        final fee = double.parse(data['fee'].toString());
        final netAmount = double.parse(data['net_amount'].toString());
        final transaction = WalletTransactionModel.fromJson(data['transaction']);

        return {
          'success': true,
          'sender_balance': senderBalance,
          'fee': fee,
          'net_amount': netAmount,
          'transaction': transaction,
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Gagal memproses transfer.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }

  /// Menarik/Mencairkan saldo ke bank atau e-wallet (dikenakan pajak 5%)
  static Future<Map<String, dynamic>> withdraw({
    required double amount,
    required String paymentMethod,
    required String paymentProvider,
    required String accountNumber,
  }) async {
    try {
      final body = {
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_provider': paymentProvider,
        'account_number': accountNumber,
      };

      final response = await ApiService.post('wallet/withdraw', body);

      if (response['success'] == true) {
        final data = response['data'];
        final balance = double.parse(data['balance'].toString());
        final tax = double.parse(data['tax'].toString());
        final netAmount = double.parse(data['net_amount'].toString());
        final transaction = WalletTransactionModel.fromJson(data['transaction']);

        return {
          'success': true,
          'balance': balance,
          'tax': tax,
          'net_amount': netAmount,
          'transaction': transaction,
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Gagal memproses penarikan saldo.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi gagal: $e',
      };
    }
  }
}
