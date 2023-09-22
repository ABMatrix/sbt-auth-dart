// ignore_for_file: constant_identifier_names
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/types/adapter.dart';

/// Hive token box key
const TOKEN_KEY = 'token_key';

/// Hive device box key
const DEVICE_KEY = 'device_key';

/// Hive cache box key
const USER_KEY = 'user_key';

/// Hive cache box key
const CACHE_KEY = 'local_cache_key';

/// Hive cache box key
const AUX_KEY = 'local_aux_key';

/// Hive cache box key
const HASH_KEY = 'local_hash_key';

/// Hive cache box key
const FRIEND_SHARE_KEY = 'friend_share_key';

/// Hive Util
class DBUtil {
  /// user token box
  static late Box<String> tokenBox;

  /// device name box
  static late Box<String> deviceNameBox;

  /// share box
  static late Box<Share?>? shareBox;

  /// user box
  static late Box<UserInfo?> userBox;

  /// aux box
  static late Box<String> auxBox;

  /// backup hash box
  static late Box<String> hashBox;

  /// friend share box
  static late Box<String> friendShareBox;

  /// init Box
  static Future<void> init() async {
    final document = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(document.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ShareAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(UserInfoAdapter());
    }
    tokenBox = await Hive.openBox(TOKEN_KEY);
    deviceNameBox = await Hive.openBox(DEVICE_KEY);
    shareBox = await Hive.openBox(CACHE_KEY);
    userBox = await Hive.openBox(USER_KEY);
    auxBox = await Hive.openBox(AUX_KEY);
    hashBox = await Hive.openBox(HASH_KEY);
    friendShareBox = await Hive.openBox(FRIEND_SHARE_KEY);
  }
}
