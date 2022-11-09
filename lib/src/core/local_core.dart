import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpc_dart/mpc_dart.dart';
import 'package:sbt_auth_dart/src/core/local_signer.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/account.dart';
import 'package:sbt_auth_dart/src/types/exception.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';
import 'package:sbt_auth_dart/src/utils.dart';
import 'package:web3dart/crypto.dart';

/// Hive box key

/// SBTAuth core, manage shares
class LocalAuthCore {
  /// Local share, saved on user device
  late Share? _local;

  /// Remote share, saved on server side
  late Share? _remote;

  /// Signer
  LocalSigner get signer => LocalSigner(this);

  /// Init core
  /// The most common case is use remote share to init auth core,
  /// the local share is loaded automaicly.
  Future<bool> init({
    Share? remote,
    String? address,
    String? backup,
    Share? local,
  }) async {
    if (address != null) {
      _local = await _getSavedShare(address) ?? local;
      if (_local != null) {
        unawaited(_saveShare(_local!, address));
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
    final keys = Ecdsa.generate(1, 3);
    final address = Ecdsa.address(keys[0]);
    _local = keyToLocalShare(keys[0]);
    _remote = keyToLocalShare(keys[1]);
    unawaited(_saveShare(_local!, address));
    return MpcAccount(
      address: address,
      shares: [for (final k in keys) keyToLocalShare(k)],
    );
  }

  /// Local share
  Share? get localShare => _local;

  /// Get wallet address
  String getAddress() {
    if (_local == null) throw SbtAuthException('Please init auth core');
    return Ecdsa.address(localShareToKey(_local!));
  }

  /// Sign method
  String signDigest(Uint8List message, {int? chainId, bool isEIP1559 = false}) {
    final result = Ecdsa.sign(
      SignParams(
        [message],
        1,
        [localShareToKey(_local!), localShareToKey(_remote!, 2)],
      ),
    );
    final signature = Signature.from(hexToBytes(result));
    return bytesToHex(signature.join(), include0x: true);
  }

  /// Sign method
  Signature signTransaction(
    Uint8List message, {
    required int chainId,
    bool isEIP1559 = false,
  }) {
    final result = Ecdsa.sign(
      SignParams(
        [message],
        1,
        [localShareToKey(_local!), localShareToKey(_remote!, 2)],
      ),
    );
    final signature = Signature.from(hexToBytes(result));
    var chainIdV = signature.v;
    if (isEIP1559) {
      chainIdV = signature.v - 27;
    } else {
      chainIdV = signature.v - 27 + (chainId * 2 + 35);
    }
    return signature.copyWith(v: chainIdV);
  }

  Future<Share?> _getSavedShare(String address) async {
    final share = DBUtil.shareBox!.get(address);
    return (share == null || share.privateKey == '') ? null : share;
  }

  Future<void> _saveShare(Share share, String address) async {
    return DBUtil.shareBox!.put(address, share);
  }

  void _recover(Share remote, String backup) {
    if (!validPrivateKey(backup)) {
      throw SbtAuthException('Wrong backup private key');
    }
    final backupShare = Share(
      privateKey: backup,
      extraData: remote.extraData,
    );
    final backupKey = localShareToKey(backupShare, 3);
    final remoteKey = localShareToKey(remote, 2);
    final backupAddress = Ecdsa.address(backupKey);
    final address = Ecdsa.address(remoteKey);
    if (backupAddress != address) {
      throw SbtAuthException('Wrong backup private key');
    }
    final localKey = Ecdsa.recover([backupKey, remoteKey]);
    _local = keyToLocalShare(localKey);
    _saveShare(keyToLocalShare(localKey), address);
  }

  /// Get privateKey
  String getPrivateKey() {
    if (_local == null || _remote == null) {
      throw SbtAuthException('Please init auth core');
    }
    final privateKey = Ecdsa.privateKey([
      localShareToKey(_local!),
      localShareToKey(_remote!, 2),
    ]);
    return privateKey;
  }

  /// Get backup privateKey
  String getBackupPrivateKey() {
    if (_local == null || _remote == null) {
      throw SbtAuthException('Please init auth core');
    }
    final localKey = localShareToKey(_local!);
    final remoteKey = localShareToKey(_remote!, 2);
    final backup = Ecdsa.recover([localKey, remoteKey]);
    return '0x${backup.x_i}';
  }
}
