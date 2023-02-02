// ignore_for_file: constant_identifier_names
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/types/adapter.dart';

/// Hive token box key
const TOKEN_KEY = 'token_key';

/// Hive cache box key
const CACHE_KEY = 'local_cache_key';

/// Hive cache box key
const SOLANA_CACHE_KEY = 'local_solana_cache_key';

/// Hive Util
class DBUtil {
  /// user token box
  static late Box<String> tokenBox;

  /// share box
  static late Box<Share?>? shareBox;

  /// solana share box
  static late Box<Share?>? solanaShareBox;

  /// init Box
  static Future<void> init() async {
    final document = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(document.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ShareAdapter());
    }
    tokenBox = await Hive.openBox(TOKEN_KEY);
    shareBox = await Hive.openBox(CACHE_KEY);
    solanaShareBox = await Hive.openBox(SOLANA_CACHE_KEY);
  }
}
