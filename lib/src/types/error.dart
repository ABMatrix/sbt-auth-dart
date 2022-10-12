import 'dart:developer';

/// Sbt auth exceoption
class SbtAuthError extends Error {
  /// Sbt auth error
  SbtAuthError([this.message]);

  /// Exception message
  final String? message;
  @override
  String toString() {
    log('SBTAuth error, $message');
    return Error.safeToString(message).replaceAll('"', '');
  }
}
