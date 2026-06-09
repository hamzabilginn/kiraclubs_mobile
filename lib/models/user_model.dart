// lib/models/user_model.dart

class UserModel {
  final int id;
  final String name;
  final String? email;
  final String? gender;
  final String? country;
  final String? bio;
  final String? avatarUrl;
  final String? vipLevel;
  final bool isVip;
  final String? verificationStatus;
  final int level;
  final String rankName;
  final int levelProgress;
  final bool isOnline;
  final String? lastSeenAt;
  final bool isAdmin;
  final bool isPublisher;
  final int tokens;
  final int earnedCoins;
  final List<MediaItem> media;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.gender,
    this.country,
    this.bio,
    this.avatarUrl,
    this.vipLevel,
    this.isVip = false,
    this.verificationStatus,
    this.level = 1,
    this.rankName = 'Bronz I',
    this.levelProgress = 0,
    this.isOnline = false,
    this.lastSeenAt,
    this.isAdmin = false,
    this.isPublisher = false,
    this.tokens = 0,
    this.earnedCoins = 0,
    this.media = const [],
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
      vipLevel:           json['vip_level'] as String?,
      isVip:              json['is_vip'] as bool? ?? false,
      verificationStatus: json['verification_status'] as String?,
      level:              json['level'] as int? ?? 1,
      rankName:           json['rank_name'] as String? ?? 'Bronz I',
      levelProgress:      json['level_progress'] as int? ?? 0,
      isOnline:           json['is_online'] as bool? ?? false,
      lastSeenAt:         json['last_seen_at'] as String?,
      isAdmin:            json['is_admin'] as bool? ?? false,
      isPublisher:        json['is_publisher'] as bool? ?? false,
      tokens:             json['tokens'] as int? ?? 0,
      earnedCoins:        json['earned_coins'] as int? ?? 0,
      media:              (json['media'] as List<dynamic>?)
          ?.map((m) => MediaItem.fromJson(m))
          .toList() ?? [],
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
    'vip_level':           vipLevel,
    'is_vip':              isVip,
    'verification_status': verificationStatus,
    'level':               level,
    'rank_name':           rankName,
    'level_progress':      levelProgress,
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
    String? vipLevel,
    bool? isVip,
    int? tokens,
    int? earnedCoins,
    List<MediaItem>? media,
  }) {
    return UserModel(
      id:                 id,
      name:               name ?? this.name,
      email:              email ?? this.email,
      gender:             gender,
      country:            country ?? this.country,
      bio:                bio ?? this.bio,
      avatarUrl:          avatarUrl ?? this.avatarUrl,
      vipLevel:           vipLevel ?? this.vipLevel,
      isVip:              isVip ?? this.isVip,
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
    );
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
