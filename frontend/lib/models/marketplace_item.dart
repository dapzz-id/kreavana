class MarketplaceItem {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String category;
  final String type;
  final double price;
  final double rating;
  final int reviewCount;
  final int orderCount;
  final String? imageUrl;
  final bool isFeatured;
  final bool isActive;
  final String status;
  final bool isFollowing;
  final bool hasPurchased;
  final bool hasReviewed;
  final bool canReview;
  final String? createdAt;
  final MarketplaceCreator? creator;
  final List<MarketplaceReview>? reviews;
  final List<MarketplaceMedia>? media;

  MarketplaceItem({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.category,
    required this.type,
    required this.price,
    this.rating = 0,
    this.reviewCount = 0,
    this.orderCount = 0,
    this.imageUrl,
    this.isFeatured = false,
    required this.isActive,
    this.status = 'published',
    this.isFollowing = false,
    this.hasPurchased = false,
    this.hasReviewed = false,
    this.canReview = false,
    this.createdAt,
    this.creator,
    this.reviews,
    this.media,
  });

  static bool _parseBool(dynamic val, [bool fallback = false]) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val == 1;
    final s = val.toString().toLowerCase().trim();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
    return fallback;
  }

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceItem(
      id: json['id']?.toString() ?? '',
      userId: (json['user_id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? 'Lainnya',
      type: json['type']?.toString() ?? 'free',
      price: (json['price'] != null)
          ? double.tryParse(json['price'].toString()) ?? 0
          : 0,
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0,
      reviewCount: int.tryParse(json['review_count']?.toString() ?? '') ?? 0,
      orderCount: int.tryParse(json['order_count']?.toString() ?? '') ?? 0,
      imageUrl: json['image_url']?.toString(),
      isFeatured: _parseBool(json['is_featured'], false),
      isActive: _parseBool(json['is_active'], true),
      status: json['status']?.toString() ?? 'published',
      isFollowing: _parseBool(json['is_following'], false),
      hasPurchased: _parseBool(json['has_purchased'], false),
      hasReviewed: _parseBool(json['has_reviewed'], false),
      canReview: _parseBool(json['can_review'], false),
      createdAt: json['created_at']?.toString(),
      creator: json['user'] is Map
          ? MarketplaceCreator.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
      reviews: json['reviews'] is List
          ? (json['reviews'] as List)
                .whereType<Map>()
                .map((r) => MarketplaceReview.fromJson(Map<String, dynamic>.from(r)))
                .toList()
          : null,
      media: json['media'] is List
          ? (json['media'] as List)
                .whereType<Map>()
                .map((e) => MarketplaceMedia.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : null,
    );
  }

  String get formattedPrice {
    if (price >= 1000000) {
      return 'Rp ${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)}.000.000';
    }
    final s = price.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  String get timeAgo {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt!);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
      return '${(diff.inDays / 30).floor()} bulan lalu';
    } catch (_) {
      return '';
    }
  }
}

class MarketplaceCreator {
  final String? id;
  final String? name;
  final String? username;
  final String? avatarUrl;
  final String? phone;
  final String? email;
  final bool? isOnline;
  final bool? isTyping;
  final String? lastOnline;

  MarketplaceCreator({
    this.id,
    this.name,
    this.username,
    this.avatarUrl,
    this.phone,
    this.email,
    this.isOnline,
    this.isTyping,
    this.lastOnline,
  });

  factory MarketplaceCreator.fromJson(Map<String, dynamic> json) {
    return MarketplaceCreator(
      id: json['id']?.toString(),
      name: json['name'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      phone: json['phone'],
      email: json['email'],
      isOnline: json['is_online'] == true || json['isOnline'] == true,
      isTyping: json['is_typing'] == true || json['isTyping'] == true,
      lastOnline:
          json['last_online'] ??
          json['lastOnline'] ??
          json['last_seen'] ??
          json['lastSeen'],
    );
  }
}

class MarketplaceReview {
  final String id;
  final String? comment;
  final int rating;
  final MarketplaceCreator? user;
  final String? createdAt;

  MarketplaceReview({
    required this.id,
    this.comment,
    required this.rating,
    this.user,
    this.createdAt,
  });

  factory MarketplaceReview.fromJson(Map<String, dynamic> json) {
    return MarketplaceReview(
      id: json['id'].toString(),
      comment: json['comment'],
      rating: json['rating'] ?? 0,
      user: json['user'] != null
          ? MarketplaceCreator.fromJson(json['user'])
          : null,
      createdAt: json['created_at'],
    );
  }
}

class MarketplaceMedia {
  final String id;
  final String filePath;
  final String fileType;

  MarketplaceMedia({
    required this.id,
    required this.filePath,
    required this.fileType,
  });

  factory MarketplaceMedia.fromJson(Map<String, dynamic> json) {
    return MarketplaceMedia(
      id: json['id']?.toString() ?? '',
      filePath: json['file_path'] ?? '',
      fileType: json['file_type'] ?? 'image',
    );
  }
}
