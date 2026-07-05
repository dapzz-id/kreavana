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
      subRole: json['sub_role'],
      isCreatorApproved: json['is_creator_approved'] == 1 ||
          json['is_creator_approved'] == true ||
          json['is_creator_approved'] == '1',
      createdAt: json['created_at'],
      balance: json['balance'] != null ? double.parse(json['balance'].toString()) : 0.0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
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
      createdAt: createdAt,
      balance: balance ?? this.balance,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
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
