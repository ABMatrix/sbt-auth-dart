import 'dart:typed_data';

import 'package:aptos/aptos_account.dart';
import 'package:aptos/aptos_client.dart';
import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/authenticator.dart';
import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/coin_client.dart';
import 'package:aptos/constants.dart';
import 'package:aptos/hex_string.dart';
import 'package:aptos/models/payload.dart';
import 'package:aptos/models/signature.dart';
import 'package:aptos/models/transaction.dart';
import 'package:aptos/transaction_builder/builder.dart';
import 'package:eth_sig_util/util/utils.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class AptosSigner {
  /// Aptos Signer
  AptosSigner(this._core, this._isTestnet);

  final AuthCore _core;

  final bool _isTestnet;

  Future<Uint8List> _sign(
      Uint8List signingMessage, String receiverAddress, String amount,
      {String? contractAddress}) async {
    final res = await _core.signDigest(
      signingMessage,
      network: _isTestnet ? 'aptos' : 'aptos_testnet',
      [receiverAddress],
      amount,
      contractAddress: contractAddress,
    );
    return hexToBytes(res);
  }

  // /// transfer
  // Future<String> transfer(
  //   String receiverAddress,
  //   BigInt amount,
  //   // BigInt gasPrice,
  //   // BigInt maxGasAmount,
  //   // BigInt expirationTimestamp,
  //   String sender,
  // ) async {
  //   final aptos = AptosClient(Constants.testnetAPI, enableDebugLog: true);
  //   final accountInfo = await aptos.getAccount(sender);
  //   final ledgerInfo = await aptos.getLedgerInfo();
  //   final sequenceNumber = int.parse(accountInfo.sequenceNumber);
  //
  //   const typeArgs = '0x1::aptos_coin::AptosCoin';
  //   const moduleId = '0x1::coin';
  //   const moduleFunc = 'transfer';
  //   final entryFunc = EntryFunction.natural(
  //     moduleId,
  //     moduleFunc,
  //     [TypeTagStruct(StructTag.fromString(typeArgs))],
  //     [
  //       bcsToBytes(AccountAddress.fromHex(receiverAddress)),
  //       bcsSerializeUint64(amount)
  //     ],
  //   );
  //   final entryFunctionPayload = TransactionPayloadEntryFunction(entryFunc);
  //
  //   final rawTx = RawTransaction(
  //       AccountAddress.fromHex(sender),
  //       BigInt.from(sequenceNumber),
  //       entryFunctionPayload,
  //       maxGasAmount,
  //       gasPrice,
  //       expirationTimestamp,
  //       ChainId(ledgerInfo['chain_id'] as int));
  //
  //   final publicKey = _core.getPubkey();
  //
  //   final txnBuilder = TransactionBuilderEd25519(
  //     Uint8List.fromList(publicKey),
  //     (signingMessage) async => Ed25519Signature(
  //         await _sign(signingMessage, receiverAddress, amount.toString())),
  //   );
  //
  //   final signedTx = txnBuilder.rawToSigned(rawTx);
  //   final txEdd25519 =
  //       signedTx.authenticator as TransactionAuthenticatorEd25519;
  //   final signature = txEdd25519.signature.value;
  //
  //   final tx = TransactionRequest(
  //     sender: sender,
  //     sequenceNumber: sequenceNumber.toString(),
  //     maxGasAmount: maxGasAmount.toString(),
  //     gasUnitPrice: gasPrice.toString(),
  //     expirationTimestampSecs: expirationTimestamp.toString(),
  //     payload: Payload('entry_function_payload', '$moduleId::$moduleFunc',
  //         ['0x1::aptos_coin::AptosCoin'], [receiverAddress, amount.toString()]),
  //     signature: Signature(
  //       'ed25519_signature',
  //       bytesToHex(publicKey),
  //       bytesToHex(signature),
  //     ),
  //   );
  //
  //   final result = await aptos.submitTransaction(tx);
  //   return (result ?? '') as String;
  // }

  Future<String> transfer(
    String from,
    String to,
    BigInt amount, {
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp,
    String? coinType,
    bool createReceiverIfMissing = false,
  }) async {
    final aptosClient = AptosClient(Constants.testnetAPI, enableDebugLog: true);
    coinType ??= AptosClient.APTOS_COIN;

    final func = createReceiverIfMissing
        ? '0x1::aptos_account::transfer_coins'
        : '0x1::coin::transfer';

    final config = ABIBuilderConfig(
        sender: from,
        maxGasAmount: maxGasAmount,
        gasUnitPrice: gasUnitPrice,
        expSecFromNow: expireTimestamp);

    final builder = TransactionBuilderRemoteABI(aptosClient, config);
    final rawTxn = await builder.build(
      func,
      [coinType],
      [to, amount],
    );

    // final txnBuilder = TransactionBuilderEd25519(
    //     _core.getPubkey(),
    //     (Uint8List signingMessage) async => Ed25519Signature(
    //         await _sign(signingMessage, to, amount.toString())));

    final signingMessage = TransactionBuilder.getSigningMessage(rawTxn);
    final signature = await _sign(signingMessage, to, amount.toString());

    final authenticator = TransactionAuthenticatorEd25519(
      Ed25519PublicKey(_core.getPubkey()),
      Ed25519Signature(signature),
    );

    final res = SignedTransaction(rawTxn, authenticator);
    final bcsTxn = bcsToBytes(res);

    final resp = await aptosClient.submitSignedBCSTransaction(bcsTxn);
    return (resp["hash"] ?? '') as String;
  }

  /// Token transaction
  Future<String> tokenTransfer(
    String from,
    String to,
    BigInt amount,
    String tokenAddress,
    String tokenName,
  ) async {
    final client = AptosClient(Constants.testnetAPI, enableDebugLog: true);
    final token = TypeTagStruct(
        StructTag.fromString('$tokenAddress::aptos_coin::$tokenName'));

    final entryFunctionPayload = TransactionPayloadEntryFunction(
      EntryFunction.natural(
        '0x1::coin',
        'transfer',
        [token],
        [bcsToBytes(AccountAddress.fromHex(to)), bcsSerializeUint64(amount)],
      ),
    );

    final rawTxn = await client.generateRawTransaction(
      from,
      entryFunctionPayload,
    );

    final signingMessage = TransactionBuilder.getSigningMessage(rawTxn);
    final signature = await _sign(signingMessage, to, amount.toString());

    final authenticator = TransactionAuthenticatorEd25519(
      Ed25519PublicKey(_core.getPubkey()),
      Ed25519Signature(signature),
    );

    final res = SignedTransaction(rawTxn, authenticator);
    final bcsTxn = bcsToBytes(res);

    final resp = await client.submitSignedBCSTransaction(bcsTxn);
    return (resp["hash"] ?? '') as String;
  }

  Future<dynamic> _transferAptos(
    AptosAccount account,
    String receiverAddress,
    BigInt amount, {
    BigInt? gasPrice,
    BigInt? maxGasAmount,
    BigInt? expirationTimestamp,
  }) async {
    final aptos = AptosClient(Constants.testnetAPI, enableDebugLog: true);
    final coinClient = CoinClient(aptos);
    final txHash = await coinClient.transfer(
      account,
      receiverAddress,
      amount,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasPrice,
      expireTimestamp: expirationTimestamp,
    );
    return txHash;
  }
}
