class OpportunityPoster {
  final int id;
  final String name;
  final String username;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? selectedPihak;

  OpportunityPoster({
    required this.id,
    required this.name,
    required this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    this.selectedPihak,
  });

  factory OpportunityPoster.fromJson(Map<String, dynamic> json) {
    return OpportunityPoster(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      phone: json['phone'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      selectedPihak: json['selected_pihak'],
    );
  }
}

class OpportunityModel {
  final int id;
  final String title;
  final String? description;
  final String pihakSlug;
  final String type; // 'location' | 'project'
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? locationCategory;
  final String? address;
  final String? deadline;
  final String? budgetRange;
  final String status;
  final int postedBy;
  final String? createdAt;
  final OpportunityPoster? poster;

  OpportunityModel({
    required this.id,
    required this.title,
    this.description,
    required this.pihakSlug,
    this.type = 'project',
    this.location,
    this.latitude,
    this.longitude,
    this.locationCategory,
    this.address,
    this.deadline,
    this.budgetRange,
    this.status = 'open',
    required this.postedBy,
    this.createdAt,
    this.poster,
  });

  bool get isLocation => type == 'location';
  bool get isProject => type == 'project';

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      description: json['description'],
      pihakSlug: json['pihak_slug'] ?? '',
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
      budgetRange: json['budget_range'],
      status: json['status'] ?? 'open',
      postedBy: json['posted_by'] is int
          ? json['posted_by']
          : int.parse(json['posted_by'].toString()),
      createdAt: json['created_at']?.toString(),
      poster: json['poster'] != null
          ? OpportunityPoster.fromJson(json['poster'])
          : null,
    );
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
}
