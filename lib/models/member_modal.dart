import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id;
  final String fullName;
  final String email;
  final String? preferredName;
  final String? aboutMe;
  final String? phone;
  final String? address;
  final String? dob;
  final String? maritalStatus;
  final String? anniversary;
  final String? ethnicity;
  final String? spouseName;
  final String? numChildren;
  final String? childrenNames;
  final String? occupation;
  final String? employer;
  final String? education;
  final String? hobbies;
  final String? interests;
  final String? talents;
  final String? favoriteBooks;
  final String? favoriteMusic;
  final String? spiritualJourney;
  final String? favoriteScripture;
  final String? testimony;
  final String? callings;
  final String? personalGoals;
  final String? familyGoals;
  final String? spiritualGoals;
  final String? profilePicUrl;
  final bool hasLoggedIn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Member({
    required this.id,
    required this.fullName,
    required this.email,
    this.preferredName,
    this.aboutMe,
    this.phone,
    this.address,
    this.dob,
    this.maritalStatus,
    this.anniversary,
    this.ethnicity,
    this.spouseName,
    this.numChildren,
    this.childrenNames,
    this.occupation,
    this.employer,
    this.education,
    this.hobbies,
    this.interests,
    this.talents,
    this.favoriteBooks,
    this.favoriteMusic,
    this.spiritualJourney,
    this.favoriteScripture,
    this.testimony,
    this.callings,
    this.personalGoals,
    this.familyGoals,
    this.spiritualGoals,
    this.profilePicUrl,
    this.hasLoggedIn = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Member.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Member(
      id: doc.id,
      fullName: _safeString(data['fullName']) ?? '',
      email: _safeString(data['email']) ?? '',
      preferredName: _safeString(data['preferredName']),
      aboutMe: _safeString(data['aboutMe']),
      phone: _safeString(data['phone']),
      address: _safeString(data['address']),
      dob: _safeString(data['dob']),
      maritalStatus: _safeString(data['maritalStatus']),
      anniversary: _safeString(data['anniversary']),
      ethnicity: _safeString(data['ethnicity']),
      spouseName: _safeString(data['spouseName']),
      numChildren: _safeString(data['numChildren']),
      childrenNames: _safeString(data['childrenNames']),
      occupation: _safeString(data['occupation']),
      employer: _safeString(data['employer']),
      education: _safeString(data['education']),
      hobbies: _safeString(data['hobbies']),
      interests: _safeString(data['interests']),
      talents: _safeString(data['talents']),
      favoriteBooks: _safeString(data['favoriteBooks']),
      favoriteMusic: _safeString(data['favoriteMusic']),
      spiritualJourney: _safeString(data['spiritualJourney']),
      favoriteScripture: _safeString(data['favoriteScripture']),
      testimony: _safeString(data['testimony']),
      callings: _safeString(data['callings']),
      personalGoals: _safeString(data['personalGoals']),
      familyGoals: _safeString(data['familyGoals']),
      spiritualGoals: _safeString(data['spiritualGoals']),
      profilePicUrl: _safeString(data['profilePicUrl']),
      hasLoggedIn: data['hasLoggedIn'] ?? false,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  static String? _safeString(dynamic value) {
    if (value == null) return null;

    try {
      if (value is String) {
        return value.isEmpty ? null : value;
      }

      if (value is List) {
        if (value.isEmpty) return null;
        return value.join(', ');
      }

      return value.toString();
    } catch (e) {
      print('Error parsing string value: $e');
      return null;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is String) {
        return DateTime.parse(value);
      }

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      return null;
    } catch (e) {
      print('Error parsing datetime: $e');
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'email': email,
      'preferredName': preferredName,
      'aboutMe': aboutMe,
      'phone': phone,
      'address': address,
      'dob': dob,
      'maritalStatus': maritalStatus,
      'anniversary': anniversary,
      'ethnicity': ethnicity,
      'spouseName': spouseName,
      'numChildren': numChildren,
      'childrenNames': childrenNames,
      'occupation': occupation,
      'employer': employer,
      'education': education,
      'hobbies': hobbies,
      'interests': interests,
      'talents': talents,
      'favoriteBooks': favoriteBooks,
      'favoriteMusic': favoriteMusic,
      'spiritualJourney': spiritualJourney,
      'favoriteScripture': favoriteScripture,
      'testimony': testimony,
      'callings': callings,
      'personalGoals': personalGoals,
      'familyGoals': familyGoals,
      'spiritualGoals': spiritualGoals,
      'profilePicUrl': profilePicUrl,
      'hasLoggedIn': hasLoggedIn,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get displayName => preferredName ?? fullName;

  int? get age {
    if (dob == null) return null;
    try {
      final parts = dob!.split('/');
      if (parts.length != 3) return null;
      final birthDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return null;
    }
  }

  bool get isBirthdayToday {
    if (dob == null) return false;
    try {
      final parts = dob!.split('/');
      if (parts.length != 3) return false;
      final today = DateTime.now();
      return int.parse(parts[0]) == today.month &&
          int.parse(parts[1]) == today.day;
    } catch (e) {
      return false;
    }
  }

  Member copyWith({
    String? preferredName,
    String? aboutMe,
    String? phone,
    String? address,
    String? dob,
    String? maritalStatus,
    String? anniversary,
    String? ethnicity,
    String? spouseName,
    String? numChildren,
    String? childrenNames,
    String? occupation,
    String? employer,
    String? education,
    String? hobbies,
    String? interests,
    String? talents,
    String? favoriteBooks,
    String? favoriteMusic,
    String? spiritualJourney,
    String? favoriteScripture,
    String? testimony,
    String? callings,
    String? personalGoals,
    String? familyGoals,
    String? spiritualGoals,
    String? profilePicUrl,
  }) {
    return Member(
      id: id,
      fullName: fullName,
      email: email,
      preferredName: preferredName ?? this.preferredName,
      aboutMe: aboutMe ?? this.aboutMe,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      dob: dob ?? this.dob,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      anniversary: anniversary ?? this.anniversary,
      ethnicity: ethnicity ?? this.ethnicity,
      spouseName: spouseName ?? this.spouseName,
      numChildren: numChildren ?? this.numChildren,
      childrenNames: childrenNames ?? this.childrenNames,
      occupation: occupation ?? this.occupation,
      employer: employer ?? this.employer,
      education: education ?? this.education,
      hobbies: hobbies ?? this.hobbies,
      interests: interests ?? this.interests,
      talents: talents ?? this.talents,
      favoriteBooks: favoriteBooks ?? this.favoriteBooks,
      favoriteMusic: favoriteMusic ?? this.favoriteMusic,
      spiritualJourney: spiritualJourney ?? this.spiritualJourney,
      favoriteScripture: favoriteScripture ?? this.favoriteScripture,
      testimony: testimony ?? this.testimony,
      callings: callings ?? this.callings,
      personalGoals: personalGoals ?? this.personalGoals,
      familyGoals: familyGoals ?? this.familyGoals,
      spiritualGoals: spiritualGoals ?? this.spiritualGoals,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      hasLoggedIn: hasLoggedIn,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}