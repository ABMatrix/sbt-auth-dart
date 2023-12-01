import 'dart:io';
import 'dart:typed_data';

import 'package:aptos/utils/sha.dart';
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc_or_grpcweb.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:solana/base58.dart';
import 'package:tron/tron.dart' as tron;
import 'package:web3dart/crypto.dart';

///
class TronSigner {
  ///
  TronSigner({
    required this.core,
    this.testNet = true,
  });

  /// account id
  String get accountId => core.localShare!.publicKey;

  ///
  final AuthCore core;

  /// 是否测试网
  final bool testNet;

  /// tron钱包客户端
  late final walletClient = tron.WalletClient(
    GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: 'grpc${testNet ? '.shasta' : ''}.trongrid.io',
      port: 50051,
      transportSecure: false,
    ),
    interceptors: [
      // TODO(RA1NO3O): replace this apiKey
      tron.ApiKeyInterceptor('2fecc24a-d0ce-438d-b623-96fe7c8b1215'),
    ],
  );

  /// Test account1
  static const testAddress1 = 'TTW2v4AVnxyL4MJpXXBXViK8UAfHZE5Qgp';

  /// Test account2
  static const testAddress2 = 'TYHYDzYGGEu4kiCiDfpjkVEcihJLVAs75o';

  /// 向TRON网络发送交易：
  ///
  /// * [ownerAddress] 发送者地址
  /// * [toAddress] 接收者地址
  /// * [amount] 交易金额
  Future<Map<String, dynamic>> sendTransaction({
    required List<int> ownerAddress,
    required List<int> toAddress,
    Int64? amount,
  }) async {
    // 1.通过系统合约API创建交易
    final tx = await walletClient.createTransaction2(
      tron.TransferContract(
        ownerAddress: ownerAddress,
        toAddress: toAddress,
        amount: amount,
      ),
    );

    if (!tx.result.result) {
      throw Exception(String.fromCharCodes(tx.result.message));
    }

    // 2.签署交易
    // 改写签名 交由core.signDigest进行

    await core
        .signDigest(
          Uint8List.fromList(tx.txid),
          [toAddress.toString()],
          amount.toString(),
          network: 'tron',
        )
        .then((signStr) => tx.transaction.signature.add(hexToBytes(signStr)));

    // 3.通过[broadcastTransaction]广播交易
    final result = await walletClient.broadcastTransaction(tx.transaction);
    if (!result.result) throw Exception(String.fromCharCodes(result.message));
    return result.writeToJsonMap();
  }

  ///
  Future<Map<dynamic, dynamic>> sendTokenTest(int amount) async {
    var publicKeyBytes =
        decompressPublicKey(hexToBytes(core.getPubKeyString().substring(2)));
    if (publicKeyBytes.length == 65) publicKeyBytes = publicKeyBytes.sublist(1);
    final hashedPublicKey = keccak256(Uint8List.fromList(publicKeyBytes));
    final addressBytes = [
      0x41,
      ...hashedPublicKey.sublist(hashedPublicKey.length - 20),
    ];
    return sendTransaction(
      ownerAddress: addressBytes,
      toAddress: base58decode(testAddress1).sublist(0, 21),
      amount: Int64(amount),
    );
  }
}
