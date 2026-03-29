import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import '../../../../core/services/cache_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/meeting.dart';

enum MeetingInterestState { interested, notInterested, none, failed }

class MeetingToggleResult {
  final MeetingInterestState state;

  const MeetingToggleResult(this.state);

  bool get isSuccess => state != MeetingInterestState.failed;
}

class MeetingAdminEngagementData {
  final int interestedCount;
  final int notInterestedCount;
  final int goingCount;
  final int maybeCount;
  final int notGoingCount;
  final List<Map<String, dynamic>> interestedUsers;
  final List<Map<String, dynamic>> goingUsers;
  final List<Map<String, dynamic>> maybeUsers;
  final List<Map<String, dynamic>> notGoingUsers;

  const MeetingAdminEngagementData({
    required this.interestedCount,
    required this.notInterestedCount,
    required this.goingCount,
    required this.maybeCount,
    required this.notGoingCount,
    required this.interestedUsers,
    required this.goingUsers,
    required this.maybeUsers,
    required this.notGoingUsers,
  });

  const MeetingAdminEngagementData.empty()
    : interestedCount = 0,
      notInterestedCount = 0,
      goingCount = 0,
      maybeCount = 0,
      notGoingCount = 0,
      interestedUsers = const [],
      goingUsers = const [],
      maybeUsers = const [],
      notGoingUsers = const [];

  factory MeetingAdminEngagementData.fromGroupedUsers({
    required List<Map<String, dynamic>> interestedUsers,
    required List<Map<String, dynamic>> goingUsers,
    required List<Map<String, dynamic>> maybeUsers,
    required List<Map<String, dynamic>> notGoingUsers,
  }) {
    return MeetingAdminEngagementData(
      interestedCount: interestedUsers.length,
      notInterestedCount: notGoingUsers.length,
      goingCount: goingUsers.length,
      maybeCount: maybeUsers.length,
      notGoingCount: notGoingUsers.length,
      interestedUsers: interestedUsers,
      goingUsers: goingUsers,
      maybeUsers: maybeUsers,
      notGoingUsers: notGoingUsers,
    );
  }
}

class MeetingImageUploadResult {
  final String? url;
  final String? errorMessage;

  const MeetingImageUploadResult({required this.url, this.errorMessage});

  bool get isSuccess => url != null && url!.trim().isNotEmpty;
}

class MeetingRepository {
  Future<List<Meeting>> getUpcomingMeetings(
    String userId, {
    int limit = 10,
  }) async {
    final cacheKey = 'meetings_upcoming_${userId}_$limit';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 20),
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((row) => Meeting.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    try {
      final snapshot = await FirestoreService.meetings.limit(300).get();
      final today = _dateOnly(DateTime.now());
      final meetingRows =
          snapshot.docs
              .map((doc) => MapEntry(_meetingFromDoc(doc), doc.reference))
              .where((row) {
                final meeting = row.key;
                final status = meeting.status;
                if (status != MeetingStatus.upcoming &&
                    status != MeetingStatus.ongoing) {
                  return false;
                }
                return _dateOnly(
                  meeting.meetingDate,
                ).isAfter(today.subtract(const Duration(days: 1)));
              })
              .toList(growable: false)
            ..sort((a, b) {
              final byDate = a.key.meetingDate.compareTo(b.key.meetingDate);
              if (byDate != 0) return byDate;
              return a.key.meetingTime.compareTo(b.key.meetingTime);
            });
      final meetings = meetingRows
          .map((row) => row.key)
          .toList(growable: false);

      if (meetings.isEmpty) {
        await CacheService.set(cacheKey, const []);
        return const [];
      }

      final trimmedRows = meetingRows.take(limit).toList(growable: false);
      final trimmed = trimmedRows.map((row) => row.key).toList(growable: false);
      final meetingRefsById = <int, DocumentReference<Map<String, dynamic>>>{};
      for (final row in trimmedRows) {
        if (row.key.id > 0) {
          meetingRefsById[row.key.id] = row.value;
        }
      }
      final meetingIds = trimmed
          .map((meeting) => meeting.id)
          .where((id) => id > 0)
          .toList(growable: false);
      final result = await Future.wait<Set<int>>([
        _safeLoadInterestedMeetingIds(userId, meetingRefsById),
        _safeLoadSeenMeetingIds(userId, meetingIds),
      ]);
      final interestedIds = result[0];
      final seenIds = result[1];
      final notInterestedIds = await _safeLoadNotInterestedMeetingIds(
        userId,
        meetingRefsById,
      );
      final enriched = trimmed
          .map(
            (meeting) => meeting.copyWith(
              isInterested: interestedIds.contains(meeting.id),
              isNotInterested: notInterestedIds.contains(meeting.id),
              isSeen: seenIds.contains(meeting.id),
            ),
          )
          .toList(growable: false);

      await CacheService.set(
        cacheKey,
        enriched.map(_meetingToCacheRow).toList(growable: false),
      );
      return enriched;
    } catch (e) {
      debugPrint('[MeetingRepo] getUpcomingMeetings error: $e');
      return [];
    }
  }

  Future<List<Meeting>> getUnseenMeetings(String userId) async {
    final all = await getUpcomingMeetings(userId, limit: 20);
    return all.where((m) => !m.isSeen).toList(growable: false);
  }

  Future<({List<Meeting> meetings, int total})> getAllMeetings({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final cacheKey =
        'meetings_admin_page_${page}_limit_${limit}_status_${status ?? ''}';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 20),
    );
    if (cached is Map) {
      final rawMeetings = List<Map<String, dynamic>>.from(
        (cached['meetings'] as List? ?? const []),
      );
      return (
        meetings: rawMeetings
            .map((row) => Meeting.fromJson(row))
            .toList(growable: false),
        total: (cached['total'] as num?)?.toInt() ?? rawMeetings.length,
      );
    }

    try {
      final snap = await FirestoreService.meetings.limit(500).get();
      final normalizedStatus = _normalizeStatus(status);
      final all =
          snap.docs
              .map(_meetingFromDoc)
              .where(
                (meeting) =>
                    normalizedStatus == null ||
                    meeting.status.toStr() == normalizedStatus,
              )
              .toList(growable: false)
            ..sort((a, b) {
              final byDate = b.meetingDate.compareTo(a.meetingDate);
              if (byDate != 0) return byDate;
              return b.meetingTime.compareTo(a.meetingTime);
            });
      final start = ((page - 1) * limit).clamp(0, all.length);
      final end = (start + limit).clamp(0, all.length);
      final meetings = all.sublist(start, end);

      await CacheService.set(cacheKey, {
        'meetings': meetings.map(_meetingToCacheRow).toList(growable: false),
        'total': all.length,
      });
      return (meetings: meetings, total: all.length);
    } catch (e) {
      debugPrint('[MeetingRepo] getAllMeetings error: $e');
      return (meetings: <Meeting>[], total: 0);
    }
  }

  Future<Meeting?> getMeetingById(int id) async {
    try {
      final snap = await FirestoreService.meetings
          .where('id', isEqualTo: id)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return Meeting.fromJson(snap.docs.first.data());
    } catch (e) {
      debugPrint('[MeetingRepo] getMeetingById error: $e');
      return null;
    }
  }

  Future<int?> createMeeting(Map<String, dynamic> data) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch;
      final payload = _normalizeMeetingPayload(data)
        ..['id'] = id
        ..['interest_count'] = 0
        ..['not_interested_count'] = 0
        ..['created_at'] = FieldValue.serverTimestamp();
      await FirestoreService.meetings.doc(id.toString()).set({...payload});
      await _invalidateMeetingCaches();
      return id;
    } catch (e) {
      debugPrint('[MeetingRepo] createMeeting error: $e');
      return null;
    }
  }

  Future<bool> updateMeeting(Map<String, dynamic> data) async {
    try {
      final id = data['id'];
      if (id == null) return false;
      final doc = await _docForMeetingId(int.tryParse('$id') ?? 0);
      if (doc == null) return false;

      final payload = Map<String, dynamic>.from(data)
        ..remove('id')
        ..removeWhere((_, value) => value == null)
        ..['updated_at'] = FieldValue.serverTimestamp();
      await doc.reference.set(
        _normalizeMeetingPayload(payload),
        SetOptions(merge: true),
      );
      await _invalidateMeetingCaches();
      return true;
    } catch (e) {
      debugPrint('[MeetingRepo] updateMeeting error: $e');
      return false;
    }
  }

  Future<bool> deleteMeeting(int id) async {
    try {
      final doc = await _docForMeetingId(id);
      if (doc == null) return false;
      await doc.reference.delete();
      await _invalidateMeetingCaches();
      return true;
    } catch (e) {
      debugPrint('[MeetingRepo] deleteMeeting error: $e');
      return false;
    }
  }

  Future<MeetingImageUploadResult> uploadMeetingImage({
    required String filePath,
    required String userId,
    int? meetingId,
  }) async {
    try {
      final authUser = fa.FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        return const MeetingImageUploadResult(
          url: null,
          errorMessage: 'You are signed out. Please login again and retry.',
        );
      }
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[MeetingRepo] uploadMeetingImage: file does not exist');
        return const MeetingImageUploadResult(
          url: null,
          errorMessage: 'Selected image file was not found.',
        );
      }
      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        debugPrint('[MeetingRepo] uploadMeetingImage: file exceeds 10MB limit');
        return const MeetingImageUploadResult(
          url: null,
          errorMessage: 'Image must be smaller than 10MB.',
        );
      }
      final imageMeta = _resolveImageMeta(file.path);
      final ownerId = authUser.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final path =
          'meetings/$ownerId/${meetingId ?? timestamp}_$timestamp.${imageMeta.extension}';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putFile(
        file,
        SettableMetadata(contentType: imageMeta.contentType),
      );
      final downloadUrl = await ref.getDownloadURL();
      return MeetingImageUploadResult(url: downloadUrl);
    } on FirebaseException catch (e) {
      // Fallback for MIME/metadata inconsistencies on certain gallery providers.
      if (e.code == 'permission-denied' || e.code == 'invalid-argument') {
        try {
          final ownerId = fa.FirebaseAuth.instance.currentUser?.uid ?? userId;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fallbackPath =
              'meetings/$ownerId/${meetingId ?? timestamp}_$timestamp.jpg';
          final fallbackRef = FirebaseStorage.instance.ref(fallbackPath);
          await fallbackRef.putFile(
            File(filePath),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final fallbackUrl = await fallbackRef.getDownloadURL();
          return MeetingImageUploadResult(url: fallbackUrl);
        } catch (_) {}
      }

      final message = switch (e.code) {
        'permission-denied' =>
          'Upload permission denied. Please re-login and try again.',
        'unauthenticated' =>
          'You are signed out. Please login again and retry.',
        'network-request-failed' =>
          'Network issue while uploading image. Please try again.',
        'invalid-argument' =>
          'Unsupported image metadata. Please retry with a different image.',
        'canceled' => 'Upload was canceled.',
        _ => 'Image upload failed (${e.code}).',
      };
      debugPrint(
        '[MeetingRepo] uploadMeetingImage firebase error: ${e.code} ${e.message}',
      );
      return MeetingImageUploadResult(url: null, errorMessage: message);
    } catch (e) {
      debugPrint('[MeetingRepo] uploadMeetingImage error: $e');
      return const MeetingImageUploadResult(
        url: null,
        errorMessage: 'Image upload failed. Please try again.',
      );
    }
  }

  Future<MeetingToggleResult> toggleInterest(
    int meetingId,
    String userId,
  ) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) {
        return const MeetingToggleResult(MeetingInterestState.failed);
      }

      final interestRef = doc.reference.collection('interests').doc(userId);
      var nextState = MeetingInterestState.none;
      await FirestoreService.db.runTransaction((tx) async {
        final interest = await tx.get(interestRef);
        final interested = interest.exists;
        final rsvpRef = doc.reference.collection('rsvps').doc(userId);
        final rsvp = await tx.get(rsvpRef);
        final notInterested =
            (rsvp.data()?['response']?.toString() ?? '') == 'not_going';

        if (interested) {
          tx.delete(interestRef);
          nextState = MeetingInterestState.none;
        } else {
          tx.set(interestRef, {
            'user_id': userId,
            'created_at': FieldValue.serverTimestamp(),
          });
          if (notInterested) {
            tx.delete(rsvpRef);
          }
          nextState = MeetingInterestState.interested;
        }
      });
      await _invalidateMeetingCaches(userId: userId);
      return MeetingToggleResult(nextState);
    } catch (e) {
      debugPrint('[MeetingRepo] toggleInterest error: $e');
      return const MeetingToggleResult(MeetingInterestState.failed);
    }
  }

  Future<MeetingToggleResult> toggleNotInterested(
    int meetingId,
    String userId,
  ) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) {
        return const MeetingToggleResult(MeetingInterestState.failed);
      }

      final rsvpRef = doc.reference.collection('rsvps').doc(userId);
      final interestRef = doc.reference.collection('interests').doc(userId);
      var nextState = MeetingInterestState.none;
      await FirestoreService.db.runTransaction((tx) async {
        final rsvp = await tx.get(rsvpRef);
        final interest = await tx.get(interestRef);
        final alreadyNotInterested =
            (rsvp.data()?['response']?.toString() ?? '') == 'not_going';

        if (alreadyNotInterested) {
          tx.delete(rsvpRef);
          nextState = MeetingInterestState.none;
        } else {
          tx.set(rsvpRef, {
            'user_id': userId,
            'response': 'not_going',
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          if (interest.exists) {
            tx.delete(interestRef);
          }
          nextState = MeetingInterestState.notInterested;
        }
      });
      await _invalidateMeetingCaches(userId: userId);
      return MeetingToggleResult(nextState);
    } catch (e) {
      debugPrint('[MeetingRepo] toggleNotInterested error: $e');
      return const MeetingToggleResult(MeetingInterestState.failed);
    }
  }

  Future<bool> markAsSeen(List<int> meetingIds, String userId) async {
    try {
      final batch = FirestoreService.db.batch();
      for (final id in meetingIds) {
        final ref = FirestoreService.userMeetingSeen(userId).doc(id.toString());
        batch.set(ref, {
          'seen': true,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      await _invalidateMeetingCaches(userId: userId);
      return true;
    } catch (e) {
      debugPrint('[MeetingRepo] markAsSeen error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getInterestedUsers(int meetingId) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) return [];
      final snapshot = await doc.reference
          .collection('interests')
          .orderBy('created_at', descending: true)
          .limit(300)
          .get();
      if (snapshot.docs.isEmpty) return [];

      final actorIds = snapshot.docs
          .map((d) {
            final uid = (d.data()['user_id'] ?? '').toString().trim();
            return uid.isNotEmpty ? uid : d.id;
          })
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final usersById = <String, Map<String, dynamic>>{};
      for (final chunk in _chunkList(actorIds, 30)) {
        final usersSnap = await FirestoreService.users
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final userDoc in usersSnap.docs) {
          usersById[userDoc.id] = userDoc.data();
        }
      }

      return snapshot.docs
          .map((d) {
            final actorId =
                (d.data()['user_id'] ?? '').toString().trim().isNotEmpty
                ? d.data()['user_id'].toString().trim()
                : d.id;
            final user = usersById[actorId] ?? const <String, dynamic>{};
            final role = _normalizeUserRole(user['role']);
            return {
              'id': actorId,
              'user_id': actorId,
              'display_name': user['display_name'] ?? 'Unknown',
              'phone_number': user['phone_number'] ?? '',
              'role': role,
              'interested_at': d.data()['created_at'],
            };
          })
          .where((row) => _isReporterOrPublicRole(row['role']))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[MeetingRepo] getInterestedUsers error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRsvpUsers(
    int meetingId, {
    String? response,
  }) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) return [];

      Query<Map<String, dynamic>> query = doc.reference
          .collection('rsvps')
          .orderBy('updated_at', descending: true)
          .limit(500);
      if (response != null && response.isNotEmpty) {
        query = query.where('response', isEqualTo: response);
      }
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return [];

      final actorIds = snapshot.docs
          .map((d) {
            final uid = (d.data()['user_id'] ?? '').toString().trim();
            return uid.isNotEmpty ? uid : d.id;
          })
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final usersById = <String, Map<String, dynamic>>{};
      for (final chunk in _chunkList(actorIds, 30)) {
        final usersSnap = await FirestoreService.users
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final userDoc in usersSnap.docs) {
          usersById[userDoc.id] = userDoc.data();
        }
      }

      return snapshot.docs
          .map((d) {
            final actorId =
                (d.data()['user_id'] ?? '').toString().trim().isNotEmpty
                ? d.data()['user_id'].toString().trim()
                : d.id;
            final user = usersById[actorId] ?? const <String, dynamic>{};
            final role = _normalizeUserRole(user['role']);
            return {
              'id': actorId,
              'user_id': actorId,
              'display_name': user['display_name'] ?? 'Unknown',
              'phone_number': user['phone_number'] ?? '',
              'role': role,
              'response': d.data()['response'],
              'attendee_name': d.data()['attendee_name'],
              'attendee_phone': d.data()['attendee_phone'],
              'attendee_details': d.data()['attendee_details'],
              'updated_at': d.data()['updated_at'],
            };
          })
          .where((row) => _isReporterOrPublicRole(row['role']))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[MeetingRepo] getRsvpUsers error: $e');
      return [];
    }
  }

  // ─── RSVP Methods (GAP-010) ────────────────────────────────────────────────

  /// Submit or update RSVP: response = 'going' | 'maybe' | 'not_going'
  Future<bool> submitRsvp(
    int meetingId,
    String userId,
    String response, {
    String? attendeeName,
    String? attendeePhone,
    String? attendeeDetails,
  }) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) return false;
      final payload = <String, dynamic>{
        'user_id': userId,
        'response': response,
        'updated_at': FieldValue.serverTimestamp(),
      };
      final name = attendeeName?.trim() ?? '';
      final phone = attendeePhone?.trim() ?? '';
      final details = attendeeDetails?.trim() ?? '';
      if (name.isNotEmpty) payload['attendee_name'] = name;
      if (phone.isNotEmpty) payload['attendee_phone'] = phone;
      if (details.isNotEmpty) payload['attendee_details'] = details;

      await doc.reference
          .collection('rsvps')
          .doc(userId)
          .set(payload, SetOptions(merge: true));
      await _invalidateMeetingCaches(userId: userId);
      return true;
    } catch (e) {
      debugPrint('[MeetingRepo] submitRsvp error: $e');
      return false;
    }
  }

  /// Get current RSVP response for a user; null if not RSVPed.
  Future<String?> getUserRsvp(int meetingId, String userId) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) return null;
      final rsvpDoc = await doc.reference.collection('rsvps').doc(userId).get();
      if (!rsvpDoc.exists) return null;
      return rsvpDoc.data()?['response']?.toString();
    } catch (e) {
      debugPrint('[MeetingRepo] getUserRsvp error: $e');
      return null;
    }
  }

  /// Returns RSVP payload for a user (response + optional attendee fields).
  Future<Map<String, dynamic>?> getUserRsvpPayload(
    int meetingId,
    String userId,
  ) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) return null;
      final rsvpDoc = await doc.reference.collection('rsvps').doc(userId).get();
      if (!rsvpDoc.exists) return null;
      return rsvpDoc.data();
    } catch (e) {
      debugPrint('[MeetingRepo] getUserRsvpPayload error: $e');
      return null;
    }
  }

  /// Get aggregate RSVP counts: {going, maybe, not_going}
  Future<Map<String, int>> getRsvpCounts(int meetingId) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) return {};
      final snap = await doc.reference.collection('rsvps').limit(500).get();
      final counts = <String, int>{'going': 0, 'maybe': 0, 'not_going': 0};
      for (final d in snap.docs) {
        final r = d.data()['response']?.toString() ?? '';
        if (counts.containsKey(r)) counts[r] = (counts[r] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('[MeetingRepo] getRsvpCounts error: $e');
      return {};
    }
  }

  Future<MeetingAdminEngagementData> getAdminEngagementDashboard(
    int meetingId,
  ) async {
    try {
      final doc = await _docForMeetingId(meetingId);
      if (doc == null) return const MeetingAdminEngagementData.empty();

      final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
        doc.reference
            .collection('interests')
            .orderBy('created_at', descending: true)
            .limit(500)
            .get(),
        doc.reference
            .collection('rsvps')
            .orderBy('updated_at', descending: true)
            .limit(500)
            .get(),
      ]);
      final interestsSnap = results[0];
      final rsvpsSnap = results[1];

      final actorIds = <String>{};
      for (final d in interestsSnap.docs) {
        final uid = (d.data()['user_id'] ?? d.id).toString().trim();
        if (uid.isNotEmpty) actorIds.add(uid);
      }
      for (final d in rsvpsSnap.docs) {
        final uid = (d.data()['user_id'] ?? d.id).toString().trim();
        if (uid.isNotEmpty) actorIds.add(uid);
      }
      final usersById = await _loadUsersById(actorIds.toList(growable: false));

      final interestedUsers = interestsSnap.docs
          .map((d) {
            final actorId = (d.data()['user_id'] ?? d.id).toString().trim();
            final user = usersById[actorId] ?? const <String, dynamic>{};
            final role = _normalizeUserRole(user['role']);
            return {
              'id': actorId,
              'user_id': actorId,
              'display_name': user['display_name'] ?? 'Unknown',
              'phone_number': user['phone_number'] ?? '',
              'role': role,
              'interested_at': d.data()['created_at'],
            };
          })
          .where((row) => _isReporterOrPublicRole(row['role']))
          .toList(growable: false);

      final goingUsers = <Map<String, dynamic>>[];
      final maybeUsers = <Map<String, dynamic>>[];
      final notGoingUsers = <Map<String, dynamic>>[];
      for (final d in rsvpsSnap.docs) {
        final actorId = (d.data()['user_id'] ?? d.id).toString().trim();
        final user = usersById[actorId] ?? const <String, dynamic>{};
        final role = _normalizeUserRole(user['role']);
        if (!_isReporterOrPublicRole(role)) continue;
        final row = <String, dynamic>{
          'id': actorId,
          'user_id': actorId,
          'display_name': user['display_name'] ?? 'Unknown',
          'phone_number': user['phone_number'] ?? '',
          'role': role,
          'response': d.data()['response'],
          'attendee_name': d.data()['attendee_name'],
          'attendee_phone': d.data()['attendee_phone'],
          'attendee_details': d.data()['attendee_details'],
          'updated_at': d.data()['updated_at'],
        };
        final response = (d.data()['response'] ?? '').toString();
        if (response == 'going') {
          goingUsers.add(row);
        } else if (response == 'maybe') {
          maybeUsers.add(row);
        } else if (response == 'not_going') {
          notGoingUsers.add(row);
        }
      }

      return MeetingAdminEngagementData.fromGroupedUsers(
        interestedUsers: interestedUsers,
        goingUsers: goingUsers,
        maybeUsers: maybeUsers,
        notGoingUsers: notGoingUsers,
      );
    } catch (e) {
      debugPrint('[MeetingRepo] getAdminEngagementDashboard error: $e');
      return const MeetingAdminEngagementData.empty();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────

  Future<DocumentSnapshot<Map<String, dynamic>>?> _docForMeetingId(
    int id,
  ) async {
    if (id <= 0) return null;

    final byField = await FirestoreService.meetings
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (byField.docs.isNotEmpty) {
      return byField.docs.first;
    }

    // Fallback for legacy meetings where numeric id is stored only in doc id.
    final byDocId = await FirestoreService.meetings.doc(id.toString()).get();
    if (byDocId.exists) {
      return byDocId;
    }
    return null;
  }

  Future<Set<int>> _loadInterestedMeetingIds(
    String userId,
    Map<int, DocumentReference<Map<String, dynamic>>> meetingRefsById,
  ) async {
    if (meetingRefsById.isEmpty) return <int>{};
    final checks = await Future.wait(
      meetingRefsById.entries.map((entry) async {
        final interestedDoc = await entry.value
            .collection('interests')
            .doc(userId)
            .get();
        return interestedDoc.exists ? entry.key : null;
      }),
    );
    return checks.whereType<int>().toSet();
  }

  Future<Set<int>> _safeLoadInterestedMeetingIds(
    String userId,
    Map<int, DocumentReference<Map<String, dynamic>>> meetingRefsById,
  ) async {
    try {
      return await _loadInterestedMeetingIds(userId, meetingRefsById);
    } catch (e) {
      debugPrint('[MeetingRepo] optional interested lookup failed: $e');
      return <int>{};
    }
  }

  Future<Set<int>> _loadSeenMeetingIds(
    String userId,
    List<int> meetingIds,
  ) async {
    if (meetingIds.isEmpty) return <int>{};

    final snapshots = await Future.wait(
      _chunkList(meetingIds.map((id) => id.toString()).toList(), 30).map(
        (chunk) => FirestoreService.userMeetingSeen(
          userId,
        ).where(FieldPath.documentId, whereIn: chunk).get(),
      ),
    );
    final seenIds = <int>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final meetingId = int.tryParse(doc.id);
        if (meetingId != null) {
          seenIds.add(meetingId);
        }
      }
    }
    return seenIds;
  }

  Future<Set<int>> _safeLoadSeenMeetingIds(
    String userId,
    List<int> meetingIds,
  ) async {
    try {
      return await _loadSeenMeetingIds(userId, meetingIds);
    } catch (e) {
      debugPrint('[MeetingRepo] optional seen lookup failed: $e');
      return <int>{};
    }
  }

  Future<Set<int>> _loadNotInterestedMeetingIds(
    String userId,
    Map<int, DocumentReference<Map<String, dynamic>>> meetingRefsById,
  ) async {
    if (meetingRefsById.isEmpty) return <int>{};
    final checks = await Future.wait(
      meetingRefsById.entries.map((entry) async {
        final rsvpDoc = await entry.value.collection('rsvps').doc(userId).get();
        return (rsvpDoc.data()?['response']?.toString() ?? '') == 'not_going'
            ? entry.key
            : null;
      }),
    );
    return checks.whereType<int>().toSet();
  }

  Future<Set<int>> _safeLoadNotInterestedMeetingIds(
    String userId,
    Map<int, DocumentReference<Map<String, dynamic>>> meetingRefsById,
  ) async {
    try {
      return await _loadNotInterestedMeetingIds(userId, meetingRefsById);
    } catch (e) {
      debugPrint('[MeetingRepo] optional not-interested lookup failed: $e');
      return <int>{};
    }
  }

  Map<String, dynamic> _meetingToCacheRow(Meeting meeting) {
    return {
      ...meeting.toJson(),
      'creator_name': meeting.creatorName,
      'interest_count': meeting.interestCount,
      'not_interested_count': meeting.notInterestedCount,
      'is_interested': meeting.isInterested,
      'is_not_interested': meeting.isNotInterested,
      'is_seen': meeting.isSeen,
      'created_at': meeting.createdAt?.toIso8601String(),
    };
  }

  List<List<T>> _chunkList<T>(List<T> input, int chunkSize) {
    if (input.isEmpty) return const [];

    final chunks = <List<T>>[];
    for (int index = 0; index < input.length; index += chunkSize) {
      final end = (index + chunkSize).clamp(0, input.length);
      chunks.add(input.sublist(index, end));
    }
    return chunks;
  }

  Future<Map<String, Map<String, dynamic>>> _loadUsersById(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const <String, Map<String, dynamic>>{};
    final usersById = <String, Map<String, dynamic>>{};
    for (final chunk in _chunkList(
      userIds.toSet().toList(growable: false),
      30,
    )) {
      final usersSnap = await FirestoreService.users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final userDoc in usersSnap.docs) {
        usersById[userDoc.id] = userDoc.data();
      }
    }
    return usersById;
  }

  Future<void> _invalidateMeetingCaches({String? userId}) async {
    await CacheService.invalidatePrefix('meetings_');
    if (userId != null && userId.isNotEmpty) {
      await CacheService.invalidatePrefix('meetings_upcoming_${userId}_');
    }
  }

  Meeting _meetingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = Map<String, dynamic>.from(doc.data());
    final normalized = _normalizeMeetingPayload(raw);
    normalized['id'] ??= int.tryParse(doc.id) ?? 0;
    normalized['status'] = _normalizeStatus(normalized['status']) ?? 'upcoming';
    return Meeting.fromJson(normalized);
  }

  Map<String, dynamic> _normalizeMeetingPayload(Map<String, dynamic> input) {
    final payload = Map<String, dynamic>.from(input);

    payload['meeting_date'] = _normalizeMeetingDate(
      payload['meeting_date'] ?? payload['date'] ?? payload['meetingDate'],
    );
    payload['meeting_time'] = _normalizeMeetingTime(
      payload['meeting_time'] ?? payload['time'] ?? payload['meetingTime'],
    );
    payload['status'] = _normalizeStatus(payload['status']) ?? 'upcoming';

    payload['created_by'] ??= payload['createdBy'] ?? '';
    payload['creator_name'] ??= payload['creatorName'];
    payload['image_url'] ??= payload['imageUrl'];
    payload['interest_count'] ??= payload['interested_count'] ?? 0;
    payload['not_interested_count'] ??= payload['notInterestedCount'] ?? 0;
    payload['title_te'] = _fallbackLocalizedValue(
      payload['title_te'],
      payload['title'],
    );
    payload['title_hi'] = _fallbackLocalizedValue(
      payload['title_hi'],
      payload['title'],
    );
    payload['description_te'] = _fallbackLocalizedValue(
      payload['description_te'],
      payload['description'],
    );
    payload['description_hi'] = _fallbackLocalizedValue(
      payload['description_hi'],
      payload['description'],
    );
    payload['venue_te'] = _fallbackLocalizedValue(
      payload['venue_te'],
      payload['venue'],
    );
    payload['venue_hi'] = _fallbackLocalizedValue(
      payload['venue_hi'],
      payload['venue'],
    );
    if (payload['image_url'] is String &&
        (payload['image_url'] as String).trim().isEmpty) {
      payload['image_url'] = null;
    }

    return payload;
  }

  String _normalizeMeetingDate(dynamic raw) {
    final parsed = FirestoreService.toDateTime(raw);
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  String _normalizeMeetingTime(dynamic raw) {
    if (raw == null) return '00:00:00';
    final value = raw.toString().trim();
    if (value.isEmpty) return '00:00:00';
    if (value.contains(':')) {
      final parts = value.split(':');
      final hh = (int.tryParse(parts[0]) ?? 0).clamp(0, 23);
      final mm = parts.length > 1
          ? (int.tryParse(parts[1]) ?? 0).clamp(0, 59)
          : 0;
      final ss = parts.length > 2
          ? (int.tryParse(parts[2]) ?? 0).clamp(0, 59)
          : 0;
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '00:00:00';
  }

  String? _fallbackLocalizedValue(dynamic currentValue, dynamic englishValue) {
    final current = (currentValue ?? '').toString().trim();
    if (current.isNotEmpty) return current;
    final english = (englishValue ?? '').toString().trim();
    return english.isEmpty ? null : english;
  }

  String? _normalizeStatus(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'upcoming':
        return 'upcoming';
      case 'ongoing':
        return 'ongoing';
      case 'completed':
        return 'completed';
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default:
        return null;
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isReporterOrPublicRole(dynamic role) {
    final normalized = _normalizeUserRole(role);
    return normalized == 'reporter' || normalized == 'public_user';
  }

  String _normalizeUserRole(dynamic role) {
    final raw = (role ?? 'public_user').toString().trim().toLowerCase();
    final compact = raw.replaceAll('_', '');
    switch (compact) {
      case 'reporter':
        return 'reporter';
      case 'publicuser':
        return 'public_user';
      case 'superadmin':
        return 'super_admin';
      case 'admin':
        return 'admin';
      default:
        return 'public_user';
    }
  }

  ({String extension, String contentType}) _resolveImageMeta(String filePath) {
    final rawExt = filePath.contains('.')
        ? filePath.split('.').last.toLowerCase().trim()
        : '';
    switch (rawExt) {
      case 'jpg':
      case 'jpeg':
        return (extension: 'jpg', contentType: 'image/jpeg');
      case 'png':
        return (extension: 'png', contentType: 'image/png');
      case 'webp':
        return (extension: 'webp', contentType: 'image/webp');
      case 'heic':
        return (extension: 'heic', contentType: 'image/heic');
      case 'heif':
        return (extension: 'heif', contentType: 'image/heif');
      case 'gif':
        return (extension: 'gif', contentType: 'image/gif');
      case 'bmp':
        return (extension: 'bmp', contentType: 'image/bmp');
      default:
        // Fallback helps with extensionless picker cache paths.
        return (extension: 'jpg', contentType: 'image/jpeg');
    }
  }
}
