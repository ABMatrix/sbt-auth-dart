import 'package:http/http.dart';
import 'package:sbt_auth_dart/src/core/core.dart';
import 'package:sbt_auth_dart/src/types/error.dart';
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
  '0x4': 'https://test-rpc-eth.abmatrix.cn',
  '0x38': 'https://rpc-bsc.abmatrix.cn',
  '0x61': 'https://test-rpc-bsc.abmatrix.cn',
  '0x89': 'https://rpc-polygon.abmatrix.cn',
  '0x13881': 'https://test-rpc-polygon.abmatrix.cn/',
};

/// Ethereum provider, use to connect to sbtauth wallet.
class EthereumProvider {
  /// Ethereum provider
  EthereumProvider({
    required this.core,
    required this.clientId,
  }) {
    accounts = [core.getAddress()];
    _setupJsonRpcClient();
  }

  /// SBTAuth core
  late AuthCore core;

  ///  Client id
  late String clientId;

  /// namespace
  final namespace = 'eip155';

  /// Chain id for the provider, default 0x1
  final chainId = '0x1';

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
      case 'personal_sing':
      case 'eth_sign':
        final message = arguments.params[0] as String;
        return core.signer.personalSign(message);
      default:
        break;
    }
    if (methods.contains(arguments.method)) {
      final typedData = arguments.params[0] as Map<String, dynamic>;
      return core.signer.signTypedData(typedData);
    }
    try {
      return await jsonRpcClient!.call(arguments.method, arguments.params);
    } catch (error) {
      if (error is RPCError) {
        rethrow;
      }
    }
  }

  Future<void> _sendTransaction(RequestArgument argument) async {
    final transaction = _signTransaction(argument);
    await jsonRpcClient!.call('eth_sendTransaction', [transaction]);
  }

  String? _signTransaction(RequestArgument argument) {
    final transaction = argument.params[0] as Map<String, dynamic>;
    return core.signer
        .signTransaction(UnsignedTransaction.fromMap(transaction));
  }

  void _setupJsonRpcClient() {
    final rpcUrl = _ethRpc[chainId];
    if (rpcUrl == null) throw SbtAuthError('Chain not supported');
    final httpClient = Client();
    jsonRpcClient = JsonRPC(rpcUrl, httpClient);
  }
}
