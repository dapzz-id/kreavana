class OpportunityPoster {
  final String? id;
  final String name;
  final String username;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? selectedSubRole;

  OpportunityPoster({
    required this.id,
    required this.name,
    required this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    this.selectedSubRole,
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
  final String subRoleSlug;
  final String type; // 'location' | 'project'
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? locationCategory;
  final String? address;
  final String? deadline;
  final String? eventDate;
  final String? eventStartTime;
  final String? eventEndTime;
  final String? budgetRange;
  final String status;
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
    required this.subRoleSlug,
    this.type = 'project',
    this.location,
    this.latitude,
    this.longitude,
    this.locationCategory,
    this.address,
    this.deadline,
    this.eventDate,
    this.eventStartTime,
    this.eventEndTime,
    this.budgetRange,
    this.status = 'open',
    this.postedBy,
    this.createdAt,
    this.poster,
    this.requirements = const [],
    this.approvedCreators = const [],
    this.applicationsCount = 0,
  });

  bool get isLocation => type == 'location';
  bool get isProject => type == 'project';

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
      eventStartTime: json['event_start_time']?.toString(),
      eventEndTime: json['event_end_time']?.toString(),
      budgetRange: json['budget_range'],
      status: json['status'] ?? 'open',
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
      'sub_role_slug': subRoleSlug,
      'type': type,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'location_category': locationCategory,
      'address': address,
      'deadline': deadline,
      'event_date': eventDate,
      'event_start_time': eventStartTime,
      'event_end_time': eventEndTime,
      'budget_range': budgetRange,
      'status': status,
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
