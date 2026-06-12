// lib/models/user_model.dart

class UserModel {
  final int id;
  final String name;
  final String? email;
  final String? gender;
  final String? country;
  final String? bio;
  final String? avatarUrl;
  final String? referralCode;
  final String? vipLevel;
  final bool isVip;
  final bool isIncognito;
  final String? verificationStatus;
  final int level;
  final String rankName;
  final int levelProgress;
  final int xpPoints;
  final bool isOnline;
  final String? lastSeenAt;
  final bool isAdmin;
  final bool isPublisher;
  final int tokens;
  final int earnedCoins;
  final List<MediaItem> media;
  // Social stats
  final int followersCount;
  final int followingCount;
  final int totalLikes;
  // Gift showcase
  final List<GiftItem> gifts;
  // Status posts
  final List<StatusPost> statuses;
  // Agency
  final String? agencyName;
  final bool isAgencyOwner;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.gender,
    this.country,
    this.bio,
    this.avatarUrl,
    this.referralCode,
    this.vipLevel,
    this.isVip = false,
    this.isIncognito = false,
    this.verificationStatus,
    this.level = 1,
    this.rankName = 'Bronz I',
    this.levelProgress = 0,
    this.xpPoints = 0,
    this.isOnline = false,
    this.lastSeenAt,
    this.isAdmin = false,
    this.isPublisher = false,
    this.tokens = 0,
    this.earnedCoins = 0,
    this.media = const [],
    this.followersCount = 0,
    this.followingCount = 0,
    this.totalLikes = 0,
    this.gifts = const [],
    this.statuses = const [],
    this.agencyName,
    this.isAgencyOwner = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:                 json['id'] as int,
      name:               json['name'] as String,
      email:              json['email'] as String?,
      gender:             json['gender'] as String?,
      country:            json['country'] as String?,
      bio:                json['bio'] as String?,
      avatarUrl:          json['avatar_url'] as String?,
      referralCode:       json['referral_code'] as String?,
      vipLevel:           json['vip_level'] as String?,
      isVip:              _parseBool(json['is_vip']),
      isIncognito:        _parseBool(json['is_incognito']),
      verificationStatus: json['verification_status'] as String?,
      level:              json['level'] as int? ?? 1,
      rankName:           json['rank_name'] as String? ?? 'Bronz I',
      levelProgress:      json['level_progress'] as int? ?? 0,
      xpPoints:           json['xp_points'] as int? ?? 0,
      isOnline:           _parseBool(json['is_online']),
      lastSeenAt:         json['last_seen_at'] as String?,
      isAdmin:            _parseBool(json['is_admin']),
      isPublisher:        _parseBool(json['is_publisher']),
      tokens:             json['tokens'] as int? ?? 0,
      earnedCoins:        json['earned_coins'] as int? ?? 0,
      media:              (json['media'] as List<dynamic>?)
          ?.map((m) => MediaItem.fromJson(m))
          .toList() ?? [],
      followersCount:     json['followers_count'] as int? ?? 0,
      followingCount:     json['following_count'] as int? ?? 0,
      totalLikes:         json['total_likes'] as int? ?? 0,
      gifts:              (json['gifts'] as List<dynamic>?)
          ?.map((g) => GiftItem.fromJson(g))
          .toList() ?? [],
      statuses:           (json['statuses'] as List<dynamic>?)
          ?.map((s) => StatusPost.fromJson(s))
          .toList() ?? [],
      agencyName:         json['agency_name'] as String?,
      isAgencyOwner:      _parseBool(json['is_agency_owner']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                  id,
    'name':                name,
    'email':               email,
    'gender':              gender,
    'country':             country,
    'bio':                 bio,
    'avatar_url':          avatarUrl,
    'referral_code':       referralCode,
    'vip_level':           vipLevel,
    'is_vip':              isVip,
    'is_incognito':        isIncognito,
    'verification_status': verificationStatus,
    'level':               level,
    'rank_name':           rankName,
    'level_progress':      levelProgress,
    'xp_points':           xpPoints,
    'is_online':           isOnline,
    'last_seen_at':        lastSeenAt,
    'is_admin':            isAdmin,
    'is_publisher':        isPublisher,
    'tokens':              tokens,
    'earned_coins':        earnedCoins,
    'media':               media.map((m) => m.toJson()).toList(),
  };

  UserModel copyWith({
    String? name,
    String? email,
    String? bio,
    String? country,
    String? avatarUrl,
    String? referralCode,
    String? vipLevel,
    bool? isVip,
    bool? isIncognito,
    int? tokens,
    int? earnedCoins,
    List<MediaItem>? media,
    int? followersCount,
    int? followingCount,
    int? totalLikes,
    int? xpPoints,
  }) {
    return UserModel(
      id:                 id,
      name:               name ?? this.name,
      email:              email ?? this.email,
      gender:             gender,
      country:            country ?? this.country,
      bio:                bio ?? this.bio,
      avatarUrl:          avatarUrl ?? this.avatarUrl,
      referralCode:       referralCode ?? this.referralCode,
      vipLevel:           vipLevel ?? this.vipLevel,
      isVip:              isVip ?? this.isVip,
      isIncognito:        isIncognito ?? this.isIncognito,
      verificationStatus: verificationStatus,
      level:              level,
      rankName:           rankName,
      levelProgress:      levelProgress,
      isOnline:           isOnline,
      lastSeenAt:         lastSeenAt,
      isAdmin:            isAdmin,
      isPublisher:        isPublisher,
      tokens:             tokens ?? this.tokens,
      earnedCoins:        earnedCoins ?? this.earnedCoins,
      media:              media ?? this.media,
      followersCount:     followersCount ?? this.followersCount,
      followingCount:     followingCount ?? this.followingCount,
      totalLikes:         totalLikes ?? this.totalLikes,
      gifts:              gifts,
      statuses:           statuses,
      agencyName:         agencyName,
      isAgencyOwner:      isAgencyOwner,
      xpPoints:           xpPoints ?? this.xpPoints,
    );
  }

  String? get firstPhotoUrl {
    for (var m in media) {
      if (m.type == 'photo' || m.type == 'image') {
        if (m.url.trim().isEmpty) continue;
        final url = m.url.toLowerCase();
        if (!url.endsWith('.mov') && !url.endsWith('.mp4') && !url.endsWith('.avi') && !url.endsWith('.mkv') && !url.endsWith('.webm')) {
          return m.url;
        }
      }
    }
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final url = avatarUrl!.toLowerCase();
      if (!url.endsWith('.mov') && !url.endsWith('.mp4') && !url.endsWith('.avi') && !url.endsWith('.mkv') && !url.endsWith('.webm')) {
        return avatarUrl;
      }
    }
    return null;
  }
}

class MediaItem {
  final int id;
  final String url;
  final String type; // 'photo' | 'video'

  MediaItem({required this.id, required this.url, required this.type});

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id:   json['id'] as int,
      url:  json['url'] as String,
      type: json['type'] as String? ?? 'photo',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'url': url, 'type': type};
}

class GiftItem {
  final String emoji;
  final int count;
  final String name;

  GiftItem({required this.emoji, required this.count, required this.name});

  factory GiftItem.fromJson(Map<String, dynamic> json) {
    return GiftItem(
      emoji: json['emoji'] as String? ?? '🎁',
      count: json['count'] as int? ?? 1,
      name:  json['name'] as String? ?? '',
    );
  }
}

class StatusPost {
  final int id;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;

  StatusPost({
    required this.id,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
  });

  factory StatusPost.fromJson(Map<String, dynamic> json) {
    return StatusPost(
      id:         json['id'] as int,
      content:    json['content'] as String? ?? '',
      createdAt:  DateTime.parse(json['created_at'] as String),
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked:    _parseBool(json['is_liked']),
    );
  }
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1';
  }
  return false;
}
