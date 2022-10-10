// ignore_for_file: implementation_imports
import 'dart:convert';

import 'package:eth_sig_util/eth_sig_util.dart';
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
  String personalSign(String message) {
    final data =
        message.startsWith('0x') ? arrayify(message) : ascii.encode(message);
    return _core.signDigest(hashMessage(data));
  }

  /// Sign typeddata
  String signTypedData(Map<String, dynamic> data) {
    return _core.signDigest(
      TypedDataUtil.hashMessage(
        jsonData: jsonEncode(data),
        version: TypedDataVersion.V4,
      ),
    );
  }

  /// Sign transaction
  String signTransaction(UnsignedTransaction transaction) {
    final chainId = transaction.chainId;
    if (transaction.type == 2 && chainId != null) {
      final encodedTx = LengthTrackingByteSink()
        ..addByte(0x02)
        ..add(rlp.encode(encodeEIP1559ToRlp(transaction)))
        ..close();
      final signature = _core.signDigest(encodedTx.asBytes());
      final result = uint8ListFromList(
        rlp.encode(
          encodeEIP1559ToRlp(transaction, hexToBytes(signature)),
        ),
      );
      return bytesToHex(result);
    } else {
      final encodedTx = LengthTrackingByteSink()
        ..addByte(0x02)
        ..add(rlp.encode(encodeToRlp(transaction)))
        ..close();
      final signature = _core.signDigest(encodedTx.asBytes());
      final result = uint8ListFromList(
        rlp.encode(
          encodeToRlp(transaction, hexToBytes(signature)),
        ),
      );
      return bytesToHex(result);
    }
  }
}
