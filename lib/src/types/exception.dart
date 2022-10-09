import 'dart:developer';

/// Sbt auth exceoption
class SbtAuthException implements Exception {
  /// Sbt auth
  SbtAuthException([this.message]);

  /// Exception message
  final String? message;
  @override
  String toString() {
    log('SBTAuth exception, $message');
    return Error.safeToString(message).replaceAll('"', '');
  }
}
