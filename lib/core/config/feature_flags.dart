/// Runtime feature flags for progressive UI rollouts.
///
/// Use `--dart-define=PUBLIC_PREMIUM_REDESIGN=false` to disable.
class FeatureFlags {
  FeatureFlags._();

  static const bool publicPremiumRedesign = bool.fromEnvironment(
    'PUBLIC_PREMIUM_REDESIGN',
    defaultValue: true,
  );

  /// Keep OTP Cloud Function enabled for auth bootstrap.
  static const bool otpCallableEnabled = bool.fromEnvironment(
    'OTP_CALLABLE_ENABLED',
    defaultValue: true,
  );

  /// Low-cost mode defaults: disable server-only admin callables.
  static const bool roleManagementCallableEnabled = bool.fromEnvironment(
    'ROLE_MANAGEMENT_CALLABLE_ENABLED',
    defaultValue: true,
  );

  static const bool storageConfigCallableEnabled = bool.fromEnvironment(
    'STORAGE_CONFIG_CALLABLE_ENABLED',
    defaultValue: true,
  );

  static const bool campaignCallableEnabled = bool.fromEnvironment(
    'CAMPAIGN_CALLABLE_ENABLED',
    defaultValue: true,
  );

  /// Optional engagement callables; when disabled app falls back to Firestore.
  static const bool interactionCallableEnabled = bool.fromEnvironment(
    'INTERACTION_CALLABLE_ENABLED',
    defaultValue: true,
  );

  /// Disable function-backed preview links in low-cost mode.
  static const bool functionPreviewRouteEnabled = bool.fromEnvironment(
    'FUNCTION_PREVIEW_ROUTE_ENABLED',
    defaultValue: true,
  );
}
