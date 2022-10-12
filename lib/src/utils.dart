import 'dart:convert';
import 'dart:typed_data';

import 'package:mpc_dart/mpc_dart.dart';
import 'package:sbt_auth_dart/src/types/account.dart';
import 'package:sbt_auth_dart/src/types/error.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';
import 'package:web3dart/crypto.dart';

const _messagePrefix = '\u0019Ethereum Signed Message:\n';

/// Check privcate key format
bool validPrivateKey(String privateKey) {
  final regexp = RegExp(r'/^[\dA-Fa-f]{64}$/');
  return regexp.hasMatch(privateKey);
}

/// Uint8ListFromList
Uint8List uint8ListFromList(List<int> data) {
  if (data is Uint8List) return data;
  return Uint8List.fromList(data);
}

/// Convert keypair to share
Share keyToShare(KeyPair key) {
  return Share(
    privateKey: key.x_i,
    extraData: key.y.toJson(),
  );
}

/// Convert share to keypair
KeyPair shareToKey(Share share, [int index = 1]) {
  return KeyPair(
    share.privateKey,
    Coordinate.fromMap(jsonDecode(share.extraData) as Map<String, dynamic>),
    index,
    1,
    3,
  );
}

/// Convert hex string to uint8list
Uint8List arrayify(String value) {
  var input = value;
  if (value.substring(0, 2) != '0x') {
    input = '0x$value';
  }
  return List<int>.generate(
    input.length ~/ 2,
    (i) => int.parse(input.substring(i * 2, i * 2 + 2), radix: 16),
  ) as Uint8List;
}

/// Keccak hash
Uint8List hashMessage(Uint8List message) {
  final prefix = _messagePrefix + message.length.toString();
  final prefixBytes = ascii.encode(prefix);
  return keccak256(Uint8List.fromList(prefixBytes + message));
}

/// Rpc encoder for EIP1559 transaction.
List<dynamic> encodeEIP1559ToRlp(
  UnsignedTransaction transaction, [
  Uint8List? signature,
]) {
  final list = [
    transaction.chainId,
    transaction.nonce,
    BigInt.parse(transaction.maxPriorityFeePerGas!),
    transaction.maxFeePerGas,
    transaction.maxGas,
  ];

  if (transaction.to != null) {
    list.add(transaction.to);
  } else {
    list.add('');
  }

  list
    ..add(transaction.value)
    ..add(transaction.data)
    ..add([]); // access list

  if (signature != null) {
    final msgSignature = Signature.from(signature);
    list
      ..add(msgSignature.v)
      ..add(msgSignature.r)
      ..add(msgSignature.s);
  }
  return list;
}

/// Rlp encoder for legacy transaction.
List<dynamic> encodeToRlp(
  UnsignedTransaction transaction, [
  Signature? signature,
]) {
  if (transaction.gasPrice == null || transaction.to == null) {
    throw SbtAuthError('Transcation format error');
  }
  final list = [
    int.parse(transaction.nonce!),
    BigInt.parse(transaction.gasPrice!),
    int.parse(transaction.gasLimit!),
  ];

  if (transaction.to != null) {
    list.add(hexToBytes(transaction.to!));
  } else {
    list.add('');
  }

  list
    ..add(BigInt.parse(transaction.value!))
    ..add(transaction.data == null ? [0] : hexToBytes(transaction.data!));

  if (signature != null) {
    list
      ..add(signature.v)
      ..add(signature.rValue)
      ..add(signature.sValue);
  }
  return list;
}

/// Pad Uint8 To 32
Uint8List padUint8ListTo32(Uint8List data) {
  assert(data.length <= 32, 'Wrong data length');
  if (data.length == 32) return data;

  // todo there must be a faster way to do this?
  return Uint8List(32)..setRange(32 - data.length, 32, data);
}
