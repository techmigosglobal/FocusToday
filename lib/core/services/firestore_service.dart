import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firestore references and common query helpers.
class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users =>
      db.collection('users');

  static CollectionReference<Map<String, dynamic>> get posts =>
      db.collection('posts');

  static CollectionReference<Map<String, dynamic>> get breakingNews =>
      db.collection('breaking_news');

  static CollectionReference<Map<String, dynamic>> get notifications =>
      db.collection('notifications');

  static CollectionReference<Map<String, dynamic>> get reports =>
      db.collection('reports');

  static CollectionReference<Map<String, dynamic>> get meetings =>
      db.collection('meetings');

  static CollectionReference<Map<String, dynamic>> get partners =>
      db.collection('partners');

  static CollectionReference<Map<String, dynamic>> get reporterApplications =>
      db.collection('reporter_applications');

  static DocumentReference<Map<String, dynamic>> get storageConfig =>
      db.collection('system').doc('storage_config');

  static DocumentReference<Map<String, dynamic>> get focusLandingConfig =>
      db.collection('system').doc('focus_landing_config');

  static CollectionReference<Map<String, dynamic>> get auditLogs =>
      db.collection('audit_logs');

  static CollectionReference<Map<String, dynamic>> get telemetryEvents =>
      db.collection('telemetry_events');

  static CollectionReference<Map<String, dynamic>> postComments(String postId) {
    return posts.doc(postId).collection('comments');
  }

  static CollectionReference<Map<String, dynamic>> commentReplies(
    String postId,
    String commentId,
  ) {
    return postComments(postId).doc(commentId).collection('replies');
  }

  static CollectionReference<Map<String, dynamic>> postInteractions(
    String postId,
  ) {
    return posts.doc(postId).collection('interactions');
  }

  static CollectionReference<Map<String, dynamic>> userBookmarks(
    String userId,
  ) {
    return users.doc(userId).collection('bookmarks');
  }

  /// Named bookmark collections: users/{uid}/bookmark_collections
  static CollectionReference<Map<String, dynamic>> userBookmarkCollections(
    String userId,
  ) => users.doc(userId).collection('bookmark_collections');

  /// Items inside a collection: .../bookmark_collections/{collId}/items
  static CollectionReference<Map<String, dynamic>> userBookmarkCollectionItems(
    String userId,
    String collId,
  ) => users
      .doc(userId)
      .collection('bookmark_collections')
      .doc(collId)
      .collection('items');

  static CollectionReference<Map<String, dynamic>> userMeetingSeen(
    String userId,
  ) {
    return users.doc(userId).collection('meeting_seen');
  }

  static DateTime toDateTime(dynamic raw, {DateTime? fallback}) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
    }
    return fallback ?? DateTime.now();
  }
}
