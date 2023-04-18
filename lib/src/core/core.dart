import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bitcoin/flutter_bitcoin.dart';
import 'package:http/http.dart' as http;
import 'package:mpc_dart/multi_mpc_dart.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/core/signer.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';
import 'package:solana/base58.dart';

import 'package:web3dart/crypto.dart';

/// chain
enum SbtChain { EVM, SOLANA, BITCOIN, DOGECOIN }

/// chain info
extension SbtChainInfo on SbtChain {
  /// engine
  Engine get engine {
    switch (this) {
      case SbtChain.EVM:
      case SbtChain.BITCOIN:
      case SbtChain.DOGECOIN:
        return Engine.ECDSA;
      case SbtChain.SOLANA:
        return Engine.EDDSA;
    }
  }
}

/// Mpc url
class MpcUrl {
  /// Mpc url
  MpcUrl({
    required this.url,
    required this.get,
    required this.set,
  });

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
  AuthCore({
    required this.mpcUrl,
    required this.signUrl,
    required this.token,
    this.chain = SbtChain.EVM,
  });

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

  /// chain
  late SbtChain chain;

  /// Remote sign
  bool remoteSign = false;

  /// Init core
  /// The most common case is use remote share to init auth core,
  /// the local share is loaded automaicly.
  Future<bool> init({
    Share? remote,
    String? address,
    Share? backup,
    String? localAux,
    Share? local,
    bool isTestnet = true,
  }) async {
    if (address != null) {
      _local = await _getSavedShare(address) ?? local;
      if (_local != null) {
        unawaited(_saveShare(_local!, address));
      }
    }
    _remote = remote;
    if (_local == null && _remote != null && backup != null) {
      await _recover(_remote!, backup, localAux!, isTestnet: isTestnet);
    }
    return _local != null;
  }

  /// Generate shares
  Future<MpcAccount> generatePubKey({bool testnet = true}) async {
    final keys = await MultiMpc.generate(1, 3, engine: chain.engine);
    _local = keyToShare(keys[0]);
    _remote = keyToShare(keys[1]);
    final address = getAddress(isTestnet: testnet);
    unawaited(_saveShare(_local!, address));
    return MpcAccount(
      address: address,
      shares: [for (final k in keys) keyToShare(k)],
    );
  }

  /// Local share
  Share? get localShare => _local;

  /// Get wallet address
  String getAddress({bool isTestnet = true}) {
    if (_local == null) throw SbtAuthException('Please init auth core');
    switch (chain) {
      case SbtChain.EVM:
        return MultiMpc.address(shareToKey(_local!));
      case SbtChain.SOLANA:
        return base58encode(hexToBytes(_local!.publicKey));
      case SbtChain.BITCOIN:
        return P2WPKH(
          data: PaymentData(pubkey: hexToBytes(_local!.publicKey)),
          network: isTestnet ? testnet : bitcoin,
        ).data.address!;
      case SbtChain.DOGECOIN:
        return P2PKH(
          data: PaymentData(pubkey: hexToBytes(_local!.publicKey)),
          network: isTestnet ? dogecoinMainnet : dogecoinMainnet,
        ).data.address!;
    }
  }

  /// Get pubkey
  Uint8List getPubkey() {
    return hexToBytes(_local!.publicKey);
  }

  /// Sign method
  Future<String> signDigest(
    Uint8List message,
    List<String> toList,
    String amount, {
    required String network,
    String? contractAddress,
  }) async {
    var msgs = message;
    if (chain == SbtChain.EVM) {
      msgs = keccak256(message);
    }
    // if (chain == SbtChain.BITCOIN && !remoteSign) {
    //   msgs = keccak256(message);
    // }
    var result = '';
    if (remoteSign) {
      final uid = await _setTaskId(
        listToHex(message),
        network,
        toList,
        amount,
        contractAddress:
            contractAddress ?? '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      );
      result = await MultiMpc.sign(
        MultiSignParams(
          keypair: shareToKey(_local!),
          msgs: [msgs],
          rawMsg: '',
          url: mpcUrl.url,
          get: mpcUrl.get,
          set: mpcUrl.set,
          uid: uid,
          token: 'Bearer $token',
        ),
      );
    } else {
      result = await MultiMpc.localSign(
        MultiSignLocalParams(
          [msgs],
          1,
          [shareToKey(_local!), shareToKey(_remote!, index: 2)],
        ),
        engine: chain.engine,
      );
    }
    return result;
  }

  /// Sign method
  Future<Signature> signTransaction(
    Uint8List message,
    List<String> toList,
    String amount, {
    required String network,
    required int chainId,
    required int nonce,
    bool isEIP1559 = false,
    String? contractAddress,
  }) async {
    final hashMessage = keccak256(message);
    var result = '';
    if (remoteSign) {
      final uid = await _setTaskId(
        listToHex(message),
        network,
        toList,
        amount,
        contractAddress: contractAddress,
        nonce: nonce,
      );
      result = await MultiMpc.sign(
        MultiSignParams(
          keypair: shareToKey(_local!),
          msgs: [hashMessage],
          rawMsg: '',
          url: mpcUrl.url,
          get: mpcUrl.get,
          set: mpcUrl.set,
          uid: uid,
          token: 'Bearer $token',
        ),
      );
    } else {
      result = await MultiMpc.localSign(
        MultiSignLocalParams(
          [hashMessage],
          1,
          [shareToKey(_local!), shareToKey(_remote!, index: 2)],
        ),
      );
    }
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

  Future<void> _recover(
    Share remote,
    Share backup,
    String aux, {
    bool isTestnet = true,
  }) async {
    final backupKey = shareToKey(backup, index: 3);
    final remoteKey = shareToKey(remote, index: 2);
    var backupAddress = '';
    var address = '';
    switch (chain) {
      case SbtChain.EVM:
        backupAddress = MultiMpc.address(backupKey);
        address = MultiMpc.address(remoteKey);
        break;
      case SbtChain.SOLANA:
        backupAddress = base58encode(hexToBytes(backupKey.pk));
        address = base58encode(hexToBytes(remoteKey.pk));
        break;
      case SbtChain.BITCOIN:
        backupAddress = P2WPKH(
          data: PaymentData(pubkey: hexToBytes(backupKey.pk)),
          network: isTestnet ? testnet : bitcoin,
        ).data.address!;
        address = P2WPKH(
          data: PaymentData(pubkey: hexToBytes(remoteKey.pk)),
          network: isTestnet ? testnet : bitcoin,
        ).data.address!;
        break;
      case SbtChain.DOGECOIN:
        backupAddress = P2PKH(
          data: PaymentData(pubkey: hexToBytes(backupKey.pk)),
          network: isTestnet ? dogecoinMainnet : dogecoinMainnet,
        ).data.address!;
        address = P2PKH(
          data: PaymentData(pubkey: hexToBytes(remoteKey.pk)),
          network: isTestnet ? dogecoinMainnet : dogecoinMainnet,
        ).data.address!;
        break;
    }
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
    final remoteShare =
        keyToShare(MultiKeypair.fromJson(MultiMpc.auxToKeypair(key)));
    return remoteShare.copyWith(privateKey: share.privateKey);
  }

  Future<String> _setTaskId(
    String rawMessage,
    String network,
    List<String> toList,
    String amount, {
    String? contractAddress,
    int? nonce,
  }) async {
    final uid = MultiMpc.uuid();
    final data = {
      'metadata': jsonEncode({
        'uid': uid,
        'party_ind': 2,
        'engine': chain.engine.name,
      }),
      'rawMsg': rawMessage,
      'network': network,
      'keyType': chain.name,
      'toList': toList,
      'amount': amount,
      'contractAddress': contractAddress,
      'nonce': nonce
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

  /// Get backup privateKey
  Future<String> getBackupPrivateKey(String aux) async {
    if (_local == null || _remote == null) {
      throw SbtAuthException('Please init auth core');
    }
    final localKey = shareToKey(_local!);
    final remoteKey = shareToKey(_remote!, index: 2);
    final backup = await MultiMpc.recover(
      [localKey, remoteKey],
      jsonDecode(aux) as Map<String, dynamic>,
    );
    if (backup.sk.startsWith('0x')) {
      return backup.sk;
    }
    return '0x${backup.sk}';
  }

  /// set sign model
  void setSignModel(bool signModel) {
    remoteSign = signModel;
  }
}
