// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:web3dart/crypto.dart';

class UnsignedTransaction {
  UnsignedTransaction(
    this.to,
    this.nonce,
    this.gasLimit,
    this.gasPrice,
    this.data,
    this.value,
    this.chainId,
    this.type,
    this.accessList,
    this.maxPriorityFeePerGas,
    this.maxFeePerGas,
    this.maxGas,
  );

  factory UnsignedTransaction.fromMap(Map<String, dynamic> map) {
    return UnsignedTransaction(
      map['to'] as String?,
      map['nonce'] as int?,
      map['gasLimit'] as String?,
      map['gasPrice'] as String?,
      map['data'] as String?,
      map['value'] as String?,
      map['chainId'] as int?,
      map['type'] as int?,
      map['accessList'] as List<String>?,
      map['maxPriorityFeePerGas'] as String?,
      map['maxFeePerGas'] as String?,
      map['maxGas'] as String?,
    );
  }

  late String? to;
  late int? nonce;
  String? gasLimit;
  String? gasPrice;
  String? data;
  String? value;
  int? chainId;
  // Typed-Transaction features
  int? type;

  // EIP-2930; Type 1 & EIP-1559; Type 2
  List<String>? accessList;

  // EIP-1559; Type 2
  String? maxPriorityFeePerGas;
  String? maxFeePerGas;
  String? maxGas;
}

/// Signatures used to sign Ethereum transactions and messages.
class Signature {
  Signature(this.r, this.s, this.v);
  factory Signature.from(Uint8List signature) {
    Uint8List r;
    Uint8List s;
    int v;
    // Get the r, s and v
    r = signature.sublist(0, 32);
    s = signature.sublist(32, 64);
    v = signature[64];
    return Signature(
      BigInt.parse(bytesToHex(r)),
      BigInt.parse(bytesToHex(s)),
      v,
    );
  }
  final BigInt r;
  final BigInt s;
  final int v;
}
