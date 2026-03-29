import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Meeting status
enum MeetingStatus { upcoming, ongoing, completed, cancelled }

extension MeetingStatusExtension on MeetingStatus {
  String toStr() => toString().split('.').last;

  static MeetingStatus fromString(String? s) {
    switch (s) {
      case 'ongoing':
        return MeetingStatus.ongoing;
      case 'completed':
        return MeetingStatus.completed;
      case 'cancelled':
        return MeetingStatus.cancelled;
      default:
        return MeetingStatus.upcoming;
    }
  }
}

/// Meeting model – maps to `meetings` table
class Meeting extends Equatable {
  final int id;
  final String title;
  final String? titleTe;
  final String? titleHi;
  final String? description;
  final String? descriptionTe;
  final String? descriptionHi;
  final DateTime meetingDate;
  final String meetingTime; // "HH:mm:ss"
  final String venue;
  final String? venueTe;
  final String? venueHi;
  final String? imageUrl;
  final String createdBy;
  final String? creatorName;
  final MeetingStatus status;
  final int displayDays;
  final int interestCount;
  final int notInterestedCount;
  final bool isInterested;
  final bool isNotInterested;
  final bool isSeen;
  final DateTime? createdAt;

  const Meeting({
    required this.id,
    required this.title,
    this.titleTe,
    this.titleHi,
    this.description,
    this.descriptionTe,
    this.descriptionHi,
    required this.meetingDate,
    required this.meetingTime,
    required this.venue,
    this.venueTe,
    this.venueHi,
    this.imageUrl,
    required this.createdBy,
    this.creatorName,
    this.status = MeetingStatus.upcoming,
    this.displayDays = 7,
    this.interestCount = 0,
    this.notInterestedCount = 0,
    this.isInterested = false,
    this.isNotInterested = false,
    this.isSeen = false,
    this.createdAt,
  });

  /// Localized title based on language code
  String localizedTitle(String langCode) {
    if (langCode == 'te' && titleTe != null && titleTe!.isNotEmpty) {
      return titleTe!;
    }
    if (langCode == 'hi' && titleHi != null && titleHi!.isNotEmpty) {
      return titleHi!;
    }
    return title;
  }

  /// Localized description
  String? localizedDescription(String langCode) {
    if (langCode == 'te' &&
        descriptionTe != null &&
        descriptionTe!.isNotEmpty) {
      return descriptionTe!;
    }
    if (langCode == 'hi' &&
        descriptionHi != null &&
        descriptionHi!.isNotEmpty) {
      return descriptionHi!;
    }
    return description;
  }

  /// Localized venue
  String localizedVenue(String langCode) {
    if (langCode == 'te' && venueTe != null && venueTe!.isNotEmpty) {
      return venueTe!;
    }
    if (langCode == 'hi' && venueHi != null && venueHi!.isNotEmpty) {
      return venueHi!;
    }
    return venue;
  }

  /// Formatted date string
  String get formattedDate {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${meetingDate.day} ${months[meetingDate.month - 1]} ${meetingDate.year}';
  }

  /// Formatted time string (12-hour)
  String get formattedTime {
    final parts = meetingTime.split(':');
    if (parts.length < 2) return meetingTime;
    int hour = int.tryParse(parts[0]) ?? 0;
    final min = parts[1];
    final amPm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '$hour:$min $amPm';
  }

  /// Days until the meeting
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return meetingDate.difference(today).inDays;
  }

  /// Whether the meeting is today
  bool get isToday => daysUntil == 0;

  /// Whether the meeting is tomorrow
  bool get isTomorrow => daysUntil == 1;

  Meeting copyWith({
    int? id,
    String? title,
    String? titleTe,
    String? titleHi,
    String? description,
    String? descriptionTe,
    String? descriptionHi,
    DateTime? meetingDate,
    String? meetingTime,
    String? venue,
    String? venueTe,
    String? venueHi,
    String? imageUrl,
    String? createdBy,
    String? creatorName,
    MeetingStatus? status,
    int? displayDays,
    int? interestCount,
    int? notInterestedCount,
    bool? isInterested,
    bool? isNotInterested,
    bool? isSeen,
    DateTime? createdAt,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      titleTe: titleTe ?? this.titleTe,
      titleHi: titleHi ?? this.titleHi,
      description: description ?? this.description,
      descriptionTe: descriptionTe ?? this.descriptionTe,
      descriptionHi: descriptionHi ?? this.descriptionHi,
      meetingDate: meetingDate ?? this.meetingDate,
      meetingTime: meetingTime ?? this.meetingTime,
      venue: venue ?? this.venue,
      venueTe: venueTe ?? this.venueTe,
      venueHi: venueHi ?? this.venueHi,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      status: status ?? this.status,
      displayDays: displayDays ?? this.displayDays,
      interestCount: interestCount ?? this.interestCount,
      notInterestedCount: notInterestedCount ?? this.notInterestedCount,
      isInterested: isInterested ?? this.isInterested,
      isNotInterested: isNotInterested ?? this.isNotInterested,
      isSeen: isSeen ?? this.isSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    }

    return Meeting(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title'] ?? '',
      titleTe: json['title_te'],
      titleHi: json['title_hi'],
      description: json['description'],
      descriptionTe: json['description_te'],
      descriptionHi: json['description_hi'],
      meetingDate: parseDate(json['meeting_date']),
      meetingTime: json['meeting_time'] ?? '00:00:00',
      venue: json['venue'] ?? '',
      venueTe: json['venue_te'],
      venueHi: json['venue_hi'],
      imageUrl: json['image_url'],
      createdBy: json['created_by'] ?? '',
      creatorName: json['creator_name'],
      status: MeetingStatusExtension.fromString(json['status']),
      displayDays: int.tryParse(json['display_days']?.toString() ?? '7') ?? 7,
      interestCount:
          int.tryParse(json['interest_count']?.toString() ?? '0') ?? 0,
      notInterestedCount:
          int.tryParse(json['not_interested_count']?.toString() ?? '0') ?? 0,
      isInterested: json['is_interested'] == true || json['is_interested'] == 1,
      isNotInterested:
          json['is_not_interested'] == true || json['is_not_interested'] == 1,
      isSeen: json['is_seen'] == true || json['is_seen'] == 1,
      createdAt: json['created_at'] is Timestamp
          ? (json['created_at'] as Timestamp).toDate()
          : DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_te': titleTe,
      'title_hi': titleHi,
      'description': description,
      'description_te': descriptionTe,
      'description_hi': descriptionHi,
      'meeting_date':
          '${meetingDate.year}-${meetingDate.month.toString().padLeft(2, '0')}-${meetingDate.day.toString().padLeft(2, '0')}',
      'meeting_time': meetingTime,
      'venue': venue,
      'venue_te': venueTe,
      'venue_hi': venueHi,
      'image_url': imageUrl,
      'created_by': createdBy,
      'status': status.toStr(),
      'display_days': displayDays,
      'interest_count': interestCount,
      'not_interested_count': notInterestedCount,
    };
  }

  @override
  List<Object?> get props => [id];
}
