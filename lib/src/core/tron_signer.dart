import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
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

  /// 发送TRX交易：
  ///
  /// * [ownerAddress] 发送者地址
  /// * [toAddress] 接收者地址
  /// * [amount] 交易金额
  Future<Map<String, dynamic>> sendTrx({
    List<int>? ownerAddress,
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

  /// 发送TRC20代币交易
  ///
  /// * [ownerAddress] 发送者地址
  /// * [toAddress] 接收者地址
  /// * [amount] 交易金额
  /// * [contractAddress] 代币所属合约地址
  Future<Map<String, dynamic>> sendToken({
    List<int>? ownerAddress,
    required List<int> toAddress,
    Int64? amount,
    required List<int> contractAddress,
    Uint8List? data,
  }) async {
    // 通过合约地址触发合约
    final tx = await walletClient.triggerContract(
      tron.TriggerSmartContract(
        ownerAddress: ownerAddress,
        contractAddress: contractAddress,
        callValue: amount,
        data: data,
      ),
    );
    // final tx = await walletClient.transferAsset2(
    //   tron.TransferAssetContract(
    //     ownerAddress: ownerAddress,
    //     toAddress: toAddress,
    //     amount: amount,
    //     assetName: tokenName,
    //   ),
    // );

    if (!tx.result.result) {
      throw Exception(String.fromCharCodes(tx.result.message));
    }

    await core
        .signDigest(
          Uint8List.fromList(tx.txid),
          [toAddress.toString()],
          amount.toString(),
          network: 'tron',
          contractAddress: 'TG3XXyExBkPp9nzdajDZsozEu4BkaSJozs',
        )
        .then((signStr) => tx.transaction.signature.add(hexToBytes(signStr)));

    final result = await walletClient.broadcastTransaction(tx.transaction);
    if (!result.result) throw Exception(String.fromCharCodes(result.message));
    return result.writeToJsonMap();
  }

  /// 发送TRX交易测试
  Future<Map<dynamic, dynamic>> sendTrxTest(int amount) async {
    var publicKeyBytes =
        decompressPublicKey(hexToBytes(core.getPubKeyString().substring(2)));
    if (publicKeyBytes.length == 65) publicKeyBytes = publicKeyBytes.sublist(1);
    final hashedPublicKey = keccak256(Uint8List.fromList(publicKeyBytes));
    final addressBytes = [
      0x41,
      ...hashedPublicKey.sublist(hashedPublicKey.length - 20),
    ];
    return sendTrx(
      ownerAddress: addressBytes,
      toAddress: base58decode(testAddress1).sublist(0, 21),
      amount: Int64(amount),
    );
  }

  /// 发送USDT代币交易测试
  Future<Map<dynamic, dynamic>> sendUSDTTokenTest(int amount) async {
    var publicKeyBytes =
        decompressPublicKey(hexToBytes(core.getPubKeyString().substring(2)));
    if (publicKeyBytes.length == 65) publicKeyBytes = publicKeyBytes.sublist(1);
    final hashedPublicKey = keccak256(Uint8List.fromList(publicKeyBytes));
    final addressBytes = [
      0x41,
      ...hashedPublicKey.sublist(hashedPublicKey.length - 20),
    ];
    final usdtContractAddress =
        base58decode('TG3XXyExBkPp9nzdajDZsozEu4BkaSJozs');

    final contract = await walletClient.getContract(
      tron.BytesMessage(
        value:
            usdtContractAddress.take(usdtContractAddress.length - 4).toList(),
      ),
    );

    if (!contract.hasAbi()) throw Exception('Contract has no abi');

    return sendToken(
      ownerAddress: addressBytes,
      toAddress: base58decode(testAddress1).sublist(0, 21),
      contractAddress: contract.contractAddress,
      data: assembleData(
        abiFunction: contract.abi.entrys
            .firstWhere((element) => element.name == 'transfer'),
        // functionInfo: 'transfer(address,uint256)',
        parameters: [
          base58decode(testAddress1).sublist(0, 21),
          BigInt.from(amount)
        ],
      ),
    );
  }

  /// 组装合约数据参数
  ///
  /// * [abiFunction] 合约方法签名
  /// * [parameters] 参数列表
  Uint8List assembleData({
    String? functionInfo,
    tron.SmartContract_ABI_Entry? abiFunction,
    required List<dynamic> parameters,
  }) {
    if (functionInfo == null && abiFunction == null) {
      throw Exception(
        'Must provide either functionInfo or abiFunction to assemble data',
      );
    }
    final functionSignature = functionInfo ??
        '${abiFunction?.name}'
            '(${abiFunction?.inputs.map((e) => e.type)})';
    final functionId = keccak256(utf8.encode(functionSignature)).sublist(0, 4);
    final encodedParameters = parameters.map((parameter) {
      if (parameter is String) {
        return parameter.padLeft(64, '0');
      } else if (parameter is BigInt) {
        return parameter.toRadixString(16).padLeft(64, '0');
      } else if (parameter is List<int>) {
        return hex.encode(parameter);
      } else {
        throw ArgumentError('Unsupported parameter type');
      }
    }).join();
    return hexToBytes('0x${hex.encode(functionId)}'
        '${encodedParameters.substring(1, encodedParameters.length - 1)}');
  }
}
