import 'package:http/http.dart';
import 'package:sbt_auth_dart/src/core/signer.dart';
import 'package:sbt_auth_dart/src/types/error.dart';
import 'package:sbt_auth_dart/src/types/exception.dart';
import 'package:sbt_auth_dart/src/types/provider.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';
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
  '0x1': 'https://rpc-eth.abmatrix.cn',
  '0x5': 'https://test-rpc-eth.abmatrix.cn',
  '0x38': 'https://rpc-bsc.abmatrix.cn',
  '0x61': 'https://test-rpc-bsc.abmatrix.cn',
  '0x89': 'https://rpc-polygon.abmatrix.cn',
  '0x13881': 'https://test-rpc-polygon.abmatrix.cn/',
};

/// Ethereum provider, use to connect to sbtauth wallet.
class SbtAuthProvider {
  /// Ethereum provider
  SbtAuthProvider({
    required this.signer,
    required this.clientId,
  }) {
    accounts = signer.getAccounts();
    _setupJsonRpcClient();
  }

  /// SBTAuth signer
  Signer signer;

  ///  Client id
  late String clientId;

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
    String? gasPrice,
    String? gasLimit,
    String? maxFeePerGas,
    String? maxPriorityFeePerGas,
  }) async {
    final transaction = {
      'gasPrice': gasPrice,
      'gasLimit': gasLimit,
      'value': value,
      'to': to,
      'data': data,
      'maxFeePerGas': maxFeePerGas,
      'maxPriorityFeePerGas': maxPriorityFeePerGas
    };
    final result = await request(
      RequestArgument(method: 'eth_sendTransaction', params: [transaction]),
    );
    return result as String;
  }

  /// Change privider chainId
  /// @params chainId '0x5'
  void setChainId(String chainid) {
    final supported = _ethRpc.keys.contains(chainId);
    if (supported) {
      chainId = chainid;
      _getNetwork();
      _setupJsonRpcClient();
    } else {
      throw SbtAuthException('ChainId not supported');
    }
  }

  void _getNetwork() {
    switch (chainId) {
      case '0x1':
        network = 'eth';
        break;
      case '0x38':
        network = 'bsc';
        break;
      case '0x89':
        network = 'polygon';
        break;
      case '0x5':
        network = 'eth_goerli';
        break;
      case '0x61':
        network = 'bsc_chapel';
        break;
      case '0x13881':
        network = 'polygon_mumbai';
        break;
    }
  }

  Future<void> _sendTransaction(RequestArgument argument) async {
    final transaction = await _signTransaction(argument);
    final response =
        await jsonRpcClient!.call('eth_sendRawTransaction', [transaction]);
    return response.result;
  }

  Future<String?> _signTransaction(RequestArgument argument) async {
    final transaction = argument.params[0] as Map<String, dynamic>;
    await _checkTransaction(transaction);
    final res = await signer.signTransaction(
      UnsignedTransaction.fromMap(transaction),
      int.parse(chainId),
      network,
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
