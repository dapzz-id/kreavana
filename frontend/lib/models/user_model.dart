class UserModel {
  final int id;
  final String name;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? phone;
  final String role; // 'user' or 'creator'
  final String selectedPihak;
  final bool isCreatorApproved;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.phone,
    this.role = 'user',
    this.selectedPihak = 'kreator',
    this.isCreatorApproved = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      phone: json['phone'],
      role: json['role'] ?? 'user',
      selectedPihak: json['selected_pihak'] ?? 'kreator',
      isCreatorApproved: json['is_creator_approved'] == 1 ||
          json['is_creator_approved'] == true ||
          json['is_creator_approved'] == '1',
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'phone': phone,
      'role': role,
      'selected_pihak': selectedPihak,
      'is_creator_approved': isCreatorApproved ? 1 : 0,
      'created_at': createdAt,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? username,
    String? email,
    String? avatarUrl,
    String? phone,
    String? role,
    String? selectedPihak,
    bool? isCreatorApproved,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      selectedPihak: selectedPihak ?? this.selectedPihak,
      isCreatorApproved: isCreatorApproved ?? this.isCreatorApproved,
      createdAt: createdAt,
    );
  }

  bool get isCreator => role == 'creator' && isCreatorApproved;
  bool get isAdmin => role == 'admin';
}

class PihakCategory {
  final String slug;
  final String name;
  final String? description;
  final String? icon;
  final String? color;

  PihakCategory({
    required this.slug,
    required this.name,
    this.description,
    this.icon,
    this.color,
  });

  factory PihakCategory.fromJson(Map<String, dynamic> json) {
    return PihakCategory(
      slug: json['slug'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'],
      color: json['color'],
    );
  }
}

class CreatorApplication {
  final int id;
  final int userId;
  final String pihakCategory;
  final String skillDescription;
  final String? portfolioLink;
  final String? experience;
  final String status; // 'pending', 'approved', 'rejected'
  final String? adminNote;
  final String? appliedAt;

  CreatorApplication({
    required this.id,
    required this.userId,
    required this.pihakCategory,
    required this.skillDescription,
    this.portfolioLink,
    this.experience,
    this.status = 'pending',
    this.adminNote,
    this.appliedAt,
  });

  factory CreatorApplication.fromJson(Map<String, dynamic> json) {
    return CreatorApplication(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int
          ? json['user_id']
          : int.parse(json['user_id'].toString()),
      pihakCategory: json['pihak_category'] ?? '',
      skillDescription: json['skill_description'] ?? '',
      portfolioLink: json['portfolio_link'],
      experience: json['experience'],
      status: json['status'] ?? 'pending',
      adminNote: json['admin_note'],
      appliedAt: json['applied_at'],
    );
  }
}
