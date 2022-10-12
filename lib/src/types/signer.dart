// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:sbt_auth_dart/src/utils.dart';
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
      map['nonce'] as String?,
      map['gasLimit'] as String?,
      map['gasPrice'] as String?,
      map['data'] as String?,
      map['value'] as String?,
      map['chainId'] as int?,
      map['type'] as int?,
      map['accessList'] as List<String>?,
      map['maxPriorityFeePerGas'] as String?,
      map['maxFeePerGas'] as String?,
      map['maxGas'] as int?,
    );
  }

  String? to;
  String? nonce;
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
  int? maxGas;
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
    if (v < 27) {
      if (v == 0 || v == 1) {
        v += 27;
      } else {
        throw Error();
      }
    }
    return Signature(
      r,
      s,
      v,
    );
  }
  int get recoveryParam => 1 - v % 2;

  final Uint8List r;
  final Uint8List s;
  final int v;

  BigInt get rValue => BigInt.parse(bytesToHex(r, include0x: true));
  BigInt get sValue => BigInt.parse(bytesToHex(s, include0x: true));

  Uint8List join() {
    return Uint8List.fromList(
      padUint8ListTo32(r) +
          padUint8ListTo32(s) +
          [if (recoveryParam == 1) 0x1c else 0x1b],
    );
  }

  Signature copyWith({
    Uint8List? r,
    Uint8List? s,
    int? v,
  }) {
    return Signature(
      r ?? this.r,
      s ?? this.s,
      v ?? this.v,
    );
  }
}
