import 'package:cloud_firestore/cloud_firestore.dart';

class Circle {
  final String id;
  final String name;
  final String? captainId;
  final List<String> memberIds;
  final String stakeId;
  final String wardId;
  final DateTime? createdAt;

  Circle({
    required this.id,
    required this.name,
    this.captainId,
    required this.memberIds,
    required this.stakeId,
    required this.wardId,
    this.createdAt,
  });

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Circle(
      id: doc.id,
      name: data['name'] ?? '',
      captainId: data['captainId'],
      memberIds: List<String>.from(data['memberIds'] ?? []),
      stakeId: data['stakeId'] ?? '',
      wardId: data['wardId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'captainId': captainId,
      'memberIds': memberIds,
      'stakeId': stakeId,
      'wardId': wardId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}