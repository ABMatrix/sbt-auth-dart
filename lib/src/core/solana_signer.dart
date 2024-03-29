import 'dart:typed_data';

import 'package:eth_sig_util/util/utils.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/core/core.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

/// Solana Signer
class SolanaSigner {
  /// Solana Signer
  SolanaSigner(this._core, this._solanaUrl, this._solanaNetwork);

  final AuthCore _core;

  final String _solanaUrl;

  final String _solanaNetwork;

  /// Send transaction
  Future<String> sendTransaction(
    Instruction instruction,
    Ed25519HDPublicKey from,
    String to,
    String amount, {
    String? contractAddress,
  }) async {
    final message = Message(instructions: [instruction]);
    final recentBlockhash = await SbtAuthApi.getRecentBlockhash(_solanaUrl);
    final recentBlockHeight = await SbtAuthApi.getRecentBlockHeight(_solanaUrl);
    final compiledMessage = message.compile(
      recentBlockhash: recentBlockhash,
      feePayer: from,
    );
    final signature = await _core.signDigest(
      Uint8List.fromList(compiledMessage.toByteArray().toList()),
      [to],
      amount,
      contractAddress: contractAddress,
      network: _solanaNetwork,
      nonce: recentBlockHeight,
    );
    final tx = SignedTx(
      compiledMessage: compiledMessage,
      signatures: [Signature(hexToBytes(signature), publicKey: from)],
    );
    final data = ByteArray.merge([
      CompactArray.fromIterable(tx.signatures.map((e) => ByteArray(e.bytes)))
          .toByteArray(),
      tx.compiledMessage.toByteArray(),
    ]);
    final hash = await SbtAuthApi.sendSolanaTransaction(
      _solanaUrl,
      base58encode(data.toList()),
    );
    return hash;
  }

  /// Create Associated TokenAccount
  Future<String> createAssociatedTokenAccount(
    Ed25519HDPublicKey from,
    Ed25519HDPublicKey to,
    Ed25519HDPublicKey tokenAddress,
  ) async {
    final effectiveOwner = to;
    final derivedAddress = await findAssociatedTokenAddress(
      owner: effectiveOwner,
      mint: tokenAddress,
    );
    final instruction = AssociatedTokenAccountInstruction.createAccount(
      mint: tokenAddress,
      address: derivedAddress,
      owner: effectiveOwner,
      funder: from,
    );
    final res = await sendTransaction(instruction, from, to.toBase58(), '0');
    return res;
  }
}

/// compact Array
class CompactArray {
  /// compact Array
  CompactArray(this._data) : _length = CompactU16(_data.length);

  /// compact Array fromIterable
  CompactArray.fromIterable(Iterable<ByteArray> data)
      : _data = ByteArray.merge(data),
        _length = CompactU16(data.length);

  final ByteArray _data;
  final CompactU16 _length;

  /// toByteArray
  ByteArray toByteArray() => ByteArray.merge([_length.toByteArray(), _data]);
}

/// CompactU16
class CompactU16 {
  /// CompactU16
  factory CompactU16(int value) {
    if (value == 0) return zero;

    /// data
    final data = List<int>.empty(growable: true);

    var rawValue = value;
    while (rawValue != 0) {
      final currentByte = rawValue & 0x7f;
      rawValue >>= 7;
      if (rawValue == 0) {
        data.add(currentByte);
      } else {
        data.add(currentByte | 0x80);
      }
    }

    return CompactU16.raw(data);
  }

  /// raw
  const CompactU16.raw(this._data);

  /// zero
  static const zero = CompactU16.raw([0]);

  final List<int> _data;

  /// value
  int get value {
    var len = 0;
    var size = 0;
    for (final elem in _data) {
      len |= (elem & 0x7f) << (size * 7);
      size += 1;
      if ((elem & 0x80) == 0) {
        break;
      }
    }

    return len;
  }

  /// size
  int get size => toByteArray().length;

  /// to byte array
  ByteArray toByteArray() => ByteArray(CompactU16(value)._data);
}
