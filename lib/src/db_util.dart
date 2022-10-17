import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/types/adapter.dart';

const TOKEN_KEY = 'token_key';

const CACHE_KEY = 'local_cache_key';

/// Hive Util
class DBUtil {
  /// dbUtil instance
  static DBUtil? instance;

  /// user token box
  late Box<String> tokenBox;

  /// share box
  late Box<Share?>? shareBox;

  /// init database path
  static Future<void> install() async {
    final document = await getApplicationDocumentsDirectory();
    Hive.init(document.path);
  }

  /// init Box
  static Future<DBUtil> getInstance() async {
    if (instance == null) {
      instance = DBUtil();
      await Hive.initFlutter();
    }
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ShareAdapter());
    }
    instance?.tokenBox = await Hive.openBox(TOKEN_KEY);
    instance?.shareBox = await Hive.openBox(CACHE_KEY);
    return instance!;
  }
}
