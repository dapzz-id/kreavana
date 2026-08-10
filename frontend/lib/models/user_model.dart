class UserModel {
  final String? id;
  final String name;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? phone;
  final String role; // 'user' or 'creator'
  final String? subRole;
  final bool isCreatorApproved;
  final String? createdAt;
  final double balance;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final String subscriptionTier;
  final int storageLimitBytes;
  final int usedStorageBytes;
  final int maxVoiceCallDurationSeconds;
  final int maxVideoCallDurationSeconds;
  final double performanceBoost;
  final String? publicKey;

  UserModel({
    this.id,
    required this.name,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.phone,
    this.role = 'user',
    this.subRole,
    this.isCreatorApproved = false,
    this.createdAt,
    this.balance = 0.0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.subscriptionTier = 'free',
    this.storageLimitBytes = 104857600, // 100MB default
    this.usedStorageBytes = 0,
    this.publicKey,
    this.maxVoiceCallDurationSeconds = 3600,
    this.maxVideoCallDurationSeconds = 1800,
    this.performanceBoost = 1.0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      phone: json['phone'],
      role: json['role'] ?? 'user',
      subRole: json['sub_role'] is Map
          ? json['sub_role']['value']?.toString()
          : json['sub_role']?.toString(),
      isCreatorApproved: json['is_creator_approved'] == 1 ||
          json['is_creator_approved'] == true ||
          json['is_creator_approved'] == '1',
      createdAt: json['created_at'],
      balance: json['balance'] != null ? double.parse(json['balance'].toString()) : 0.0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      subscriptionTier: json['subscription_tier'] ?? 'free',
      storageLimitBytes: json['storage_limit_bytes'] ?? 104857600,
      usedStorageBytes: json['used_storage_bytes'] ?? 0,
      publicKey: json['public_key'],
      maxVoiceCallDurationSeconds: json['max_voice_call_duration_seconds'] ?? 3600,
      maxVideoCallDurationSeconds: json['max_video_call_duration_seconds'] ?? 1800,
      performanceBoost: json['performance_boost'] != null ? double.parse(json['performance_boost'].toString()) : 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'phone': phone,
      'role': role,
      'sub_role': subRole,
      'is_creator_approved': isCreatorApproved ? 1 : 0,
      'created_at': createdAt,
      'balance': balance,
      'followers_count': followersCount,
      'following_count': followingCount,
      'is_following': isFollowing,
      'subscription_tier': subscriptionTier,
      'storage_limit_bytes': storageLimitBytes,
      'used_storage_bytes': usedStorageBytes,
      'public_key': publicKey,
      'max_voice_call_duration_seconds': maxVoiceCallDurationSeconds,
      'max_video_call_duration_seconds': maxVideoCallDurationSeconds,
      'performance_boost': performanceBoost,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? avatarUrl,
    String? phone,
    String? role,
    String? subRole,
    bool? isCreatorApproved,
    double? balance,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    String? subscriptionTier,
    int? storageLimitBytes,
    int? usedStorageBytes,
    String? publicKey,
    int? maxVoiceCallDurationSeconds,
    int? maxVideoCallDurationSeconds,
    double? performanceBoost,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      subRole: subRole ?? this.subRole,
      isCreatorApproved: isCreatorApproved ?? this.isCreatorApproved,
      createdAt: createdAt ?? createdAt,
      balance: balance ?? this.balance,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      storageLimitBytes: storageLimitBytes ?? this.storageLimitBytes,
      usedStorageBytes: usedStorageBytes ?? this.usedStorageBytes,
      publicKey: publicKey ?? this.publicKey,
      maxVoiceCallDurationSeconds: maxVoiceCallDurationSeconds ?? this.maxVoiceCallDurationSeconds,
      maxVideoCallDurationSeconds: maxVideoCallDurationSeconds ?? this.maxVideoCallDurationSeconds,
      performanceBoost: performanceBoost ?? this.performanceBoost,
    );
  }

  bool get isCreator => role == 'creator' && isCreatorApproved;
  bool get isAdmin => role == 'admin';
}

class SubRoleCategory {
  final String slug;
  final String name;
  final String? description;
  final String? icon;
  final String? color;

  SubRoleCategory({
    required this.slug,
    required this.name,
    this.description,
    this.icon,
    this.color,
  });

  factory SubRoleCategory.fromJson(Map<String, dynamic> json) {
    return SubRoleCategory(
      slug: json['slug'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'],
      color: json['color'],
    );
  }
}

class CreatorApplication {
  final String? id;
  final String? userId;
  final String subRoleCategory;
  final String skillDescription;
  final String? portfolioLink;
  final String? experience;
  final String? ktpPhotoUrl;
  final String? selfiePhotoUrl;
  final String? nik;
  final String? fullNameKtp;
  final String? birthPlace;
  final String? birthDate;
  final String? addressKtp;
  final String status;
  final String? adminNote;
  final String? appliedAt;

  CreatorApplication({
    this.id,
    this.userId,
    required this.subRoleCategory,
    required this.skillDescription,
    this.portfolioLink,
    this.experience,
    this.ktpPhotoUrl,
    this.selfiePhotoUrl,
    this.nik,
    this.fullNameKtp,
    this.birthPlace,
    this.birthDate,
    this.addressKtp,
    this.status = 'pending',
    this.adminNote,
    this.appliedAt,
  });

  factory CreatorApplication.fromJson(Map<String, dynamic> json) {
    return CreatorApplication(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString(),
      subRoleCategory: json['sub_role_category'] ?? '',
      skillDescription: json['skill_description'] ?? '',
      portfolioLink: json['portfolio_link'],
      experience: json['experience'],
      ktpPhotoUrl: json['ktp_photo_url'],
      selfiePhotoUrl: json['selfie_photo_url'],
      nik: json['nik'],
      fullNameKtp: json['full_name_ktp'],
      birthPlace: json['birth_place'],
      birthDate: json['birth_date']?.toString(),
      addressKtp: json['address_ktp'],
      status: json['status'] ?? 'pending',
      adminNote: json['admin_note'],
      appliedAt: json['applied_at'],
    );
  }
}
