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
  late Signer signer;

  ///  Client id
  late String clientId;

  /// namespace
  final namespace = 'eip155';

  /// Chain id for the provider, default 0x1
  String chainId = '0x5';

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
  }) async {
    final transaction = {
      'gasPrice': gasPrice,
      'gasLimit': gasLimit,
      'value': value,
      'to': to,
      'data': data
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
      _setupJsonRpcClient();
    } else {
      throw SbtAuthException('ChainId not supported');
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
    return signer.signTransaction(
      UnsignedTransaction.fromMap(transaction),
      int.parse(chainId),
    );
  }

  void _setupJsonRpcClient() {
    final rpcUrl = _ethRpc[chainId];
    if (rpcUrl == null) throw SbtAuthError('Chain not supported');
    final httpClient = Client();
    jsonRpcClient = JsonRPC(rpcUrl, httpClient);
  }

  Future<void> _checkTransaction(Map<String, dynamic> transaction) async {
    if (transaction['nonce'] == null) {
      final response = await jsonRpcClient!
          .call('eth_getTransactionCount', [accounts[0], 'latest']);
      transaction['nonce'] = response.result;
    }
    if (transaction['gasLimit'] == null) {
      final request = {
        'from': accounts[0],
        'to': transaction['to'],
        'value': transaction['value'],
        'data': (transaction['data'] == null || transaction['data'] == '0x')
            ? null
            : transaction['data'],
      };
      final response = await jsonRpcClient!.call('eth_estimateGas', [request]);
      transaction['gasLimit'] = response.result;
    }
  }
}
