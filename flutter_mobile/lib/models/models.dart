// ignore_for_file: non_constant_identifier_names

class ConnectedDevice {
  final String id;
  final String name;
  final String type; // 'ble' | 'api'
  final String
      provider; // 'polar' | 'garmin' | 'whoop' | 'apple' | 'amazfit' | 'generic'
  final String status; // 'connected' | 'disconnected' | 'syncing'
  final int? batteryLevel;
  final String? lastSync;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.provider,
    required this.status,
    this.batteryLevel,
    this.lastSync,
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      provider: json['provider'],
      status: json['status'],
      batteryLevel: json['batteryLevel'],
      lastSync: json['lastSync'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'provider': provider,
        'status': status,
        'batteryLevel': batteryLevel,
        'lastSync': lastSync,
      };
}

class UserProfile {
  String firstName;
  String lastName;
  String email;
  String birthDate;
  String role;
  double weight;
  double height;
  int maxHr;
  String unitSystem;
  String language;
  String themeMode;
  String avatarUrl;
  bool notificationsEnabled;
  String? skiClub;
  String? gender;
  String? skillLevel;
  List<ConnectedDevice> connectedDevices;
  Map<String, double>? oneRepMax;
  String? teamId;
  String hrZoneMode;
  List<Map<String, int>>? customHrZones;

  UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.birthDate,
    required this.role,
    required this.weight,
    required this.height,
    required this.maxHr,
    required this.unitSystem,
    required this.language,
    this.themeMode = 'system',
    required this.avatarUrl,
    required this.notificationsEnabled,
    this.skiClub,
    this.gender,
    this.skillLevel,
    required this.connectedDevices,
    this.oneRepMax,
    this.teamId,
    this.hrZoneMode = 'standard',
    this.customHrZones,
  });

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? birthDate,
    String? role,
    double? weight,
    double? height,
    int? maxHr,
    String? unitSystem,
    String? language,
    String? themeMode,
    String? avatarUrl,
    bool? notificationsEnabled,
    String? skiClub,
    String? gender,
    String? skillLevel,
    List<ConnectedDevice>? connectedDevices,
    Map<String, double>? oneRepMax,
    String? teamId,
    String? hrZoneMode,
    List<Map<String, int>>? customHrZones,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      role: role ?? this.role,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      maxHr: maxHr ?? this.maxHr,
      unitSystem: unitSystem ?? this.unitSystem,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      skiClub: skiClub ?? this.skiClub,
      gender: gender ?? this.gender,
      skillLevel: skillLevel ?? this.skillLevel,
      connectedDevices: connectedDevices ?? List.from(this.connectedDevices),
      oneRepMax: oneRepMax ??
          (this.oneRepMax != null ? Map.from(this.oneRepMax!) : null),
      teamId: teamId ?? this.teamId,
      hrZoneMode: hrZoneMode ?? this.hrZoneMode,
      customHrZones: customHrZones ?? this.customHrZones,
    );
  }

  int get age {
    try {
      final birth = DateTime.parse(birthDate);
      final today = DateTime.now();
      int a = today.year - birth.year;
      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        a--;
      }
      return a;
    } catch (e) {
      return 0; // Fallback
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      birthDate: json['birthDate'],
      role: json['role'],
      weight: (json['weight'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      maxHr: json['maxHr'],
      unitSystem: json['unitSystem'],
      language: json['language'],
      themeMode: json['themeMode'] ?? 'system',
      avatarUrl: json['avatarUrl'],
      notificationsEnabled: json['notificationsEnabled'] ?? false,
      skiClub: json['skiClub'],
      gender: json['gender'],
      skillLevel: json['skillLevel'],
      connectedDevices: (json['connectedDevices'] as List<dynamic>?)
              ?.map((e) => ConnectedDevice.fromJson(e))
              .toList() ??
          [],
      oneRepMax: json['oneRepMax'] != null
          ? Map<String, double>.from((json['oneRepMax'] as Map)
              .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
          : null,
      teamId: json['teamId'],
      hrZoneMode: json['hrZoneMode'] ?? 'standard',
      customHrZones: json['customHrZones'] != null
          ? (json['customHrZones'] as List)
              .map((e) => Map<String, int>.from(e as Map))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'birthDate': birthDate,
        'role': role,
        'weight': weight,
        'height': height,
        'maxHr': maxHr,
        'unitSystem': unitSystem,
        'language': language,
        'themeMode': themeMode,
        'avatarUrl': avatarUrl,
        'notificationsEnabled': notificationsEnabled,
        'skiClub': skiClub,
        'gender': gender,
        'skillLevel': skillLevel,
        'connectedDevices': connectedDevices.map((e) => e.toJson()).toList(),
        'oneRepMax': oneRepMax,
        'teamId': teamId,
        'hrZoneMode': hrZoneMode,
        'customHrZones': customHrZones,
      };
}

class BodyMetricLog {
  String id;
  String date;
  String type; // Body, health, score, or coach-defined metric key.
  double value;

  BodyMetricLog({
    required this.id,
    required this.date,
    required this.type,
    required this.value,
  });

  factory BodyMetricLog.fromJson(Map<String, dynamic> json) {
    return BodyMetricLog(
      id: json['id'],
      date: json['date'],
      type: json['type'],
      value: (json['value'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'type': type,
        'value': value,
      };
}

class PRLog {
  String id;
  String exerciseId;
  String date;
  double weight;
  String? note;

  PRLog({
    required this.id,
    required this.exerciseId,
    required this.date,
    required this.weight,
    this.note,
  });

  factory PRLog.fromJson(Map<String, dynamic> json) {
    return PRLog(
      id: json['id'],
      exerciseId: json['exerciseId'],
      date: json['date'],
      weight: (json['weight'] as num).toDouble(),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'date': date,
        'weight': weight,
        'note': note,
      };
}

class JumpLog {
  String id;
  String date;
  String type;
  double value;

  JumpLog({
    required this.id,
    required this.date,
    required this.type,
    required this.value,
  });

  factory JumpLog.fromJson(Map<String, dynamic> json) {
    return JumpLog(
      id: json['id'],
      date: json['date'],
      type: json['type'],
      value: (json['value'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'type': type,
        'value': value,
      };
}

class Team {
  String id;
  String name;
  int members;
  String category;
  String image;
  String inviteCode;
  String? description;
  bool? isPrivate;

  Team({
    required this.id,
    required this.name,
    required this.members,
    required this.category,
    required this.image,
    required this.inviteCode,
    this.description,
    this.isPrivate,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      members: json['members'],
      category: json['category'],
      image: json['image'],
      inviteCode: json['inviteCode'],
      description: json['description'],
      isPrivate: json['isPrivate'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'category': category,
        'image': image,
        'inviteCode': inviteCode,
        'description': description,
        'isPrivate': isPrivate,
      };
}

class CalendarEvent {
  String id;
  String teamId;
  String type;
  String title;
  String date;
  String startTime;
  String endTime;
  String? location;
  String? notes;
  String? sportCategory; // 'ski' | 'dryland'
  String? drylandSpecialty;
  Map<String, dynamic>? technicalDetails;
  List<Map<String, dynamic>>? attendees;
  String status; // 'planned' | 'completed' | 'cancelled'

  CalendarEvent({
    required this.id,
    required this.teamId,
    required this.type,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.location,
    this.notes,
    this.sportCategory,
    this.drylandSpecialty,
    this.technicalDetails,
    this.attendees,
    this.status = 'planned',
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      teamId: json['teamId'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      location: json['location'],
      notes: json['notes'],
      sportCategory: json['sportCategory'],
      drylandSpecialty: json['drylandSpecialty'],
      technicalDetails: json['technicalDetails'],
      attendees: json['attendees'] != null
          ? List<Map<String, dynamic>>.from(json['attendees'])
          : null,
      status: json['status'] ?? 'planned',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'teamId': teamId,
        'type': type,
        'title': title,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'location': location,
        'notes': notes,
        'sportCategory': sportCategory,
        'drylandSpecialty': drylandSpecialty,
        'technicalDetails': technicalDetails,
        'attendees': attendees,
        'status': status,
      };
}

class TrainingSession {
  String id;
  String sportId;
  String date;
  String startTime;
  String endTime;
  String duration;
  int effort;
  String? eventId;
  Map<String, dynamic>? details;

  TrainingSession({
    required this.id,
    required this.sportId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.effort,
    this.eventId,
    this.details,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'],
      sportId: json['sportId'],
      date: json['date'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      duration: json['duration'],
      effort: json['effort'],
      eventId: json['eventId'],
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sportId': sportId,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'duration': duration,
        'effort': effort,
        'eventId': eventId,
        'details': details,
      };
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String timestamp;
  final bool isRead;
  final String? type; // 'training' | 'race' | 'message'

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      timestamp: json['timestamp'],
      isRead: json['isRead'] ?? false,
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': timestamp,
        'isRead': isRead,
        'type': type,
      };
}
