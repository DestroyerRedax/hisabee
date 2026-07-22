import 'package:meta/meta.dart';

/// Configuration and precondition checklist for the Cloud Activation Gate (PRD Section 13.3).
@immutable
class CloudActivationConfig {
  final bool hasDevStagingProdConfig;
  final bool hasOauthCredentials;
  final bool hasSecurityRules;
  final bool hasEmulatorSetup;
  final bool hasAppCheckPlan;
  final bool hasApprovedConsentCopy;
  final bool hasRollbackPlan;

  const CloudActivationConfig({
    this.hasDevStagingProdConfig = false,
    this.hasOauthCredentials = false,
    this.hasSecurityRules = false,
    this.hasEmulatorSetup = false,
    this.hasAppCheckPlan = false,
    this.hasApprovedConsentCopy = false,
    this.hasRollbackPlan = false,
  });

  /// Evaluates whether all Section 13.3 prerequisites are completely fulfilled.
  bool get isGateApproved =>
      hasDevStagingProdConfig &&
      hasOauthCredentials &&
      hasSecurityRules &&
      hasEmulatorSetup &&
      hasAppCheckPlan &&
      hasApprovedConsentCopy &&
      hasRollbackPlan;
}

/// Enforces the PRD Section 13.3 Activation Gate.
///
/// Cloud services remain explicitly unavailable until all activation gate criteria are met.
class CloudActivationGate {
  final CloudActivationConfig config;

  const CloudActivationGate({
    this.config = const CloudActivationConfig(), // Default: Gate is closed
  });

  bool get isCloudAvailable => config.isGateApproved;

  /// Returns status message explaining gate availability.
  String get statusMessage {
    if (config.isGateApproved) {
      return 'Cloud Activation Gate is APPROVED. Sync services are active.';
    }
    return 'Cloud Activation Gate is LOCKED. App is operating in strict local-only mode.';
  }
}
