// ignore_for_file: public_member_api_docs

import 'dart:core';

class UnsignedTransaction {
  UnsignedTransaction({
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
  });
  String? to;
  int? nonce;
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
