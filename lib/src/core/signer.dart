// ignore_for_file: implementation_imports
import 'dart:convert';

import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:flutter/foundation.dart';
import 'package:sbt_auth_dart/src/core/core.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';
import 'package:sbt_auth_dart/src/utils.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/src/utils/length_tracking_byte_sink.dart';
import 'package:web3dart/src/utils/rlp.dart' as rlp;

/// Signer
class Signer {
  /// Signer
  Signer(this._core);

  final AuthCore _core;

  /// Get accounts, multi account is not supported, return account list with
  /// only one address
  List<String> getAccounts() {
    return [_core.getAddress()];
  }

  /// Sign message
  Future<String> personalSign(String message) async {
    final data =
        message.startsWith('0x') ? hexToBytes(message) : ascii.encode(message);
    final res = await _core.signDigest(
      uit8Message(data),
      [],
      '',
      network: '',
    );
    return res;
  }

  /// Sign type data
  Future<String> signTypedData(Map<String, dynamic> data) async {
    final res = await _core.signDigest(
      TypedDataUtil.hashMessage(
        jsonData: jsonEncode(data),
        version: TypedDataVersion.V4,
      ),
      [],
      '',
      network: '',
    );
    return res;
  }

  /// Sign transaction
  Future<String> signTransaction(
    UnsignedTransaction transaction,
    int chainId,
    String? network,
    List<String> toList,
    String amount,
    int nonce, {
    String? contractAddress,
  }) async {
    if (transaction.maxFeePerGas != null ||
        transaction.maxPriorityFeePerGas != null) {
      final encodedTx = LengthTrackingByteSink()
        ..addByte(0x02)
        ..add(rlp.encode(encodeEIP1559ToRlp(transaction, chainId)))
        ..close();
      final signature = await _core.signTransaction(
        encodedTx.asBytes(),
        toList,
        amount,
        contractAddress: contractAddress,
        chainId: chainId,
        network: network,
        isEIP1559: true,
        nonce: nonce,
      );
      final result = [0x02] +
          uint8ListFromList(
            rlp.encode(
              encodeEIP1559ToRlp(transaction, chainId, signature),
            ),
          );
      return bytesToHex(result, include0x: true);
    } else {
      final innerSignature =
          Signature(Uint8List.fromList([0]), Uint8List.fromList([0]), chainId);
      final encodedTx = uint8ListFromList(
        rlp.encode(
          encodeToRlp(
            transaction,
            innerSignature,
          ),
        ),
      );
      final signature = await _core.signTransaction(
        encodedTx,
        toList,
        amount,
        contractAddress: contractAddress,
        chainId: chainId,
        network: network,
        nonce: nonce,
      );
      final result = uint8ListFromList(
        rlp.encode(
          encodeToRlp(transaction, signature),
        ),
      );
      return bytesToHex(result, include0x: true);
    }
  }
}
