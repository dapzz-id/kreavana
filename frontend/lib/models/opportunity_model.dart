class OpportunityPoster {
  final String? id;
  final String name;
  final String username;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? selectedSubRole;
  final String role;
  final bool isVerified;
  final String? verificationType;

  OpportunityPoster({
    required this.id,
    required this.name,
    required this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    this.selectedSubRole,
    this.role = 'user',
    this.isVerified = false,
    this.verificationType,
  });

  factory OpportunityPoster.fromJson(Map<String, dynamic> json) {
    return OpportunityPoster(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      phone: json['phone'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      selectedSubRole: json['selected_sub_role'],
      role: json['role'] ?? 'user',
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      verificationType: json['verification_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'selected_sub_role': selectedSubRole,
      'role': role,
      'is_verified': isVerified,
      'verification_type': verificationType,
    };
  }
}

class OpportunityRequirementModel {
  final String? id;
  final String subRoleSlug;
  final int quantity;
  final String? notes;
  final String paymentScheme;
  final List<Map<String, dynamic>> paymentTerms;

  OpportunityRequirementModel({
    this.id,
    required this.subRoleSlug,
    this.quantity = 1,
    this.notes,
    this.paymentScheme = 'full_at_end',
    this.paymentTerms = const [],
  });

  factory OpportunityRequirementModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> terms = [];
    if (json['payment_terms'] is List) {
      for (final t in json['payment_terms']) {
        if (t is Map) {
          terms.add(Map<String, dynamic>.from(t));
        }
      }
    }
    return OpportunityRequirementModel(
      id: json['id']?.toString(),
      subRoleSlug: json['sub_role_slug'] ?? '',
      quantity: (json['quantity_needed'] ?? json['quantity']) != null
          ? int.tryParse((json['quantity_needed'] ?? json['quantity']).toString()) ?? 1
          : 1,
      notes: json['notes'],
      paymentScheme: json['payment_scheme']?.toString() ?? 'full_at_end',
      paymentTerms: terms,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_role_slug': subRoleSlug,
      'quantity': quantity,
      'notes': notes,
      'payment_scheme': paymentScheme,
      'payment_terms': paymentTerms,
    };
  }

  List<String> get tags {
    if (notes == null || notes!.trim().isEmpty) return [];
    return notes!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String get subRoleTitle {
    switch (subRoleSlug.toLowerCase().replaceAll('-', '_')) {
      case 'fotografi':
      case 'photographer':
      case 'fotografer':
        return 'Fotografer';
      case 'videografi':
      case 'videographer':
      case 'videografer':
        return 'Videografer';
      case 'desain_grafis':
      case 'desainer':
        return 'Desainer Grafis';
      case 'editor':
        return 'Editor Video';
      case 'animator':
        return 'Animator';
      case 'konten_kreator':
      case 'content_creator':
        return 'Content Creator';
      case 'drone':
        return 'Pilot Drone';
      case 'mc':
        return 'MC / Host';
      case 'singer':
        return 'Penyanyi / Musisi';
      case 'event_organizer':
        return 'Event Organizer';
      case 'wedding_organizer':
        return 'Wedding Organizer';
      case 'makeup_artist':
        return 'Makeup Artist';
      case 'model':
        return 'Model / Talent';
      case 'copywriter':
        return 'Copywriter';
      case 'community':
        return 'Komunitas Kreatif';
      case 'institution':
        return 'Lembaga / Yayasan';
      case 'government':
        return 'Instansi Pemerintah';
      case 'tukang_kendang':
        return 'Tukang Kendang';
      default:
        return subRoleSlug.replaceAll('_', ' ').replaceAll('-', ' ');
    }
  }

  String get label {
    final title = subRoleTitle;
    final unit = (subRoleSlug.contains('organizer') || subRoleSlug.contains('community')) ? 'tim' : 'orang';
    return '$title ($quantity $unit)';
  }
}

class OpportunityApprovedCreatorModel {
  final String id;
  final String? applicationId;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? subRole;
  final String? capability;
  final double agreedPrice;
  final String? contractNumber;
  final String? clientSignature;
  final String? clientSignedAt;
  final String? creatorSignature;
  final String? creatorSignedAt;
  final List<String> dynamicTerms;
  final String? studentName;
  final String? studentMajor;
  final String? pitchMessage;
  final List<Map<String, dynamic>> submittedDocuments;

  OpportunityApprovedCreatorModel({
    required this.id,
    this.applicationId,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.subRole,
    this.capability,
    this.agreedPrice = 0.0,
    this.contractNumber,
    this.clientSignature,
    this.clientSignedAt,
    this.creatorSignature,
    this.creatorSignedAt,
    this.dynamicTerms = const [],
    this.studentName,
    this.studentMajor,
    this.pitchMessage,
    this.submittedDocuments = const [],
  });

  bool get isClientSigned =>
      (clientSignedAt != null && clientSignedAt!.isNotEmpty) ||
      (clientSignature != null && clientSignature!.isNotEmpty);
  bool get isSigned =>
      (creatorSignedAt != null && creatorSignedAt!.isNotEmpty) ||
      (creatorSignature != null && creatorSignature!.isNotEmpty);
  bool get isContractFinal => isClientSigned && isSigned;

  String get studentDisplayName {
    if (studentName != null && studentName!.trim().isNotEmpty) {
      return studentName!.trim();
    }
    if (submittedDocuments.isNotEmpty) {
      final doc0 = submittedDocuments.first;
      final dName = (doc0['student_name'] ?? doc0['name'] ?? '').toString().trim();
      if (dName.isNotEmpty) return dName;
    }
    if (pitchMessage != null &&
        (pitchMessage!.startsWith('Peserta:') || pitchMessage!.startsWith('Siswa:'))) {
      final prefix = pitchMessage!.startsWith('Peserta:') ? 'Peserta:' : 'Siswa:';
      final parts = pitchMessage!.split('|').map((p) => p.trim()).toList();
      final head = parts.first.replaceFirst(prefix, '').trim();
      final pStart = head.lastIndexOf('(');
      final pEnd = head.lastIndexOf(')');
      if (pStart > 0 && pEnd > pStart) {
        return head.substring(0, pStart).trim();
      }
      return head;
    }
    return name;
  }

  String get studentMajorDisplay {
    if (studentMajor != null && studentMajor!.trim().isNotEmpty) {
      return studentMajor!.trim();
    }
    if (submittedDocuments.isNotEmpty) {
      final doc0 = submittedDocuments.first;
      final dMajor = (doc0['major'] ?? doc0['jurusan'] ?? '').toString().trim();
      if (dMajor.isNotEmpty) return dMajor;
    }
    if (pitchMessage != null &&
        (pitchMessage!.startsWith('Peserta:') || pitchMessage!.startsWith('Siswa:'))) {
      final prefix = pitchMessage!.startsWith('Peserta:') ? 'Peserta:' : 'Siswa:';
      final parts = pitchMessage!.split('|').map((p) => p.trim()).toList();
      final head = parts.first.replaceFirst(prefix, '').trim();
      final pStart = head.lastIndexOf('(');
      final pEnd = head.lastIndexOf(')');
      if (pStart > 0 && pEnd > pStart) {
        return head.substring(pStart + 1, pEnd).trim();
      }
    }
    return capability?.replaceAll('_', ' ').toUpperCase() ?? 'Peserta Magang';
  }

  factory OpportunityApprovedCreatorModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parsedDocs = const [];
    if (json['submitted_documents'] is List) {
      parsedDocs = (json['submitted_documents'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return OpportunityApprovedCreatorModel(
      id: json['id']?.toString() ?? '',
      applicationId: json['application_id']?.toString(),
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      subRole: json['sub_role'],
      capability: json['capability'],
      agreedPrice: json['agreed_price'] != null
          ? (double.tryParse(json['agreed_price'].toString()) ?? 0.0)
          : 0.0,
      contractNumber: json['contract_number']?.toString(),
      clientSignature: json['client_signature']?.toString(),
      clientSignedAt: json['client_signed_at']?.toString(),
      creatorSignature: json['creator_signature'],
      creatorSignedAt: json['creator_signed_at'],
      dynamicTerms: json['dynamic_terms'] is List
          ? (json['dynamic_terms'] as List).map((e) => e.toString()).toList()
          : const [],
      studentName: json['student_name']?.toString(),
      studentMajor: json['student_major']?.toString(),
      pitchMessage: json['pitch_message']?.toString(),
      submittedDocuments: parsedDocs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'application_id': applicationId,
      'name': name,
      'username': username,
      'avatar_url': avatarUrl,
      'sub_role': subRole,
      'capability': capability,
      'agreed_price': agreedPrice,
      'contract_number': contractNumber,
      'client_signature': clientSignature,
      'client_signed_at': clientSignedAt,
      'creator_signature': creatorSignature,
      'creator_signed_at': creatorSignedAt,
      'dynamic_terms': dynamicTerms,
      'student_name': studentName,
      'student_major': studentMajor,
      'pitch_message': pitchMessage,
      'submitted_documents': submittedDocuments,
    };
  }
}

class OpportunityModel {
  final String? id;
  final String title;
  final String? description;
  final String? posterUrl;
  final String? bannerUrl;
  final String subRoleSlug;
  final String type; // 'location' | 'project'
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? locationCategory;
  final String? address;
  final String? deadline;
  final String? eventDate;
  final String? eventStartDate;
  final String? eventEndDate;
  final String? eventStartTime;
  final String? eventEndTime;
  final String? budgetRange;
  final String status;
  final String? meetingDate;
  final String? meetingTime;
  final String? meetingLocation;
  final double? meetingLat;
  final double? meetingLng;
  final String? meetingNotes;
  final String meetingStatus; // 'not_required', 'pending_marketing_review', 'verified_paid'
  final String? meetingCounterBy;
  final String? meetingCounterDate;
  final String? meetingCounterTime;
  final String? meetingCounterLocation;
  final double? meetingCounterLat;
  final double? meetingCounterLng;
  final String? meetingCounterNotes;
  final String? meetingCounterStatus;
  final String escrowStatus; // 'none', 'pending_deposit', 'held_in_escrow', 'released_to_creators'
  final int eventProgress;
  final String? postedBy;
  final String? createdAt;
  final OpportunityPoster? poster;
  final List<OpportunityRequirementModel> requirements;
  final List<OpportunityApprovedCreatorModel> approvedCreators;
  final int applicationsCount;
  final double? externalRating;
  final String? externalRatingSource;
  final String? externalProofUrl;
  final String? signatureType; // 'wet_signature' | 'dynamic_electronic'
  final String? clientSignature;
  final String? clientSignedAt;
  final String? wetSignatureDocumentUrl;
  final String? wetSignatureVerifiedAt;
  final String? officialAcceptanceLetterUrl;
  final String? officialAcceptanceLetterName;
  final String? officialAcceptanceLetterUploadedAt;
  final double? escrowAmount;
  final List<String> dynamicTerms;
  final String? adminName;
  final String? adminSignatureUrl;
  final String? adminSignedAt;
  final String? adminStartedAt;
  final String? autoReleaseTriggeredAt;
  final String? gracePeriodDeadline;
  final bool isGracePeriodActive;
  final int gracePeriodDaysLeft;
  final bool isWetSignatureRequired;
  final bool isDynamicSignatureRequired;
  final bool hasApplied;

  OpportunityModel({
    required this.id,
    required this.title,
    this.description,
    this.posterUrl,
    this.bannerUrl,
    required this.subRoleSlug,
    this.type = 'project',
    this.location,
    this.latitude,
    this.longitude,
    this.locationCategory,
    this.address,
    this.deadline,
    this.eventDate,
    this.eventStartDate,
    this.eventEndDate,
    this.eventStartTime,
    this.eventEndTime,
    this.budgetRange,
    this.status = 'open',
    this.meetingDate,
    this.meetingTime,
    this.meetingLocation,
    this.meetingLat,
    this.meetingLng,
    this.meetingNotes,
    this.meetingStatus = 'not_required',
    this.meetingCounterBy,
    this.meetingCounterDate,
    this.meetingCounterTime,
    this.meetingCounterLocation,
    this.meetingCounterLat,
    this.meetingCounterLng,
    this.meetingCounterNotes,
    this.meetingCounterStatus,
    this.escrowStatus = 'none',
    this.eventProgress = 0,
    this.postedBy,
    this.createdAt,
    this.poster,
    this.requirements = const [],
    this.approvedCreators = const [],
    this.applicationsCount = 0,
    this.externalRating,
    this.externalRatingSource,
    this.externalProofUrl,
    this.signatureType,
    this.clientSignature,
    this.clientSignedAt,
    this.wetSignatureDocumentUrl,
    this.wetSignatureVerifiedAt,
    this.officialAcceptanceLetterUrl,
    this.officialAcceptanceLetterName,
    this.officialAcceptanceLetterUploadedAt,
    this.escrowAmount,
    this.dynamicTerms = const [],
    this.adminName,
    this.adminSignatureUrl,
    this.adminSignedAt,
    this.adminStartedAt,
    this.autoReleaseTriggeredAt,
    this.gracePeriodDeadline,
    this.isGracePeriodActive = false,
    this.gracePeriodDaysLeft = 0,
    this.isWetSignatureRequired = false,
    this.isDynamicSignatureRequired = true,
    this.hasApplied = false,
  });

  bool get isLocation => type == 'location';
  bool get isProject => type == 'project';
  bool get isOngoing => status.toLowerCase() == 'in_progress' || status.toLowerCase() == 'ongoing';
  bool get isClosed =>
      status.toLowerCase() == 'closed' ||
      status.toLowerCase() == 'completed' ||
      (totalQuota > 0 && remainingQuota <= 0);
  bool get hasExternalRating => externalRating != null && externalRating! > 0;
  bool get hasOfficialAcceptanceLetter =>
      officialAcceptanceLetterUrl != null && officialAcceptanceLetterUrl!.trim().isNotEmpty;
  bool get isMeetingPending => meetingStatus.toLowerCase() == 'pending' || meetingStatus.toLowerCase() == 'pending_marketing_review';
  bool get isMeetingInProcess => meetingStatus.toLowerCase() == 'diproses' || meetingStatus.toLowerCase() == 'approved';
  bool get isMeetingVerified => meetingStatus.toLowerCase() == 'verified_completed' || meetingStatus.toLowerCase() == 'verified_paid' || (wetSignatureVerifiedAt != null && wetSignatureVerifiedAt!.isNotEmpty);
  bool get hasMeetingCounter => meetingCounterStatus == 'pending' && meetingCounterBy != null;
  bool get isMeetingCounterByAdmin => meetingCounterBy == 'admin' && meetingCounterStatus == 'pending';
  bool get isMeetingCounterByClient => meetingCounterBy == 'client' && meetingCounterStatus == 'pending';

  bool get isEventRunning {
    if (status.toLowerCase() != 'open') return true;
    if (eventProgress > 0) return true;
    final rawDate = eventStartDate ?? eventDate;
    if (rawDate != null && rawDate.trim().isNotEmpty) {
      try {
        final parsed = DateTime.tryParse(rawDate.trim());
        if (parsed != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final eventDay = DateTime(parsed.year, parsed.month, parsed.day);
          if (eventDay.isBefore(today)) {
            return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  bool get canApply => status.toLowerCase() == 'open' && !isEventRunning && !isClosed;

  bool get isMagang {
    final locCat = (locationCategory ?? '').toLowerCase();
    if (locCat == 'magang' || locCat == 'internship') return true;
    if (locCat == 'job' || locCat == 'pekerjaan' || locCat == 'lowongan') return false;

    final sub = subRoleSlug.toLowerCase();
    final t = title.toLowerCase();
    final d = (description ?? '').toLowerCase();

    if (sub == 'magang' || sub.contains('magang') || sub.contains('intern')) return true;
    if (t.contains('magang') || t.contains('intern') || t.contains('pkl') || t.contains('mbkm')) return true;
    if (d.contains('program magang') ||
        d.contains('peserta magang') ||
        d.contains('siswa magang') ||
        d.contains('mahasiswa magang') ||
        d.contains('siswa vokasi') ||
        d.contains('tempat pkl') ||
        d.contains('penempatan magang')) {
      return true;
    }

    return requirements.any((r) {
      final rSub = r.subRoleSlug.toLowerCase();
      final notes = (r.notes ?? '').toLowerCase();
      return rSub.contains('magang') ||
          (notes.isNotEmpty &&
              (notes.contains('magang') ||
                  notes.contains('pkl') ||
                  notes.contains('mbkm') ||
                  notes.contains('siswa smk') ||
                  notes.contains('siswa vokasi')));
    });
  }

  bool get isJob => !isMagang;

  /// Calculates total quota strictly from specialization requirements,
  /// excluding non-quota qualification descriptions.
  int get totalQuota {
    int total = 0;
    for (final r in requirements) {
      final sub = r.subRoleSlug.trim().toLowerCase();
      if (sub == 'kualifikasi' || sub == 'qualification' || sub == 'syarat') {
        continue;
      }
      final notes = (r.notes ?? '').trim();
      if (notes.isNotEmpty &&
          !notes.toLowerCase().startsWith('spesialisasi') &&
          (notes.startsWith('Memiliki') ||
           notes.startsWith('Mampu') ||
           notes.startsWith('Peserta') ||
           notes.startsWith('Siswa') ||
           notes.startsWith('Mahasiswa') ||
           notes.startsWith('Disiplin') ||
           notes.startsWith('Menguasai') ||
           notes.startsWith('Siap'))) {
        continue;
      }

      int q = r.quantity;
      if (q <= 0 && notes.isNotEmpty) {
        final match = RegExp(r'\((\d+)\s+kuota\)').firstMatch(notes);
        if (match != null) {
          q = int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }

      if (q > 0) {
        total += q;
      }
    }

    if (total <= 0) {
      for (final r in requirements) {
        final notes = r.notes ?? '';
        final match = RegExp(r'\((\d+)\s+kuota\)').firstMatch(notes);
        if (match != null) {
          total += int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }
    }
    return total;
  }

  int get remainingQuota {
    final t = totalQuota;
    if (t <= 0) return 0;
    return (t - approvedCreators.length).clamp(0, t);
  }

  bool get isWetSignatureBudget {
    if (isWetSignatureRequired) return true;
    if (signatureType == 'wet_signature') return true;
    final b = (budgetRange ?? '').toLowerCase();
    if (b.contains('5.000.000 - 20.000.000')) return false;
    if (b.contains('20.000.000 - 100.000.000')) return false;
    return b.contains('100.000.000') ||
        b.contains('tanda tangan basah') ||
        (b.startsWith('>=') && !b.contains('2.500.000') && !b.contains('20.000.000'));
  }

  bool get isDynamicSignatureBudget => !isWetSignatureBudget;

  bool get isClientSigned =>
      (clientSignature != null && clientSignature!.isNotEmpty) ||
      (clientSignedAt != null && clientSignedAt!.isNotEmpty);

  bool get areAllApprovedCreatorsSigned =>
      approvedCreators.isNotEmpty && approvedCreators.every((c) => c.isSigned);

  bool get isContractFullyApproved {
    if (isWetSignatureBudget) {
      return (wetSignatureDocumentUrl != null && wetSignatureDocumentUrl!.isNotEmpty) ||
          (wetSignatureVerifiedAt != null && wetSignatureVerifiedAt!.isNotEmpty) ||
          meetingStatus == 'verified_paid' ||
          meetingStatus == 'verified_completed';
    } else {
      return isClientSigned && areAllApprovedCreatorsSigned;
    }
  }

  bool get isContractSigned => isContractFullyApproved;

  bool get isLargeTransaction => isWetSignatureBudget;

  String get effectiveBannerUrl => (bannerUrl != null && bannerUrl!.isNotEmpty)
      ? bannerUrl!
      : (posterUrl ?? '');

  String get durationDisplay {
    if (eventStartDate != null && eventStartDate!.isNotEmpty && eventEndDate != null && eventEndDate!.isNotEmpty) {
      return '$eventStartDate s/d $eventEndDate';
    }
    if (eventDate != null && eventDate!.isNotEmpty) {
      return eventDate!;
    }
    return deadline ?? 'Jadwal fleksibel';
  }

  List<String> get allTags {
    final list = <String>{};
    for (final r in requirements) {
      list.addAll(r.tags);
    }
    return list.toList();
  }

  List<String> get allSubRoleSlugs {
    final slugs = <String>{};
    if (subRoleSlug.isNotEmpty) slugs.add(subRoleSlug.toLowerCase());
    for (final r in requirements) {
      if (r.subRoleSlug.isNotEmpty) slugs.add(r.subRoleSlug.toLowerCase());
    }
    return slugs.toList();
  }

  OpportunityModel copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    String? locationCategory,
    String? subRoleSlug,
    String? location,
    String? address,
    double? latitude,
    double? longitude,
    String? posterUrl,
    String? bannerUrl,
    String? deadline,
    String? eventDate,
    String? eventStartDate,
    String? eventEndDate,
    String? eventStartTime,
    String? eventEndTime,
    String? budgetRange,
    String? status,
    String? meetingDate,
    String? meetingTime,
    String? meetingLocation,
    double? meetingLat,
    double? meetingLng,
    String? meetingNotes,
    String? meetingStatus,
    String? meetingCounterBy,
    String? meetingCounterDate,
    String? meetingCounterTime,
    String? meetingCounterLocation,
    double? meetingCounterLat,
    double? meetingCounterLng,
    String? meetingCounterNotes,
    String? meetingCounterStatus,
    String? escrowStatus,
    int? eventProgress,
    String? postedBy,
    String? createdAt,
    OpportunityPoster? poster,
    List<OpportunityRequirementModel>? requirements,
    List<OpportunityApprovedCreatorModel>? approvedCreators,
    int? applicationsCount,
    double? externalRating,
    String? externalRatingSource,
    String? externalProofUrl,
    String? signatureType,
    String? clientSignature,
    String? clientSignedAt,
    String? wetSignatureDocumentUrl,
    String? wetSignatureVerifiedAt,
    String? officialAcceptanceLetterUrl,
    String? officialAcceptanceLetterName,
    String? officialAcceptanceLetterUploadedAt,
    double? escrowAmount,
    List<String>? dynamicTerms,
    String? adminName,
    String? adminSignatureUrl,
    String? adminSignedAt,
    String? adminStartedAt,
    String? autoReleaseTriggeredAt,
    String? gracePeriodDeadline,
    bool? isGracePeriodActive,
    int? gracePeriodDaysLeft,
    bool? isWetSignatureRequired,
    bool? isDynamicSignatureRequired,
    bool? hasApplied,
  }) {
    return OpportunityModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      locationCategory: locationCategory ?? this.locationCategory,
      subRoleSlug: subRoleSlug ?? this.subRoleSlug,
      location: location ?? this.location,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      posterUrl: posterUrl ?? this.posterUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      deadline: deadline ?? this.deadline,
      eventDate: eventDate ?? this.eventDate,
      eventStartDate: eventStartDate ?? this.eventStartDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      eventStartTime: eventStartTime ?? this.eventStartTime,
      eventEndTime: eventEndTime ?? this.eventEndTime,
      budgetRange: budgetRange ?? this.budgetRange,
      status: status ?? this.status,
      meetingDate: meetingDate ?? this.meetingDate,
      meetingTime: meetingTime ?? this.meetingTime,
      meetingLocation: meetingLocation ?? this.meetingLocation,
      meetingLat: meetingLat ?? this.meetingLat,
      meetingLng: meetingLng ?? this.meetingLng,
      meetingNotes: meetingNotes ?? this.meetingNotes,
      meetingStatus: meetingStatus ?? this.meetingStatus,
      meetingCounterBy: meetingCounterBy ?? this.meetingCounterBy,
      meetingCounterDate: meetingCounterDate ?? this.meetingCounterDate,
      meetingCounterTime: meetingCounterTime ?? this.meetingCounterTime,
      meetingCounterLocation: meetingCounterLocation ?? this.meetingCounterLocation,
      meetingCounterLat: meetingCounterLat ?? this.meetingCounterLat,
      meetingCounterLng: meetingCounterLng ?? this.meetingCounterLng,
      meetingCounterNotes: meetingCounterNotes ?? this.meetingCounterNotes,
      meetingCounterStatus: meetingCounterStatus ?? this.meetingCounterStatus,
      escrowStatus: escrowStatus ?? this.escrowStatus,
      eventProgress: eventProgress ?? this.eventProgress,
      postedBy: postedBy ?? this.postedBy,
      createdAt: createdAt ?? this.createdAt,
      poster: poster ?? this.poster,
      requirements: requirements ?? this.requirements,
      approvedCreators: approvedCreators ?? this.approvedCreators,
      applicationsCount: applicationsCount ?? this.applicationsCount,
      externalRating: externalRating ?? this.externalRating,
      externalRatingSource: externalRatingSource ?? this.externalRatingSource,
      externalProofUrl: externalProofUrl ?? this.externalProofUrl,
      signatureType: signatureType ?? this.signatureType,
      clientSignature: clientSignature ?? this.clientSignature,
      clientSignedAt: clientSignedAt ?? this.clientSignedAt,
      wetSignatureDocumentUrl: wetSignatureDocumentUrl ?? this.wetSignatureDocumentUrl,
      wetSignatureVerifiedAt: wetSignatureVerifiedAt ?? this.wetSignatureVerifiedAt,
      officialAcceptanceLetterUrl: officialAcceptanceLetterUrl ?? this.officialAcceptanceLetterUrl,
      officialAcceptanceLetterName: officialAcceptanceLetterName ?? this.officialAcceptanceLetterName,
      officialAcceptanceLetterUploadedAt: officialAcceptanceLetterUploadedAt ?? this.officialAcceptanceLetterUploadedAt,
      escrowAmount: escrowAmount ?? this.escrowAmount,
      dynamicTerms: dynamicTerms ?? this.dynamicTerms,
      adminName: adminName ?? this.adminName,
      adminSignatureUrl: adminSignatureUrl ?? this.adminSignatureUrl,
      adminSignedAt: adminSignedAt ?? this.adminSignedAt,
      adminStartedAt: adminStartedAt ?? this.adminStartedAt,
      autoReleaseTriggeredAt: autoReleaseTriggeredAt ?? this.autoReleaseTriggeredAt,
      gracePeriodDeadline: gracePeriodDeadline ?? this.gracePeriodDeadline,
      isGracePeriodActive: isGracePeriodActive ?? this.isGracePeriodActive,
      gracePeriodDaysLeft: gracePeriodDaysLeft ?? this.gracePeriodDaysLeft,
      isWetSignatureRequired: isWetSignatureRequired ?? this.isWetSignatureRequired,
      isDynamicSignatureRequired: isDynamicSignatureRequired ?? this.isDynamicSignatureRequired,
      hasApplied: hasApplied ?? this.hasApplied,
    );
  }

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    var reqsList = <OpportunityRequirementModel>[];
    if (json['requirements'] is List) {
      reqsList = (json['requirements'] as List)
          .map((r) => OpportunityRequirementModel.fromJson(r))
          .toList();
    }

    var approvedList = <OpportunityApprovedCreatorModel>[];
    if (json['approved_creators'] is List) {
      approvedList = (json['approved_creators'] as List)
          .map((c) => OpportunityApprovedCreatorModel.fromJson(c))
          .toList();
    }

    return OpportunityModel(
      id: json['id']?.toString(),
      title: json['title'] ?? '',
      description: json['description'],
      posterUrl: json['poster_url'],
      bannerUrl: json['banner_url'],
      subRoleSlug: json['sub_role_slug'] ?? '',
      type: json['type'] ?? 'project',
      location: json['location'],
      latitude: json['latitude'] != null
          ? (json['latitude'] is double
              ? json['latitude']
              : double.tryParse(json['latitude'].toString()))
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] is double
              ? json['longitude']
              : double.tryParse(json['longitude'].toString()))
          : null,
      locationCategory: json['location_category'],
      address: json['address'],
      deadline: json['deadline']?.toString(),
      eventDate: json['event_date']?.toString(),
      eventStartDate: json['event_start_date']?.toString(),
      eventEndDate: json['event_end_date']?.toString(),
      eventStartTime: json['event_start_time']?.toString(),
      eventEndTime: json['event_end_time']?.toString(),
      budgetRange: json['budget_range'],
      status: json['status'] ?? 'open',
      meetingDate: json['meeting_date']?.toString(),
      meetingTime: json['meeting_time']?.toString(),
      meetingLocation: json['meeting_location']?.toString(),
      meetingLat: json['meeting_lat'] != null
          ? (json['meeting_lat'] is double
              ? json['meeting_lat']
              : double.tryParse(json['meeting_lat'].toString()))
          : null,
      meetingLng: json['meeting_lng'] != null
          ? (json['meeting_lng'] is double
              ? json['meeting_lng']
              : double.tryParse(json['meeting_lng'].toString()))
          : null,
      meetingNotes: json['meeting_notes']?.toString(),
      meetingStatus: json['meeting_status']?.toString() ?? 'not_required',
      meetingCounterBy: json['meeting_counter_by']?.toString(),
      meetingCounterDate: json['meeting_counter_date']?.toString(),
      meetingCounterTime: json['meeting_counter_time']?.toString(),
      meetingCounterLocation: json['meeting_counter_location']?.toString(),
      meetingCounterLat: json['meeting_counter_lat'] != null
          ? (json['meeting_counter_lat'] is double
              ? json['meeting_counter_lat']
              : double.tryParse(json['meeting_counter_lat'].toString()))
          : null,
      meetingCounterLng: json['meeting_counter_lng'] != null
          ? (json['meeting_counter_lng'] is double
              ? json['meeting_counter_lng']
              : double.tryParse(json['meeting_counter_lng'].toString()))
          : null,
      meetingCounterNotes: json['meeting_counter_notes']?.toString(),
      meetingCounterStatus: json['meeting_counter_status']?.toString(),
      escrowStatus: json['escrow_status']?.toString() ?? 'none',
      eventProgress: json['event_progress'] != null
          ? int.tryParse(json['event_progress'].toString()) ?? 0
          : 0,
      postedBy: json['posted_by']?.toString(),
      createdAt: json['created_at']?.toString(),
      poster: json['poster'] != null
          ? OpportunityPoster.fromJson(json['poster'])
          : null,
      requirements: reqsList,
      approvedCreators: approvedList,
      applicationsCount: json['applications_count'] != null
          ? int.tryParse(json['applications_count'].toString()) ?? 0
          : (json['applications'] is List
              ? (json['applications'] as List).length
              : 0),
      externalRating: json['external_rating'] != null
          ? (json['external_rating'] is num
              ? (json['external_rating'] as num).toDouble()
              : double.tryParse(json['external_rating'].toString()))
          : null,
      externalRatingSource: json['external_rating_source']?.toString(),
      externalProofUrl: json['external_proof_url']?.toString(),
      signatureType: json['signature_type']?.toString(),
      clientSignature: json['client_signature']?.toString(),
      clientSignedAt: json['client_signed_at']?.toString(),
      wetSignatureDocumentUrl: json['wet_signature_document_url']?.toString(),
      wetSignatureVerifiedAt: json['wet_signature_verified_at']?.toString(),
      officialAcceptanceLetterUrl: json['official_acceptance_letter_url']?.toString(),
      officialAcceptanceLetterName: json['official_acceptance_letter_name']?.toString(),
      officialAcceptanceLetterUploadedAt: json['official_acceptance_letter_uploaded_at']?.toString(),
      escrowAmount: json['escrow_amount'] != null
          ? (json['escrow_amount'] is num
              ? (json['escrow_amount'] as num).toDouble()
              : double.tryParse(json['escrow_amount'].toString()))
          : null,
      dynamicTerms: json['dynamic_terms'] is List
          ? (json['dynamic_terms'] as List).map((e) => e.toString()).toList()
          : [],
      adminName: json['admin_name']?.toString(),
      adminSignatureUrl: json['admin_signature_url']?.toString(),
      adminSignedAt: json['admin_signed_at']?.toString(),
      adminStartedAt: json['admin_started_at']?.toString(),
      autoReleaseTriggeredAt: json['auto_release_triggered_at']?.toString(),
      gracePeriodDeadline: json['grace_period_deadline']?.toString(),
      isGracePeriodActive: json['is_grace_period_active'] == true,
      gracePeriodDaysLeft: json['grace_period_days_left'] != null
          ? int.tryParse(json['grace_period_days_left'].toString()) ?? 0
          : 0,
      isWetSignatureRequired: json['is_wet_signature_required'] == true,
      isDynamicSignatureRequired: json['is_dynamic_signature_required'] == true ||
          json['signature_type'] == 'dynamic_electronic',
      hasApplied: json['has_applied'] == true || json['has_applied'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'poster_url': posterUrl,
      'banner_url': bannerUrl,
      'sub_role_slug': subRoleSlug,
      'type': type,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'location_category': locationCategory,
      'address': address,
      'deadline': deadline,
      'event_date': eventDate,
      'event_start_date': eventStartDate,
      'event_end_date': eventEndDate,
      'event_start_time': eventStartTime,
      'event_end_time': eventEndTime,
      'budget_range': budgetRange,
      'status': status,
      'meeting_date': meetingDate,
      'meeting_time': meetingTime,
      'meeting_location': meetingLocation,
      'meeting_lat': meetingLat,
      'meeting_lng': meetingLng,
      'meeting_notes': meetingNotes,
      'meeting_status': meetingStatus,
      'meeting_counter_by': meetingCounterBy,
      'meeting_counter_date': meetingCounterDate,
      'meeting_counter_time': meetingCounterTime,
      'meeting_counter_location': meetingCounterLocation,
      'meeting_counter_lat': meetingCounterLat,
      'meeting_counter_lng': meetingCounterLng,
      'meeting_counter_notes': meetingCounterNotes,
      'meeting_counter_status': meetingCounterStatus,
      'escrow_status': escrowStatus,
      'event_progress': eventProgress,
      'posted_by': postedBy,
      'created_at': createdAt,
      'poster': poster?.toJson(),
      'requirements': requirements.map((r) => r.toJson()).toList(),
      'approved_creators': approvedCreators.map((c) => c.toJson()).toList(),
      'external_rating': externalRating,
      'external_rating_source': externalRatingSource,
      'external_proof_url': externalProofUrl,
      'signature_type': signatureType,
      'client_signature': clientSignature,
      'client_signed_at': clientSignedAt,
      'wet_signature_document_url': wetSignatureDocumentUrl,
      'wet_signature_verified_at': wetSignatureVerifiedAt,
      'official_acceptance_letter_url': officialAcceptanceLetterUrl,
      'official_acceptance_letter_name': officialAcceptanceLetterName,
      'official_acceptance_letter_uploaded_at': officialAcceptanceLetterUploadedAt,
      'escrow_amount': escrowAmount,
      'dynamic_terms': dynamicTerms,
      'admin_name': adminName,
      'admin_signature_url': adminSignatureUrl,
      'admin_signed_at': adminSignedAt,
      'admin_started_at': adminStartedAt,
      'auto_release_triggered_at': autoReleaseTriggeredAt,
      'grace_period_deadline': gracePeriodDeadline,
      'is_grace_period_active': isGracePeriodActive,
      'grace_period_days_left': gracePeriodDaysLeft,
      'is_wet_signature_required': isWetSignatureRequired,
      'is_dynamic_signature_required': isDynamicSignatureRequired,
      'has_applied': hasApplied,
    };
  }

  String get locationCategoryLabel {
    switch (locationCategory) {
      case 'nature':
        return 'Alam';
      case 'tourism':
        return 'Wisata';
      case 'culture':
        return 'Budaya';
      case 'urban':
        return 'Urban';
      case 'hidden_gems':
        return 'Hidden Gems';
      case 'seasonal':
        return 'Seasonal';
      default:
        return locationCategory ?? 'Lokasi';
    }
  }

  String get subRoleLabel {
    switch (subRoleSlug.toLowerCase()) {
      case 'mc':
        return '🎤 MC & Host Event';
      case 'videographer':
      case 'videografer':
        return '🎥 Videografer';
      case 'photographer':
      case 'fotografer':
        return '📸 Fotografer';
      case 'content_creator':
        return '🎬 Content Creator';
      case 'animator':
        return '🎨 Animator';
      case 'editor':
        return '✂️ Editor Video';
      case 'desainer':
        return '🖌️ Desainer Grafis';
      case 'musisi':
        return '🎵 Musisi & Audio';
      case 'talent':
        return '💃 Model & Talent';
      case 'tukang_kendang':
        return '🥁 Tukang Kendang';
      case 'wedding_organizer':
        return '💍 Wedding Organizer';
      case 'event_organizer':
        return '🎪 Event Organizer';
      case 'makeup_artist':
        return '💄 Makeup Artist';
      case 'singer':
        return '🎤 Penyanyi';
      default:
        return subRoleSlug.isNotEmpty ? subRoleSlug : '⭐ Creator';
    }
  }
}
