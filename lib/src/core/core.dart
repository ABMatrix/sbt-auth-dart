import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mpc_dart/mpc_dart.dart';
import 'package:sbt_auth_dart/src/core/signer.dart';
import 'package:sbt_auth_dart/src/types/account.dart';
import 'package:sbt_auth_dart/src/types/adapter.dart';
import 'package:sbt_auth_dart/src/types/exception.dart';

import 'package:sbt_auth_dart/src/utils.dart';

/// Hive box key
const CACHE_KEY = 'local_cache_key';

/// SBTAuth core, manage shares
class AuthCore {
  /// Local share, saved on user device
  late Share? _local;

  /// Remote share, saved on server side
  late Share? _remote;
  Box<Share?>? _box;

  /// Signer
  Signer get signer => Signer(this);

  /// Init core
  /// The most common case is use remote share to init auth core,
  /// the local share is loaded automaicly.
  Future<bool> init(
      {Share? remote, String? address, String? backup, Share? local}) async {
    await _initHive();
    if (address != null) {
      _local = _getSavedShare(address) ?? local;
      if (_local != null) {
        _saveShare(_local!, address);
      }
    }
    _remote = remote;
    if (_local == null && _remote != null && backup != null) {
      _recover(_remote!, backup);
    }
    return _local != null;
  }

  /// Generate shares
  Future<MpcAccount> generatePubKey() async {
    await _initHive();
    final keys = Ecdsa.generate(1, 3);
    final address = Ecdsa.address(keys[0]);
    _local = keyToShare(keys[0]);
    _remote = keyToShare(keys[1]);
    _saveShare(_local!, address);
    return MpcAccount(
      address: address,
      shares: [for (final k in keys) keyToShare(k)],
    );
  }

  /// Local share
  Share? get localShare => _local;

  /// Get wallet address
  String getAddress() {
    if (_local == null) throw SbtAuthException('Please init auth core');
    return Ecdsa.address(shareToKey(_local!));
  }

  /// Sign method
  String signDigest(Uint8List message) {
    final result = Ecdsa.sign(
      SignParams(
        [message],
        1,
        [shareToKey(_local!), shareToKey(_remote!, 2)],
      ),
    );
    return result;
  }

  Share? _getSavedShare(String address) {
    final share = _box!.get(address);
    return share;
  }

  Future<void> _saveShare(Share share, String address) {
    return _box!.put(address, share);
  }

  void _recover(Share remote, String backup) {
    if (!validPrivateKey(backup)) {
      throw SbtAuthException('Wrong backup private key');
    }
    final backupShare = Share(
      privateKey: backup,
      extraData: remote.extraData,
    );
    final backupKey = shareToKey(backupShare, 3);
    final remoteKey = shareToKey(remote, 2);
    final backupAddress = Ecdsa.address(backupKey);
    final address = Ecdsa.address(remoteKey);
    if (backupAddress != address) {
      throw SbtAuthException('Wrong backup private key');
    }
    final localKey = Ecdsa.recover([backupKey, remoteKey]);
    _local = keyToShare(localKey);
    _saveShare(keyToShare(localKey), address);
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ShareAdapter());
    await Hive.openBox<Share?>(CACHE_KEY);
    _box = Hive.box<Share?>(CACHE_KEY);
  }
}
