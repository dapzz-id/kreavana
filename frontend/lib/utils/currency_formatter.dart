import 'package:flutter/services.dart';

/// Formatter input nominal mata uang Rupiah Indonesia (memisahkan ribuan dengan tanda titik).
/// Contoh: 6000 -> 6.000, 250000 -> 250.000, 10000000 -> 10.000.000
class IndonesianCurrencyInputFormatter extends TextInputFormatter {
  final int maxDigits;

  const IndonesianCurrencyInputFormatter({this.maxDigits = 12});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Ambil hanya karakter angka
    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Batasi jumlah digit maksimal (default 12 digit = 999 Miliar)
    if (cleanDigits.length > maxDigits) {
      return oldValue;
    }

    // Format angka dengan pemisah ribuan titik
    final parsedInt = int.tryParse(cleanDigits) ?? 0;
    final formatted = formatIndonesianNumber(parsedInt);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Helper untuk memformat angka bilangan bulat ke format titik ribuan Indonesia
String formatIndonesianNumber(num amount) {
  final intVal = amount.toInt();
  final str = intVal.abs().toString();
  final formatted = str.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
  return intVal < 0 ? '-$formatted' : formatted;
}

/// Helper untuk memformat angka dengan prefix Rp (misal: Rp 6.000)
String formatRupiah(num amount, {bool withPrefix = true}) {
  final numStr = formatIndonesianNumber(amount);
  return withPrefix ? 'Rp $numStr' : numStr;
}

/// Helper untuk membersihkan string currency dan mengembalikan angka murni (double)
double parseRupiahToDouble(String? text) {
  if (text == null || text.trim().isEmpty) return 0.0;
  final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(clean) ?? 0.0;
}
