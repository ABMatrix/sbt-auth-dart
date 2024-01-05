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
  /// Tron 签名器
  /// * [testNet] 仅用作透传参数为`getAddress`所用, 无其他效果
  /// * [jRPCUrl] jRPC URL
  /// * [gRPCUrl] gRPC URL
  TronSigner({
    required this.core,
    this.testNet = true,
    required this.jRPCUrl,
    required this.gRPCUrl,
  });

  /// account id
  String get accountId => core.localShare!.publicKey;

  ///
  final AuthCore core;

  /// 是否测试网
  final bool testNet;

  /// jRPC URL
  final String jRPCUrl;

  /// gRPC URL
  final String gRPCUrl;

  /// HTTP(jRPC) 客户端
  late final httpClient = Dio(
    BaseOptions(
      baseUrl: jRPCUrl,
      headers: {
        'accept': 'aplication/json',
        'content-type': 'application/json',
      },
    ),
  );

  /// gRPC 客户端
  late final walletClient = tron.WalletClient(
    GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: Uri.parse(gRPCUrl).host,
      port: 50051,
      transportSecure: false,
    ),
    interceptors: [
      tron.ApiKeyInterceptor('7fb2a814-c3e4-4fdd-b425-319151924063'),
    ],
  );

  /// 获取带宽消耗
  Future<num> getBandwidth({String? ownerAddress}) async {
    final accountActivated = await httpClient.post<Map<String, dynamic>>(
      '/wallet/getaccount',
      data: {
        'address': ownerAddress ?? core.getAddress(isTestnet: testNet),
        'visible': true,
      },
    ).then((resp) => resp.data?.isNotEmpty ?? false);
    if (accountActivated) return 0.002;
    return 0.1;
  }

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
          network: testNet ? 'tron_testnet' : 'tron',
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
  Future<Map<String, dynamic>?> sendToken({
    String? ownerAddress,
    required String toAddress,
    required BigInt amount,
    required String contractAddress,
  }) async {
    //解码合约地址
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

    // 触发智能合约
    final tscResp = await triggerSmartContract(
      ownerAddress: ownerAddress,
      contractAddress: contractAddress,
      abiFunc: transferAbiFunc,
      params: params,
    );

    // 取出交易json
    final jsonTx = tscResp?['transaction'] as Map<String, dynamic>;

    // 调用mpc远端签名
    final signStr = await core.signDigest(
      hexToBytes(jsonTx['txID'] as String),
      [toAddress],
      amount.toString(),
      network: 'tron',
      contractAddress: contractAddress,
    );

    return broadcastTransaction(signStr: signStr, jsonTx: jsonTx);
  }

  /// 触发智能合约
  ///
  /// * [ownerAddress] 发送者地址, 为空时使用`core.getAddress(isTestnet: testNet)`
  /// * [contractAddress] 合约地址
  /// * [abiFunc] 合约方法
  /// * [params] 参数
  ///
  /// [API 文档](https://developers.tron.network/reference/triggersmartcontract)
  Future<Map<String, dynamic>?> triggerSmartContract({
    String? ownerAddress,
    required String contractAddress,
    required tron.SmartContract_ABI_Entry abiFunc,
    Iterable<String> params = const [],
  }) =>
      httpClient.post<Map<String, dynamic>>(
        '/wallet/triggersmartcontract',
        data: {
          'owner_address': ownerAddress ?? core.getAddress(isTestnet: testNet),
          'contract_address': contractAddress,
          'function_selector': '${abiFunc.name}'
                  '${abiFunc.inputs.map((e) => e.type)}'
              .replaceAll(' ', ''),
          'parameter': params.join(),
          'fee_limit': 1000000000,
          'visible': true,
        },
      ).then((resp) => resp.data);

  /// 广播交易
  ///
  /// * [signStr] 签名字符串
  /// * [jsonTx] 交易JSON
  ///
  /// [API 文档](https://developers.tron.network/reference/broadcasttransaction)
  Future<Map<String, dynamic>?> broadcastTransaction({
    required String signStr,
    required Map<String, dynamic> jsonTx,
  }) =>
      httpClient.post<Map<String, dynamic>>(
        '/wallet/broadcasttransaction',
        data: {
          'txID': jsonTx['txID'],
          'visible': true,
          'raw_data': jsonTx['raw_data'],
          'raw_data_hex': jsonTx['raw_data_hex'],
          'signature': [signStr],
        },
      ).then((resp) => resp.data);
}
