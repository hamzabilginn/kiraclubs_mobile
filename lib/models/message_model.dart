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

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id:        json['id'] as int,
      body:      json['body'] as String? ?? '',
      type:      json['type'] as String? ?? 'text',
      isMine:    json['is_mine'] as bool? ?? false,
      isRead:    json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
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
      body:      json['body'] as String? ?? '',
      type:      json['type'] as String? ?? 'text',
      isMine:    json['is_mine'] as bool? ?? false,
      isRead:    json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
