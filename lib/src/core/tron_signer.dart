import 'dart:typed_data';

import 'package:dio/dio.dart';
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

  /// tron HTTP客户端
  final httpClient = Dio(
    BaseOptions(
      headers: {
        'accept': 'aplication/json',
        'content-type': 'application/json',
      },
    ),
  );

  /// tron钱包客户端
  late final walletClient = tron.WalletClient(
    GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: 'grpc${testNet ? '.shasta' : ''}.trongrid.io',
      port: 50051,
      transportSecure: false,
    ),
    interceptors: [
      tron.ApiKeyInterceptor('7fb2a814-c3e4-4fdd-b425-319151924063'),
    ],
  );

  /// 发送TRX交易：
  ///
  /// * [ownerAddress] 发送者地址, 为空时使用`core.getAddress(isTestnet: testNet)`
  /// * [toAddress] 接收者地址
  /// * [amount] 交易金额 精度6
  Future<Map<String, dynamic>> sendTrx({
    String? ownerAddress,
    required String toAddress,
    required Int64 amount,
  }) async {
    // 1.通过系统合约API创建交易
    final tx = await walletClient.createTransaction2(
      tron.TransferContract(
        ownerAddress: Uint8List.fromList(
          base58decode(ownerAddress ?? core.getAddress(isTestnet: testNet))
              .sublist(0, 21),
        ),
        toAddress: Uint8List.fromList(base58decode(toAddress).sublist(0, 21)),
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
          [toAddress],
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
  /// * [ownerAddress] 发送者地址, 为空时使用`core.getAddress(isTestnet: testNet)`
  /// * [toAddress] 接收者地址
  /// * [amount] 交易金额
  /// * [contractAddress] 代币所属合约地址
  Future<Map<String, dynamic>> sendToken({
    String? ownerAddress,
    required String toAddress,
    required BigInt amount,
    required String contractAddress,
  }) async {
    final dca = base58decode(contractAddress);
    // 获取合约信息
    final contract = await walletClient.getContract(
      tron.BytesMessage(value: dca.take(dca.length - 4).toList()),
    );

    if (!contract.hasAbi()) {
      throw Exception('Contract ${contract.name} has no abi!');
    }

    // 取出转账方法
    final transferAbiFunc =
        contract.abi.entrys.firstWhere((element) => element.name == 'transfer');

    // 组装转账参数
    final params = transferAbiFunc.inputs.map(
      (e) => switch (e.type) {
        'address' => bytesToHex(
            Uint8List.fromList(
              base58decode(
                toAddress.substring(1, toAddress.length - 4),
              ),
            ),
          ).padLeft(64, '0'),
        'uint256' => amount.toRadixString(16).padLeft(64, '0'),
        _ => throw FormatException('Unknown abiFunction input: ${e.type}'),
      },
    );

    // 通过合约地址触发合约
    // https://developers.tron.network/reference/triggersmartcontract
    final tscResp = await httpClient.postUri<Map<String, dynamic>>(
      Uri.https('api.shasta.trongrid.io', '/wallet/triggersmartcontract'),
      data: {
        'owner_address': ownerAddress ?? core.getAddress(isTestnet: testNet),
        'contract_address': contractAddress,
        'function_selector': '${transferAbiFunc.name}'
                '${transferAbiFunc.inputs.map((e) => e.type)}'
            .replaceAll(' ', ''),
        'parameter': params.join(),
        'fee_limit': 1000000000,
        'visible': true,
      },
    );

    final jsonTx = tscResp.data?['transaction'] as Map<String, dynamic>;

    // 调用mpc远端签名
    final signStr = await core.signDigest(
      hexToBytes(jsonTx['txID'] as String),
      [toAddress],
      amount.toString(),
      network: 'tron',
      contractAddress: contractAddress,
    );

    // 广播交易
    // https://developers.tron.network/reference/broadcasttransaction
    final result = await httpClient.postUri<Map<String, dynamic>>(
      Uri.https('api.shasta.trongrid.io', '/wallet/broadcasttransaction'),
      data: {
        'txID': jsonTx['txID'],
        'visible': true,
        'raw_data': jsonTx['raw_data'],
        'raw_data_hex': jsonTx['raw_data_hex'],
        'signature': [signStr]
      },
    );

    return Future.value(result.data);
  }
}
