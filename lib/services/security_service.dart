// Security service: biometric app lock via local_auth.
// Gracefully degrades on devices without biometrics.

import 'package:local_auth/local_auth.dart';

abstract final class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Does this device support biometrics at all?
  static Future<bool> canUseBiometrics() async {
    try {
      final bool supported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system biometric prompt. Returns true on success.
  /// Never throws — returns false when unavailable or cancelled.
  static Future<bool> authenticate(String reason) async {
    try {
      if (!await canUseBiometrics()) return true; // no lock available
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return true; // fail-open so users are never locked out by a bug
    }
  }
}
