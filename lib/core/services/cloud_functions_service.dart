import 'package:cloud_functions/cloud_functions.dart';

/// Centralized callable client so all Cloud Functions hit the deployed region.
class CloudFunctionsService {
  CloudFunctionsService._();

  static FirebaseFunctions get instance =>
      FirebaseFunctions.instanceFor(region: 'asia-south1');
}

