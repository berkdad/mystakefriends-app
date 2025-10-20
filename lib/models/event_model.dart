import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrenceFrequency { none, daily, weekly, monthly, yearly }

class RecurrencePattern {
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime? endDate;

  RecurrencePattern({
    required this.frequency,
    this.interval = 1,
    this.endDate,
  });

  factory RecurrencePattern.fromMap(Map<String, dynamic> data) {
    RecurrenceFrequency freq;
    switch (data['frequency']) {
      case 'daily':
        freq = RecurrenceFrequency.daily;
        break;
      case 'weekly':
        freq = RecurrenceFrequency.weekly;
        break;
      case 'monthly':
        freq = RecurrenceFrequency.monthly;
        break;
      case 'yearly':
        freq = RecurrenceFrequency.yearly;
        break;
      default:
        freq = RecurrenceFrequency.none;
    }

    return RecurrencePattern(
      frequency: freq,
      interval: data['interval'] ?? 1,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.toString().split('.').last,
      'interval': interval,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    };
  }
}

class CircleEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String? eventTime;
  final String? location;
  final String? imageUrl;
  final String organizerId;
  final String organizerName;
  final bool isRecurring;
  final String? seriesId;
  final RecurrencePattern? recurrencePattern;
  final bool isBirthday;
  final String? birthdayMemberId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CircleEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.eventTime,
    this.location,
    this.imageUrl,
    required this.organizerId,
    required this.organizerName,
    this.isRecurring = false,
    this.seriesId,
    this.recurrencePattern,
    this.isBirthday = false,
    this.birthdayMemberId,
    required this.createdAt,
    this.updatedAt,
  });

  factory CircleEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CircleEvent(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      eventDate: data['eventDate'] != null
          ? DateTime.parse(data['eventDate'])
          : DateTime.now(),
      eventTime: data['eventTime'],
      location: data['location'],
      imageUrl: data['imageUrl'],
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      isRecurring: data['isRecurring'] ?? false,
      seriesId: data['seriesId'],
      recurrencePattern: data['recurrencePattern'] != null
          ? RecurrencePattern.fromMap(data['recurrencePattern'])
          : null,
      isBirthday: data['isBirthday'] ?? false,
      birthdayMemberId: data['birthdayMemberId'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'eventDate': eventDate.toIso8601String(),
      'eventTime': eventTime,
      'location': location,
      'imageUrl': imageUrl,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'isRecurring': isRecurring,
      'seriesId': seriesId,
      'recurrencePattern': recurrencePattern?.toMap(),
      'isBirthday': isBirthday,
      'birthdayMemberId': birthdayMemberId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DateTime get eventDateTime {
    if (eventTime != null && eventTime!.isNotEmpty) {
      final timeParts = eventTime!.split(':');
      return DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    }
    return eventDate;
  }

  bool get isPast => eventDateTime.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return eventDate.year == now.year &&
        eventDate.month == now.month &&
        eventDate.day == now.day;
  }
}