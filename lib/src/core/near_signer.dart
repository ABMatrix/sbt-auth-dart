import 'package:eth_sig_util/util/utils.dart';
import 'package:near_api_flutter/near_api_flutter.dart';
import 'package:sbt_auth_dart/src/core/core.dart';
import 'package:solana/base58.dart';

/// default gas
const int defaultGas = 30000000000000;

/// Near Signer
class NearSigner {
  ///need for the account to call methods and create transactions
  NearSigner({
    required this.core,
    this.isTestnet = true,
  });

  /// Whether testnet
  final bool isTestnet;

  /// account id
  String get accountId => core.localShare!.publicKey;

  /// Auth core
  AuthCore core;

  /// public key
  String get publicKey => base58encode(hexToBytes(accountId));

  /// RPC provider
  RPCProvider provider = NEARTestNetRPC();

  /// Transfer near from account to receiver
  Future<Map<dynamic, dynamic>> sendTokens(
    double nearAmount,
    String receiver,
  ) async {
    final accessKey = await findAccessKey();

    // Create Transaction
    accessKey.nonce++;

    final transaction = Transaction(
      signer: accountId,
      publicKey: publicKey,
      nearAmount: nearAmount.toStringAsFixed(12),
      gasFees: defaultGas,
      receiver: receiver,
      methodName: '',
      methodArgs: '',
      accessKey: accessKey,
      actionType: ActionType.transfer,
    );

    // Serialize Transaction
    final serializedTransaction =
        TransactionManager.serializeTransferTransaction(transaction);
    final hashedSerializedTx =
        TransactionManager.toSHA256(serializedTransaction);

    // Sign Transaction
    final hexSignature = await core.signDigest(
      hashedSerializedTx,
      [receiver],
      nearAmount.toString(),
      network: 'near',
      nonce: '',
    );
    final signature = hexToBytes(hexSignature);

    // Serialize Signed Transaction
    final serializedSignedTransaction =
        TransactionManager.serializeSignedTransferTransaction(
      transaction,
      signature,
    );
    final encodedTransaction =
        TransactionManager.encodeSerialization(serializedSignedTransaction)
            as String;

    // Broadcast Transaction
    final res = await provider.broadcastTransaction(encodedTransaction);
    return res;
  }

  /// Calls contract mutate state functions
  Future<Map<dynamic, dynamic>> callFunction(
    String to,
    String contractId,
    String functionName,
    String functionArgs, [
    double nearAmount = 0.0,
    int gasFees = defaultGas,
  ]) async {
    final accessKey = await findAccessKey();

    // Create Transaction
    accessKey.nonce++;

    final transaction = Transaction(
      actionType: ActionType.functionCall,
      signer: accountId,
      publicKey: publicKey,
      nearAmount: nearAmount.toStringAsFixed(12),
      gasFees: gasFees,
      receiver: contractId,
      methodName: functionName,
      methodArgs: functionArgs,
      accessKey: accessKey,
    );

    // Serialize Transaction
    final serializedTransaction =
        TransactionManager.serializeFunctionCallTransaction(transaction);
    final hashedSerializedTx =
        TransactionManager.toSHA256(serializedTransaction);

    // Sign Transaction
    final hexSignature = await core.signDigest(
      hashedSerializedTx,
      [to],
      nearAmount.toString(),
      network: 'near',
      nonce: '',
      contractAddress: contractId,
    );
    final signature = hexToBytes(hexSignature);

    // Serialize Signed Transaction
    final serializedSignedTransaction =
        TransactionManager.serializeSignedFunctionCallTransaction(
      transaction,
      signature,
    );
    final encodedTransaction =
        TransactionManager.encodeSerialization(serializedSignedTransaction)
            as String;

    // Broadcast Transaction
    final res = await provider.broadcastTransaction(encodedTransaction);
    return res;
  }

  /// Gets user accessKey information
  Future<AccessKey> findAccessKey() async {
    final res = await provider.findAccessKey(
      accountId,
      publicKey,
    );
    return res;
  }

  /// Create account
// Future<void> createAccount(
//   String newAccountId,
//   String amount,
//   String publicKey,
// ) async {
//   const config = {
//     'networkId': 'testnet',
//     'nodeUrl': 'https://rpc.testnet.near.org',
//   };
//   final near = Near().providers.jsonRpcProvider('https://rpc.testnet.near.org').callFunction(accountId, methodName, argsBase64);
//   final address = _core.signer.getAccounts();
//   final creatorAccount = await near.account(address);
//   Contract contract = Contract(contractId, account);
//   return await creatorAccount.functionCall({
//     'contractId': 'testnet',
//     'methodName': 'create_account',
//     'args': {
//       'new_account_id': newAccountId,
//       'new_public_key': publicKey,
//     },
//     'gas': '300000000000000',
//     'attachedDeposit': utils.format.parseNearAmount(amount),
//   });
// }
}

class NEARTestNetRPC extends RPCProvider {
  factory NEARTestNetRPC() {
    return _nearTestNetRPCProvider;
  }

  NEARTestNetRPC._internal() : super('https://rpc.testnet.near.org');
  static final NEARTestNetRPC _nearTestNetRPCProvider =
      NEARTestNetRPC._internal();
}
