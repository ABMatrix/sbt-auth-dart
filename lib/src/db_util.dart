// ignore_for_file: constant_identifier_names
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/types/adapter.dart';

/// Hive token box key
const TOKEN_KEY = 'token_key';

/// Hive device name box key
const DEVICE_NAME_KEY = 'device_name_key';

/// Hive cache box key
const CACHE_KEY = 'local_cache_key';

/// Hive Util
class DBUtil {
  /// user token box
  static late Box<String> tokenBox;


  /// device box
  static late Box<String> deviceBox;

  /// share box
  static late Box<Share?>? shareBox;

  /// init Box
  static Future<void> init() async {
    final document = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(document.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ShareAdapter());
    }
    tokenBox = await Hive.openBox(TOKEN_KEY);
    deviceBox = await Hive.openBox(DEVICE_NAME_KEY);
    shareBox = await Hive.openBox(CACHE_KEY);
  }
}
