import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/firestore_service.dart';

class ReportRepository {
  Future<bool> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      await FirestoreService.reports.add({
        'post_id': postId,
        'reporter_id': reporterId,
        'reason': reason,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[ReportRepo] reportPost error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReports({
    String status = 'pending',
  }) async {
    try {
      final snapshot = await FirestoreService.reports
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true)
          .limit(250)
          .get();
      return snapshot.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();
    } catch (e) {
      debugPrint('[ReportRepo] getReports error: $e');
      return [];
    }
  }

  Future<bool> reviewReport({
    required String reportId,
    required String status,
    required String reviewedBy,
  }) async {
    try {
      await FirestoreService.reports.doc(reportId).set({
        'status': status,
        'reviewed_by': reviewedBy,
        'reviewed_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirestoreService.auditLogs.add({
        'event_type': 'report_reviewed',
        'entity_type': 'report',
        'entity_id': reportId,
        'actor_id': reviewedBy,
        'summary': 'Report marked as $status',
        'metadata': {'status': status},
        // Legacy compatibility
        'type': 'report_reviewed',
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[ReportRepo] reviewReport error: $e');
      return false;
    }
  }
}
