class KtpOcrResult {
  final String? nik;
  final String? fullName;
  final String? birthPlace;
  final String? birthDate;
  final String? address;
  final String rawText;

  KtpOcrResult({
    this.nik,
    this.fullName,
    this.birthPlace,
    this.birthDate,
    this.address,
    this.rawText = '',
  });

  bool get hasData => nik != null || fullName != null || address != null;
}

class KtpOcrService {
  static Future<KtpOcrResult> scanFromFile(String filePath) async {
    return KtpOcrResult(rawText: '');
  }

  static KtpOcrResult parseKtpText(String text) {
    return KtpOcrResult(rawText: text);
  }
}
