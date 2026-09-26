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

  OpportunityRequirementModel({
    this.id,
    required this.subRoleSlug,
    this.quantity = 1,
    this.notes,
  });

  factory OpportunityRequirementModel.fromJson(Map<String, dynamic> json) {
    return OpportunityRequirementModel(
      id: json['id']?.toString(),
      subRoleSlug: json['sub_role_slug'] ?? '',
      quantity: (json['quantity_needed'] ?? json['quantity']) != null
          ? int.tryParse((json['quantity_needed'] ?? json['quantity']).toString()) ?? 1
          : 1,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_role_slug': subRoleSlug,
      'quantity': quantity,
      'notes': notes,
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
  final String name;
  final String username;
  final String? avatarUrl;
  final String? subRole;
  final String? capability;

  OpportunityApprovedCreatorModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.subRole,
    this.capability,
  });

  factory OpportunityApprovedCreatorModel.fromJson(Map<String, dynamic> json) {
    return OpportunityApprovedCreatorModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      subRole: json['sub_role'],
      capability: json['capability'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatar_url': avatarUrl,
      'sub_role': subRole,
      'capability': capability,
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
  final String escrowStatus; // 'none', 'pending_deposit', 'held_in_escrow', 'released_to_creators'
  final int eventProgress;
  final String? postedBy;
  final String? createdAt;
  final OpportunityPoster? poster;
  final List<OpportunityRequirementModel> requirements;
  final List<OpportunityApprovedCreatorModel> approvedCreators;
  final int applicationsCount;

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
    this.escrowStatus = 'none',
    this.eventProgress = 0,
    this.postedBy,
    this.createdAt,
    this.poster,
    this.requirements = const [],
    this.approvedCreators = const [],
    this.applicationsCount = 0,
  });

  bool get isLocation => type == 'location';
  bool get isProject => type == 'project';
  bool get isOngoing => status.toLowerCase() == 'in_progress' || status.toLowerCase() == 'ongoing';
  bool get isClosed => status.toLowerCase() == 'closed' || status.toLowerCase() == 'completed';

  bool get isLargeTransaction {
    final b = (budgetRange ?? '').toLowerCase();
    return b.contains('20.000.000') || b.contains('50.000.000') || b.contains('mou') || meetingStatus != 'not_required';
  }

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
    String? escrowStatus,
    int? eventProgress,
    String? postedBy,
    String? createdAt,
    OpportunityPoster? poster,
    List<OpportunityRequirementModel>? requirements,
    List<OpportunityApprovedCreatorModel>? approvedCreators,
    int? applicationsCount,
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
      escrowStatus: escrowStatus ?? this.escrowStatus,
      eventProgress: eventProgress ?? this.eventProgress,
      postedBy: postedBy ?? this.postedBy,
      createdAt: createdAt ?? this.createdAt,
      poster: poster ?? this.poster,
      requirements: requirements ?? this.requirements,
      approvedCreators: approvedCreators ?? this.approvedCreators,
      applicationsCount: applicationsCount ?? this.applicationsCount,
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
      'escrow_status': escrowStatus,
      'event_progress': eventProgress,
      'posted_by': postedBy,
      'created_at': createdAt,
      'poster': poster?.toJson(),
      'requirements': requirements.map((r) => r.toJson()).toList(),
      'approved_creators': approvedCreators.map((c) => c.toJson()).toList(),
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
