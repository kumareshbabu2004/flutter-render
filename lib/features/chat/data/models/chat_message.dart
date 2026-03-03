/// A single chat message in a tournament chat room.
class ChatMessage {
  final String id;
  final String bracketId;
  final String senderId;
  final String senderName;
  final String? senderLocation; // state abbreviation, e.g. "IL"
  final String message;
  final DateTime timestamp;
  final bool isFlagged;
  final String? flagReason;
  final bool isSystem; // system messages like "User joined the bracket"

  const ChatMessage({
    required this.id,
    required this.bracketId,
    required this.senderId,
    required this.senderName,
    this.senderLocation,
    required this.message,
    required this.timestamp,
    this.isFlagged = false,
    this.flagReason,
    this.isSystem = false,
  });

  ChatMessage copyWith({
    bool? isFlagged,
    String? flagReason,
  }) {
    return ChatMessage(
      id: id,
      bracketId: bracketId,
      senderId: senderId,
      senderName: senderName,
      senderLocation: senderLocation,
      message: message,
      timestamp: timestamp,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      isSystem: isSystem,
    );
  }
}

/// Represents a tournament chat room.
class ChatRoom {
  final String bracketId;
  final String bracketTitle;
  final String hostName;
  final int participantCount;
  final int unreadCount;
  final ChatMessage? lastMessage;

  const ChatRoom({
    required this.bracketId,
    required this.bracketTitle,
    required this.hostName,
    this.participantCount = 0,
    this.unreadCount = 0,
    this.lastMessage,
  });
}
