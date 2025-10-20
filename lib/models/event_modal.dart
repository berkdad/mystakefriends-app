import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType { text, image, document }

class ChatMessage {
  final String id;
  final String memberId;
  final String memberName;
  final ChatMessageType type;
  final String? message;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.type,
    this.message,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    required this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    ChatMessageType messageType;
    switch (data['type']) {
      case 'image':
        messageType = ChatMessageType.image;
        break;
      case 'document':
        messageType = ChatMessageType.document;
        break;
      default:
        messageType = ChatMessageType.text;
    }

    return ChatMessage(
      id: doc.id,
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      type: messageType,
      message: data['message'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileSize: data['fileSize'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'type': type.toString().split('.').last,
      'message': message,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isText => type == ChatMessageType.text;
  bool get isImage => type == ChatMessageType.image;
  bool get isDocument => type == ChatMessageType.document;
}