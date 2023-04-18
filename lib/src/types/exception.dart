import 'dart:developer';

/// Sbt auth exceoption
class SbtAuthException implements Exception {
  /// Sbt auth
  SbtAuthException([this.message, this.code]);

  /// Exception message
  final String? message;

  /// Exception code
  final String? code;
  @override
  String toString() {
    log('SBTAuth exception, $message');
    return Error.safeToString(message).replaceAll('"', '');
  }
}
