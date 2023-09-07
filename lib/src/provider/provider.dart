import 'dart:convert';

import 'package:http/http.dart';
import 'package:sbt_auth_dart/src/core/signer.dart';
import 'package:sbt_auth_dart/src/types/error.dart';
import 'package:sbt_auth_dart/src/types/exception.dart';
import 'package:sbt_auth_dart/src/types/provider.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/json_rpc.dart';

const _ethSignerMethods = [
  'eth_requestAccounts',
  'eth_accounts',
  'eth_chainId',
  'eth_sendTransaction',
  'eth_signTransaction',
  'eth_sign',
  'signTypedData',
  'signTypedData_v1',
  'signTypedData_v3',
  'signTypedData_v4',
  'personal_sign',
];

const _ethRpc = {
  '0x1': 'https://rpc-product.safematrix.io/json-rpc/http/eth',
  '0x5': 'https://rpc-product.safematrix.io/json-rpc/http/eth_goerli',
  // Sepolia
  '0xaa36a7': 'https://rpc-product.safematrix.io/json-rpc/http/sepolia',
  '0x38': 'https://rpc-product.safematrix.io/json-rpc/http/bsc',
  '0x61': 'https://rpc-product.safematrix.io/json-rpc/http/bsc_chapel',
  // Polygon
  '0x89': 'https://rpc-product.safematrix.io/json-rpc/http/polygon',
  // Polygon Mumbai
  '0x13881': 'https://rpc-product.safematrix.io/json-rpc/http/polygon_mumbai',
  // Filecoin
  '0x13a': 'https://rpc-product.safematrix.io/json-rpc/http/filecoin_evm',
  // Filecoin calibration
  '0x4cb2f':
      'https://rpc-product.safematrix.io/json-rpc/http/filecoin_calibration_evm',
  // Avalanche
  '0xa86a': 'https://rpc-product.safematrix.io/json-rpc/http/avalanche',
  // Avalance Fuji
  '0xa869': 'https://rpc-product.safematrix.io/json-rpc/http/avalanche_fuji',
  // Optimism
  '0xa': 'https://rpc-product.safematrix.io/json-rpc/http/optimism',
  // Optimism Goerli
  '0x1a4': 'https://rpc-product.safematrix.io/json-rpc/http/optimism_goerli',
  // Arbitrum
  '0xa4b1': 'https://rpc-product.safematrix.io/json-rpc/http/arbitrum',
  // Arbitrum Goerli
  '0x66eed': 'https://rpc-product.safematrix.io/json-rpc/http/arbitrum_goerli',
  // Cronos
  '0x19': 'https://rpc-product.safematrix.io/json-rpc/http/cronos',
  // Cronos Testnet
  '0x152': 'https://rpc-product.safematrix.io/json-rpc/http/cronos_testnet',
  // ETHW
  '0x2711': 'https://rpc-product.safematrix.io/json-rpc/http/ethw',
  // Fantom
  '0xfa': 'https://rpc-product.safematrix.io/json-rpc/http/fantom',
  // Fantom Testnet
  '0xfa2': 'https://rpc-product.safematrix.io/json-rpc/http/fantom_testnet',
  // ZkSync
  '0x144': 'https://rpc-product.safematrix.io/json-rpc/http/zksync',
  // ZkSync Testnet
  '0x118': 'https://rpc-product.safematrix.io/json-rpc/http/zksync_testnet',
  // Bool Testnet
  '0x2f': 'https://rpc-product.safematrix.io/json-rpc/http/bool_testnet',
  // Base Goerli
  '0x14a33': 'https://rpc-product.safematrix.io/json-rpc/http/base_goerli',
  // Base
  '0x2105': 'https://rpc-product.safematrix.io/json-rpc/http/base',
  // Linea testnet
  '0xe704': 'https://rpc-product.safematrix.io/json-rpc/http/linea_testnet',
  // Linea
  '0xe708': 'https://rpc-product.safematrix.io/json-rpc/http/linea',
};

/// develop url
const String developUrl = 'https://test-api.safff.xyz/safff/wallet';

/// prod url
const String prodUrl = 'https://api.safff.xyz/safff/wallet';

/// Ethereum provider, use to connect to sbtauth wallet.
class SbtAuthProvider {
  /// Ethereum provider
  SbtAuthProvider({
    required this.signer,
    required this.clientId,
    required this.isTestnet,
    String? url,
  }) {
    accounts = signer.getAccounts();
    _setupJsonRpcClient();
    _url = url;
  }

  String? _url;

  /// SBTAuth signer
  Signer signer;

  ///  Client id
  late String clientId;

  /// is testnet
  final bool isTestnet;

  /// namespace
  final namespace = 'eip155';

  /// Chain id for the provider, default 0x1
  String chainId = '0x5';

  /// network
  String network = 'eth';

  /// Methods supported
  final methods = _ethSignerMethods;

  /// Provider accounts
  List<String> accounts = [];

  /// JsonRpc client.
  JsonRPC? jsonRpcClient;

  /// Json rpc request
  Future<dynamic> request(RequestArgument arguments) async {
    switch (arguments.method) {
      case 'eth_requestAccounts':
        return accounts;
      case 'eth_accounts':
        return accounts;
      case 'eth_chainId':
        return chainId;
      case 'eth_signTransaction':
        return _signTransaction(arguments);
      case 'eth_sendTransaction':
        return _sendTransaction(arguments);
      case 'personal_sign':
      case 'eth_sign':
        final message = arguments.params[0] as String;
        return signer.personalSign(message);
      default:
        break;
    }
    if (methods.contains(arguments.method)) {
      final typedData = arguments.params[0] as Map<String, dynamic>;
      return signer.signTypedData(typedData);
    }
    try {
      return await jsonRpcClient!.call(arguments.method, arguments.params);
    } catch (error) {
      if (error is RPCError) {
        rethrow;
      }
    }
  }

  /// Send transaction.
  Future<String> sendTransaction({
    required String to,
    required String value,
    String? data,
    String? nonce,
    String? gasPrice,
    String? gasLimit,
    String? maxFeePerGas,
    String? maxPriorityFeePerGas,
    bool useWhiteList = true,
  }) async {
    final transaction = {
      'gasPrice': gasPrice,
      'gasLimit': gasLimit,
      'value': value,
      'to': to,
      'nonce': nonce,
      'data': data,
      'maxFeePerGas': maxFeePerGas,
      'maxPriorityFeePerGas': maxPriorityFeePerGas,
      'useWhiteList': useWhiteList,
    };
    final result = await request(
      RequestArgument(method: 'eth_sendTransaction', params: [transaction]),
    );
    return result as String;
  }

  /// Change privider chainId
  /// @params chainId '0x5'
  void setChainId(
    String chainid, {
    String network = '',
  }) {
    final supported = _ethRpc.keys.contains(chainId);
    if (supported) {
      chainId = chainid;
      _getNetwork(network);
      _setupJsonRpcClient();
    } else {
      throw SbtAuthException('ChainId not supported');
    }
  }

  final Map<String, String> _networkMap = {
    '0x1': 'eth',
    '0x5': 'eth_goerli',
    '0x38': 'bsc',
    '0x61': 'bsc_chapel',
    '0x89': 'polygon',
    '0x13881': 'polygon_mumbai',
    '0x13a': 'filecoin_evm',
    '0x4cb2f': 'filecoin_calibration_evm',
    '0xa86a': 'avalanche',
    '0xa869': 'avalanche_fuji',
    '0xa': 'optimism',
    '0x1a4': 'optimism_goerli',
    '0xa4b1': 'arbitrum',
    '0x66eed': 'arbitrum_goerli',
    '0x19': 'cronos',
    '0x152': 'cronos_testnet',
    '0x2711': 'ethw',
    '0xfa': 'fantom',
    '0xfa2': 'fantom_testnet',
    '0x144': 'zksync',
    '0x118': 'zksync_testnet',
    '0x2f': 'bool_testnet',
    '0x14a33': 'base_goerli',
    '0x2105': 'base',
    '0xe704': 'linea_testnet',
    '0xe708': 'linea',
  };

  void _getNetwork(String chainNetwork) {
    if (chainNetwork != '') {
      network = chainNetwork;
    } else {
      network = _networkMap[chainId] ?? 'eth';
    }
  }

  Future<String> _sendTransaction(RequestArgument argument) async {
    final transaction = await _signTransaction(argument);
    // final response =
    //     await jsonRpcClient!.call('eth_sendRawTransaction', [transaction]);
    // return response.result;
    final api = EvmApi(
      url: _url ?? (isTestnet ? developUrl : prodUrl),
      network: network,
    );
    final hash = await api.sendTransaction(transaction ?? '');
    return hash;
  }

  Future<String?> _signTransaction(RequestArgument argument) async {
    final transaction = argument.params[0] as Map<String, dynamic>;
    await _checkTransaction(transaction);
    var data = transaction['data'] as String;
    var contractAddress = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    var toAddress = transaction['to'] as String;
    var transferValue =
        BigInt.parse(transaction['value'] as String).toRadixString(10);
    if (!data.startsWith('0x')) {
      data = '0x$data';
    }

    /// token transaction
    if (data.startsWith('0xa9059cbb')) {
      toAddress = '0x${data.substring(34, 74)}';
      transferValue = hexToInt(data.substring(74)).toString();
      contractAddress = transaction['to'] as String;
    } else if (data.startsWith('0x5f575529')) {
      /// swap
      // token address
      contractAddress = '0x${data.substring(98, 138)}';
      transferValue = hexToInt(data.substring(138, 202)).toString();
      // swap contract address
      toAddress = transaction['to'] as String;
    } else if (data.startsWith('0x095ea7b3')) {
      /// approve
      // token address
      contractAddress = transaction['to'] as String;
      transferValue = hexToInt(data.substring(74, 138)).toString();
      //contract address
      toAddress = '0x${data.substring(34, 74)}';
    }

    final res = await signer.signTransaction(
      UnsignedTransaction.fromMap(transaction),
      int.parse(chainId),
      (transaction['useWhiteList'] as bool) ? network : null,
      [toAddress],
      transferValue,
      int.parse((transaction['nonce'] ?? '0').toString()),
      contractAddress: contractAddress,
    );
    return res;
  }

  void _setupJsonRpcClient() {
    final rpcUrl = _ethRpc[chainId];
    if (rpcUrl == null) throw SbtAuthError('Chain not supported');
    final httpClient = Client();
    jsonRpcClient = JsonRPC(rpcUrl, httpClient);
  }

  Future<void> _checkTransaction(Map<String, dynamic> transaction) async {
    if (transaction['to'] == null || transaction['value'] == null) {
      throw SbtAuthException('Invalid transaction');
    }
    final to = transaction['to'] as String;
    if (!to.startsWith('0x')) {
      transaction['to'] = '0x$to';
    }
    final value = transaction['value'] as String;
    if (!value.startsWith('0x')) {
      transaction['value'] = '0x$BigInt.parse(value).toRadixString(16)';
    }
    if (transaction['gasPrice'] == null &&
        transaction['maxFeePerGas'] == null &&
        transaction['maxPriorityFeePerGas'] == null) {
      final response = await jsonRpcClient!.call('eth_gasPrice', []);
      transaction['gasPrice'] = response.result;
    }
    if (transaction['nonce'] == null) {
      final response = await jsonRpcClient!
          .call('eth_getTransactionCount', [accounts[0], 'latest']);
      transaction['nonce'] = response.result;
    }
    if (transaction['gasLimit'] == null) {
      final data = transaction['data'] as String?;
      final request = {
        'from': accounts[0],
        'to': transaction['to'],
        'value': transaction['value'],
        'data': (data == null || data == '0x')
            ? null
            : data.startsWith('0x')
                ? data
                : '0x$data',
      };
      final response = await jsonRpcClient!.call('eth_estimateGas', [request]);
      transaction['gasLimit'] = response.result;
    }
  }
}

/// api
class EvmApi {
  ///api
  EvmApi({required this.url, required this.network});

  ///url
  final String url;

  /// net work
  final String network;

  /// send transaction
  Future<String> sendTransaction(String singedData) async {
    final data = {'singedData': singedData, 'network': network};
    final response = await post(
      Uri.parse('${url}transfer'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );
    final hash = _checkResponse(response) as String;
    return hash;
  }

  static dynamic _checkResponse(Response response) {
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['code'] != '000') {
      throw SbtAuthException((body['msg'] ?? '') as String);
    }
    return body['data'];
  }
}
