class FormValidators {
  static final _nikRegex = RegExp(r'^\d{16}$');
  static final _nameRegex = RegExp(r"^[A-Za-z\s\.',-]+$");
  static final _urlRegex = RegExp(
    r'^https?:\/\/[^\s/$.?#].[^\s]*$',
    caseSensitive: false,
  );

  static String? nik(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIK wajib diisi';
    }
    if (!_nikRegex.hasMatch(value.trim())) {
      return 'NIK harus 16 digit angka';
    }
    return null;
  }

  static String? ktpName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama wajib diisi';
    }
    if (value.trim().length < 3) {
      return 'Nama minimal 3 karakter';
    }
    if (!_nameRegex.hasMatch(value.trim())) {
      return 'Nama hanya huruf, spasi, titik, koma, atau strip';
    }
    return null;
  }

  static String? birthPlace(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tempat lahir wajib diisi';
    }
    if (value.trim().length < 2) {
      return 'Tempat lahir minimal 2 karakter';
    }
    if (!_nameRegex.hasMatch(value.trim())) {
      return 'Tempat lahir hanya huruf dan spasi';
    }
    return null;
  }

  static String? birthDay(String? value) {
    if (value == null || value.trim().isEmpty) return 'Hari wajib diisi';
    if (!RegExp(r'^\d{1,2}$').hasMatch(value)) return 'Hari hanya angka';
    final day = int.tryParse(value);
    if (day == null || day < 1 || day > 31) return 'Hari tidak valid (1–31)';
    return null;
  }

  static String? birthMonth(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bulan wajib diisi';
    if (!RegExp(r'^\d{1,2}$').hasMatch(value)) return 'Bulan hanya angka';
    final month = int.tryParse(value);
    if (month == null || month < 1 || month > 12) return 'Bulan tidak valid (1–12)';
    return null;
  }

  static String? birthYear(String? value) {
    if (value == null || value.trim().isEmpty) return 'Tahun wajib diisi';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) return 'Tahun harus 4 digit angka';
    final year = int.tryParse(value);
    if (year == null || year < 1940 || year > DateTime.now().year) {
      return 'Tahun tidak valid';
    }
    return null;
  }

  static String? birthDateCombined(String day, String month, String year) {
    final d = int.tryParse(day);
    final m = int.tryParse(month);
    final y = int.tryParse(year);
    if (d == null || m == null || y == null) return 'Tanggal lahir tidak valid';
    try {
      final date = DateTime(y, m, d);
      if (date.year != y || date.month != m || date.day != d) {
        return 'Tanggal lahir tidak valid';
      }
      if (date.isAfter(DateTime.now())) {
        return 'Tanggal lahir tidak boleh di masa depan';
      }
    } catch (_) {
      return 'Tanggal lahir tidak valid';
    }
    return null;
  }

  static String toIsoDate(String day, String month, String year) {
    return '${year.padLeft(4, '0')}-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
  }

  static String? address(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Alamat wajib diisi';
    }
    if (value.trim().length < 10) {
      return 'Alamat minimal 10 karakter';
    }
    return null;
  }

  static String? skills(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Keahlian wajib diisi';
    }
    if (value.trim().length < 20) {
      return 'Deskripsi keahlian minimal 20 karakter';
    }
    return null;
  }

  static String? portfolioUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Link portfolio wajib diisi';
    }
    if (!_urlRegex.hasMatch(value.trim())) {
      return 'Format URL tidak valid (contoh: https://behance.net/...)';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^(\+62|62|0)8[0-9]{8,11}$').hasMatch(value.trim())) {
      return 'Nomor telepon tidak valid (contoh: 081234567890)';
    }
    return null;
  }
}
