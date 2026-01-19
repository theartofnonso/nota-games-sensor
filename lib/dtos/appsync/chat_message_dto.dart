/// Simple chat message DTO
/// Represents a single text message in a conversation
class ChatMessageDto {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  ChatMessageDto({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  factory ChatMessageDto.fromJson({required Map<String, dynamic> json}) {
    return ChatMessageDto(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
