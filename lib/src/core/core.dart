import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mpc_dart/multi_mpc_dart.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/core/signer.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';

import 'package:web3dart/crypto.dart';

/// Mpc url
class MpcUrl {
  /// Mpc url
  MpcUrl({required this.url, required this.get, required this.set});

  /// url
  late String url;

  /// get
  late String get;

  /// set
  late String set;
}

/// SBTAuth core, manage shares
class AuthCore {
  /// Auth core
  AuthCore({required this.mpcUrl, required this.signUrl, required this.token});

  /// Local share, saved on user device
  late Share? _local;

  /// Remote share, saved on server side
  late Share? _remote;

  /// Signer
  Signer get signer => Signer(this);

  /// Mpc url
  late MpcUrl mpcUrl;

  /// Sign url
  late String signUrl;

  /// token
  late String token;

  /// Init core
  /// The most common case is use remote share to init auth core,
  /// the local share is loaded automaicly.
  Future<bool> init({
    Share? remote,
    String? address,
    Share? backup,
    String? backupAux,
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
      await _recover(_remote!, backup, backupAux!);
    }
    return _local != null;
  }

  /// Generate shares
  Future<MpcAccount> generatePubKey() async {
    final keys = await MultiMpc.generate(1, 3);
    final address = MultiMpc.address(keys[0]);
    _local = keyToShare(keys[0]);
    _remote = keyToShare(keys[1]);
    unawaited(_saveShare(_local!, address));
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
    return MultiMpc.address(shareToKey(_local!));
  }

  /// Sign method
  Future<String> signDigest(
    Uint8List message, {
    int? chainId,
    bool isEIP1559 = false,
  }) async {
    final uid = await _setTaskId(listToHex(message), chainId ?? 0);
    final rawMessage = keccak256(message);
    final result = await MultiMpc.sign(
      MultiSignParams(
        keypair: shareToKey(_local!),
        msgs: [rawMessage],
        rawMsg: '',
        url: mpcUrl.url,
        get: mpcUrl.get,
        set: mpcUrl.set,
        uid: uid,
        token: 'Bearer $token',
      ),
    );
    final signature = Signature.from(hexToBytes(result));
    return bytesToHex(signature.join(), include0x: true);
  }

  /// Sign method
  Future<Signature> signTransaction(
    Uint8List message, {
    required int chainId,
    bool isEIP1559 = false,
  }) async {
    final uid = await _setTaskId(listToHex(message), chainId);
    final rawMessage = keccak256(message);
    final result = await MultiMpc.sign(
      MultiSignParams(
        keypair: shareToKey(_local!),
        msgs: [rawMessage],
        rawMsg: '',
        url: mpcUrl.url,
        get: mpcUrl.get,
        set: mpcUrl.set,
        uid: uid,
        token: 'Bearer $token',
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

  Future<void> _recover(Share remote, Share backup, String aux) async {
    final backupKey = shareToKey(backup, index: 3);
    final remoteKey = shareToKey(remote, index: 2);
    final backupAddress = MultiMpc.address(backupKey);
    final address = MultiMpc.address(remoteKey);
    if (backupAddress != address) {
      throw SbtAuthException('Wrong backup private key');
    }
    final localKey = await MultiMpc.recover(
      [backupKey, remoteKey],
      jsonDecode(aux) as Map<String, dynamic>,
    );
    _local = keyToShare(localKey);
    await _saveShare(keyToShare(localKey), address);
  }

  /// Get remote key pair
  static Share getRemoteKeypair(Share share) {
    final key = shareToKey(share);
    return keyToShare(MultiKeypair.fromJson(MultiMpc.auxToKeypair(key)));
  }

  Future<String> _setTaskId(String rawMessage, int chainID) async {
    final uid = MultiMpc.uuid();
    final data = {
      'metadata': jsonEncode({
        'uid': uid,
        'party_ind': 2,
        'engine': 'ECDSA',
      }),
      'rawMsg': rawMessage,
      'chainID': chainID,
    };
    final res = await http.post(
      Uri.parse(signUrl),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['code'] != '000') {
      throw SbtAuthException((body['msg'] ?? '') as String);
    }
    return uid;
  }
}
