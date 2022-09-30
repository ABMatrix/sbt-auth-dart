import 'package:hive/hive.dart';
import 'package:sbt_auth_dart/src/types/account.dart';

/// Hive box key
const CACHE_KEY = 'local_cache_key';

/// SBTAuth core, manage shares
class AuthCore {
  /// Local share, saved on user device
  late Share? _local;

  /// Remote share, saved on server side
  late Share? _remote;
  final _box = Hive.box<Share?>(CACHE_KEY);

  /// Init core
  /// The most common case is use remote share to init auth core,
  /// the local share is loaded automaicly.
  ///
  bool init({Share? remote, String? address, String? backup, Share? local}) {
    if (address != null) {
      _local = _getSavedShare(address) ?? local;
      if (_local != null) {
        _saveShare(local, address);
      }
    }
    _remote = remote;
    if (_local == null && remote != null && backup != null) {
      recover(remote, backup);
    }
    return _local != null;
  }

  Share? _getSavedShare(String address) {
    final share = _box.get(address);
    return share;
  }

  Future<void> _saveShare(Share share, String address) {
    return _box.put(address, share);
  }

  _recover() {
    
  }
}
