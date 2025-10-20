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
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      preferredName: data['preferredName'],
      aboutMe: data['aboutMe'],
      phone: data['phone'],
      address: data['address'],
      dob: data['dob'],
      maritalStatus: data['maritalStatus'],
      anniversary: data['anniversary'],
      ethnicity: data['ethnicity'],
      spouseName: data['spouseName'],
      numChildren: data['numChildren'],
      childrenNames: data['childrenNames'],
      occupation: data['occupation'],
      employer: data['employer'],
      education: data['education'],
      hobbies: data['hobbies'],
      interests: data['interests'],
      talents: data['talents'],
      favoriteBooks: data['favoriteBooks'],
      favoriteMusic: data['favoriteMusic'],
      spiritualJourney: data['spiritualJourney'],
      favoriteScripture: data['favoriteScripture'],
      testimony: data['testimony'],
      callings: data['callings'],
      personalGoals: data['personalGoals'],
      familyGoals: data['familyGoals'],
      spiritualGoals: data['spiritualGoals'],
      profilePicUrl: data['profilePicUrl'],
      hasLoggedIn: data['hasLoggedIn'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
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
        int.parse(parts[2]), // year
        int.parse(parts[0]), // month
        int.parse(parts[1]), // day
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