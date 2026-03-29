import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/firestore_service.dart';
import '../models/partner.dart';

/// Repository for partner enrollment operations.
class EnrollmentRepository {
  /// Submit a new partner enrollment application.
  Future<bool> submitEnrollment({
    required Partner partner,
    String? actorId,
  }) async {
    try {
      await FirestoreService.partners.add({
        ...partner.toJson(),
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });
      await FirestoreService.auditLogs.add({
        'event_type': 'partner_enrollment_submitted',
        'entity_type': 'partner',
        'entity_id': null,
        'actor_id': actorId,
        'summary': 'Partner enrollment submitted',
        'metadata': {'name': partner.name},
        // Legacy compatibility
        'type': 'partner_enrollment_submitted',
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[EnrollmentRepo] submitEnrollment error: $e');
      return false;
    }
  }
}
