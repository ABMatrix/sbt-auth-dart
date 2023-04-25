import 'dart:typed_data';

import 'package:aptos/aptos_client.dart';
import 'package:aptos/aptos_types/account_address.dart';
import 'package:aptos/aptos_types/authenticator.dart';
import 'package:aptos/aptos_types/ed25519.dart';
import 'package:aptos/aptos_types/transaction.dart';
import 'package:aptos/aptos_types/type_tag.dart';
import 'package:aptos/bcs/helper.dart';
import 'package:aptos/transaction_builder/builder.dart';
import 'package:eth_sig_util/util/utils.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

/// Aptos Signer
class AptosSigner {
  /// Aptos Signer
  AptosSigner(this._core, this._isTestnet);

  final AuthCore _core;

  final bool _isTestnet;

  AptosClient get _client => AptosClient(
        _isTestnet
            ? 'https://aptos-testnet-rpc.allthatnode.com/v1'
            : 'https://aptos-mainnet-rpc.allthatnode.com/v1',
        enableDebugLog: _isTestnet,
      );

  Future<Uint8List> _sign(
    Uint8List signingMessage,
    String receiverAddress,
    String amount, {
    String? contractAddress,
    int? nonce,
  }) async {
    final res = await _core.signDigest(
      signingMessage,
      network: _isTestnet ? 'aptos_testnet' : 'aptos',
      [receiverAddress],
      amount,
      contractAddress: contractAddress,
      nonce: nonce,
    );
    return hexToBytes(res);
  }

  /// Transaction apt
  Future<String> transfer(
    String from,
    String to,
    BigInt amount, {
    BigInt? maxGasAmount,
    BigInt? gasUnitPrice,
    BigInt? expireTimestamp,
    String? coinType,
  }) async {
    coinType ??= AptosClient.APTOS_COIN;

    final isExists = await _client.accountExist(to);
    final func =
        isExists ? '0x1::coin::transfer' : '0x1::aptos_account::transfer_coins';

    final config = ABIBuilderConfig(
      sender: from,
      maxGasAmount: maxGasAmount,
      gasUnitPrice: gasUnitPrice,
      expSecFromNow: expireTimestamp,
    );

    final builder = TransactionBuilderRemoteABI(_client, config);
    final rawTxn = await builder.build(
      func,
      [coinType],
      [to, amount],
    );

    final signingMessage = TransactionBuilder.getSigningMessage(rawTxn);
    final signature = await _sign(
      signingMessage,
      to,
      amount.toString(),
      nonce: rawTxn.sequenceNumber.toInt(),
    );

    final authenticator = TransactionAuthenticatorEd25519(
      Ed25519PublicKey(_core.getPubkey()),
      Ed25519Signature(signature),
    );

    final res = SignedTransaction(rawTxn, authenticator);
    final bcsTxn = bcsToBytes(res);

    final resp = await _client.submitSignedBCSTransaction(bcsTxn);
    return (resp['hash'] ?? '') as String;
  }

  /// Token transaction
  Future<String> tokenTransfer(
    String from,
    String to,
    BigInt amount,
    String tokenAddress,
    String tokenName,
  ) async {
    final token =
        TypeTagStruct(StructTag.fromString('$tokenAddress::coins::$tokenName'));
    final resourceType = '0x1::coin::CoinStore<$to::coins::$tokenName>';
    await tokenRegister(to, resourceType);

    final entryFunctionPayload = TransactionPayloadEntryFunction(
      EntryFunction.natural(
        '0x1::coin',
        'transfer',
        [token],
        [bcsToBytes(AccountAddress.fromHex(to)), bcsSerializeUint64(amount)],
      ),
    );

    final rawTxn = await _client.generateRawTransaction(
      from,
      entryFunctionPayload,
    );

    final signingMessage = TransactionBuilder.getSigningMessage(rawTxn);
    final signature = await _sign(
      signingMessage,
      to,
      amount.toString(),
      nonce: rawTxn.sequenceNumber.toInt(),
    );

    final authenticator = TransactionAuthenticatorEd25519(
      Ed25519PublicKey(_core.getPubkey()),
      Ed25519Signature(signature),
    );

    final res = SignedTransaction(rawTxn, authenticator);
    final bcsTxn = bcsToBytes(res);

    final resp = await _client.submitSignedBCSTransaction(bcsTxn);
    return (resp['hash'] ?? '') as String;
  }

  /// Register
  Future<String> registerToken(
    String from,
    String tokenAddress,
    String tokenName,
  ) async {
    final token =
        TypeTagStruct(StructTag.fromString('$tokenAddress::coins::$tokenName'));

    final entryFunctionPayload = TransactionPayloadEntryFunction(
      EntryFunction.natural(
        '0x1::managed_coin',
        'register',
        [token],
        [],
      ),
    );

    final rawTxn = await _client.generateRawTransaction(
      from,
      entryFunctionPayload,
    );

    final signingMessage = TransactionBuilder.getSigningMessage(rawTxn);
    final signature = await _sign(
      signingMessage,
      '',
      '0',
      nonce: rawTxn.sequenceNumber.toInt(),
    );

    final authenticator = TransactionAuthenticatorEd25519(
      Ed25519PublicKey(_core.getPubkey()),
      Ed25519Signature(signature),
    );

    final res = SignedTransaction(rawTxn, authenticator);
    final bcsTxn = bcsToBytes(res);

    final resp = await _client.submitSignedBCSTransaction(bcsTxn);
    return (resp['hash'] ?? '') as String;
  }

  /// whether token register
  Future<void> tokenRegister(String address, String resourceType) async {
    try {
      await _client.getAccountResource(address, resourceType);
    } catch (e) {
      throw SbtAuthException('The recipient has not registered the token');
    }
  }
}
