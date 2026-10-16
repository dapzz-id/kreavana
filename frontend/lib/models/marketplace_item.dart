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

  List<String> get allImageUrls {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      urls.add(imageUrl!.trim());
    }
    if (media != null && media!.isNotEmpty) {
      for (final m in media!) {
        if (m.fileType != 'video' && m.filePath.trim().isNotEmpty) {
          if (!urls.contains(m.filePath.trim())) {
            urls.add(m.filePath.trim());
          }
        }
      }
    }
    if (urls.isEmpty) {
      urls.add(displayImageUrl);
    }
    return urls;
  }

  String get displayImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl!.trim();
    }
    if (media != null && media!.isNotEmpty) {
      final firstImg = media!.firstWhere(
        (m) => m.fileType != 'video' && m.filePath.trim().isNotEmpty,
        orElse: () => media!.first,
      );
      if (firstImg.filePath.trim().isNotEmpty) {
        return firstImg.filePath.trim();
      }
    }

    final t = title.toLowerCase();
    final c = category.toLowerCase();

    if (t.contains('lut') || t.contains('color grade') || t.contains('s-log')) {
      return 'https://images.unsplash.com/photo-1533750516457-a7f992034fec?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('after effects') || t.contains('opening') || t.contains('intro')) {
      return 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('profil perusahaan') || t.contains('liputan') || t.contains('multicam')) {
      return 'https://images.unsplash.com/photo-1518133910546-b6c2fb7d79e3?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('sound fx') || t.contains('audio') || t.contains('transitions')) {
      return 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('brand identity') || t.contains('logo package') || t.contains('guidelines')) {
      return 'https://images.unsplash.com/photo-1600132806370-bf17e65e942f?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('proposal bisnis') || t.contains('sponsorship') || t.contains('mou')) {
      return 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('design system') || t.contains('mobile app') || t.contains('figma') || t.contains('ui kit')) {
      return 'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('feed') || t.contains('instagram') || t.contains('umkm')) {
      return 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('3d icon') || t.contains('blender')) {
      return 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('maskot') || t.contains('ilustrasi') || t.contains('vektor')) {
      return 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('lightroom') || t.contains('wedding') || t.contains('warm')) {
      return 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('wisuda') || t.contains('portrait') || t.contains('studio')) {
      return 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('street') || t.contains('urban') || t.contains('cyberpunk')) {
      return 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('katalog') || t.contains('commercial') || t.contains('e-commerce')) {
      return 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('kalender konten') || t.contains('copywriting')) {
      return 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('tiktok') || t.contains('hook') || t.contains('reels')) {
      return 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?auto=format&fit=crop&w=1200&q=80';
    }
    if (t.contains('notion') || t.contains('workspace') || t.contains('planner')) {
      return 'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?auto=format&fit=crop&w=1200&q=80';
    }

    switch (c) {
      case 'videografi':
        return 'https://images.unsplash.com/photo-1533750516457-a7f992034fec?auto=format&fit=crop&w=1200&q=80';
      case 'fotografi':
        return 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80';
      case 'desain':
        return 'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?auto=format&fit=crop&w=1200&q=80';
      case 'branding':
        return 'https://images.unsplash.com/photo-1600132806370-bf17e65e942f?auto=format&fit=crop&w=1200&q=80';
      case 'konten':
        return 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=1200&q=80';
      default:
        return 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';
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
