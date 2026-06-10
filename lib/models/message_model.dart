import 'user_model.dart';

class MessageModel {
  final int id;
  final String body;
  final String type; // 'text' | 'image' | 'voice'
  final bool isMine;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.body,
    required this.type,
    required this.isMine,
    required this.isRead,
    required this.createdAt,
  });

  static DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    final str = val.toString();
    try {
      return DateTime.parse(str);
    } catch (_) {
      try {
        final parts = str.split(':');
        if (parts.length >= 2) {
          final now = DateTime.now();
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      } catch (_) {}
      return DateTime.now();
    }
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id:        json['id'] as int,
      body:      json['body'] as String? ?? json['translated_text'] as String? ?? json['original_text'] as String? ?? '',
      type:      json['type'] as String? ?? 'text',
      isMine:    json['is_mine'] as bool? ?? false,
      isRead:    json['is_read'] as bool? ?? false,
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

class ConversationModel {
  final UserModel partner;
  final LastMessage? lastMessage;
  final int unreadCount;

  ConversationModel({
    required this.partner,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      partner:     UserModel.fromJson(json['partner'] as Map<String, dynamic>),
      lastMessage: json['last_message'] != null
          ? LastMessage.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

class LastMessage {
  final String body;
  final String type;
  final bool isMine;
  final bool isRead;
  final DateTime createdAt;

  LastMessage({
    required this.body,
    required this.type,
    required this.isMine,
    required this.isRead,
    required this.createdAt,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      body:      json['body'] as String? ?? json['translated_text'] as String? ?? json['original_text'] as String? ?? '',
      type:      json['type'] as String? ?? 'text',
      isMine:    json['is_mine'] as bool? ?? false,
      isRead:    json['is_read'] as bool? ?? false,
      createdAt: MessageModel._parseDateTime(json['created_at']),
    );
  }
}

class CallLogItem {
  final int id;
  final UserModel user;
  final String type; // 'call_ended' | 'call_missed'
  final int duration; // saniye cinsinden
  final String direction; // 'incoming' | 'outgoing'
  final DateTime createdAt;

  CallLogItem({
    required this.id,
    required this.user,
    required this.type,
    required this.duration,
    required this.direction,
    required this.createdAt,
  });

  factory CallLogItem.fromJson(Map<String, dynamic> json) {
    return CallLogItem(
      id:        json['id'] as int,
      user:      UserModel.fromJson(json['user'] as Map<String, dynamic>),
      type:      json['type'] as String? ?? 'call_ended',
      duration:  json['duration'] as int? ?? 0,
      direction: json['direction'] as String? ?? 'incoming',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
