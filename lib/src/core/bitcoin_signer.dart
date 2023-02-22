import 'dart:convert';
import 'dart:typed_data';

import 'package:eth_sig_util/util/utils.dart';
import 'package:flutter_bitcoin/flutter_bitcoin.dart';
import 'package:http/http.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

/// bitcoin url
const BITCOIN_URL = 'https://api.abmatrix.cn/safff/wallet';

/// bitcoin test url
const BITCOIN_TEST_URL = 'https://test-api.abmatrix.cn/safff/wallet';

/// input rate
const INPUT_RATE = 68;

/// output rate
const OUTPUT_RATE = 31;

/// Bitcoin Signer
class BitcoinSinger {
  /// Bitcoin Signer
  BitcoinSinger(this._core, this._isTestnet);

  final AuthCore _core;

  final bool _isTestnet;

  /// send bitcoin transaction
  Future<String> sendBtcTransaction(
    String from,
    String to,
    int amount, {
    int feeRate = 8,
  }) async {
    if (amount < 1000) {
      throw SbtAuthException('Amount too low');
    }
    final txb = TransactionBuilder(network: _isTestnet ? testnet : bitcoin)
      ..setVersion(1);
    final btcApi = BtcApi(isTestnet: _isTestnet);
    final utxos = await btcApi.getUtxo(from);
    final result = getUsedUtxos(utxos, amount, feeRate: feeRate);
    final inputUtxos = result[0] as List<Utxo>;
    final left = result[1] as int;
    final p2wpkh = P2WPKH(
      data: PaymentData(pubkey: _core.getPubkey()),
      network: _isTestnet ? testnet : bitcoin,
    ).data;
    for (var i = 0; i < inputUtxos.length; i++) {
      txb.addInput(inputUtxos[i].txid, inputUtxos[i].vout, null, p2wpkh.output);
    }
    txb.addOutput(to, amount);
    if (left > 1000) {
      txb.addOutput(from, left);
    }
    for (var i = 0; i < inputUtxos.length; i++) {
      await txb.sbtSign(
        vin: i,
        pubkey: _core.getPubkey(),
        core: _core,
        witnessValue: int.parse(inputUtxos[i].amount),
      );
    }
    final hash = await btcApi.sendTransaction(txb.build().toHex());
    return hash;
  }

  /// get used utxo
  List<dynamic> getUsedUtxos(List<Utxo> utxos, int amount, {int feeRate = 8}) {
    final inputUtxos = <Utxo>[];
    var total = 0;
    var useAmount = 0;
    for (var i = 0; i < utxos.length; i++) {
      inputUtxos.add(utxos[i]);
      useAmount += int.parse(utxos[i].amount);
      final fee = (((INPUT_RATE * inputUtxos.length) + OUTPUT_RATE * 2 + 10.5) *
              feeRate)
          .ceil();
      total = fee + amount;
      if (useAmount >= total) {
        return [inputUtxos, useAmount - total];
      }
    }
    throw SbtAuthException('Not enough utxo found');
  }
}

///Utxo
class Utxo {
  /// Utxo
  Utxo({
    required this.txid,
    required this.vout,
    required this.amount,
    required this.confirmations,
    required this.script,
  });

  /// Utxo from map
  factory Utxo.fromMap(Map<String, dynamic> map) {
    return Utxo(
      txid: (map['txid'] ?? '') as String,
      vout: (map['vout'] ?? '0') as int,
      amount: (map['amount'] ?? '0') as String,
      confirmations: (map['confirmations'] ?? 0) as int,
      script: (map['script'] ?? '') as String,
    );
  }

  /// txid
  final String txid;

  /// vout
  final int vout;

  /// amount
  final String amount;

  /// confirmations
  final int confirmations;

  /// script
  final String script;
}

/// bitcoin api
class BtcApi {
  ///btc api
  BtcApi({required this.isTestnet});

  /// url
  final bool isTestnet;

  /// get utxo
  Future<List<Utxo>> getUtxo(String address) async {
    final url = isTestnet ? BITCOIN_TEST_URL : BITCOIN_URL;
    final network = isTestnet ? 'btc_testnet' : 'bitcoin';
    final response = await get(
      Uri.parse(
        '$url/unspent?address=$address&network=$network',
      ),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
    );
    final data = _checkResponse(response) as List;
    return [for (var i in data) Utxo.fromMap(i as Map<String, dynamic>)];
  }

  /// send transaction
  Future<String> sendTransaction(String singedData) async {
    final url = isTestnet ? BITCOIN_TEST_URL : BITCOIN_URL;
    final network = isTestnet ? 'btc_testnet' : 'bitcoin';
    final data = {'singedData': singedData, 'network': network};
    final response = await post(
      Uri.parse('$url/transfer'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );
    final hash = _checkResponse(response) as String;
    return hash;
  }

  static dynamic _checkResponse(Response response) {
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['code'] != '000') {
      throw SbtAuthException((body['msg'] ?? '') as String);
    }
    return body['data'];
  }
}

/// TransactionBuilder
class TransactionBuilder {
  /// TransactionBuilder
  TransactionBuilder({NetworkType? network, int? maximumFeeRate}) {
    this.network = network ?? bitcoin;
    this.maximumFeeRate = maximumFeeRate ?? 2500;
    _inputs = [];
    _tx = Transaction();
    _tx.version = 2;
  }

  /// TransactionBuilder from transaction
  factory TransactionBuilder.fromTransaction(
    Transaction transaction, [
    NetworkType? network,
  ]) {
    final txb = TransactionBuilder(network: network)
      ..setVersion(transaction.version)
      ..setLockTime(transaction.locktime);
    // Copy outputs (done first to avoid signature invalidation)
    for (final txOut in transaction.outs) {
      txb.addOutput(txOut.script, txOut.value!);
    }

    for (final txIn in transaction.ins) {
      txb._addInputUnsafe(
        txIn!.hash!,
        txIn.index!,
        Input(
          sequence: txIn.sequence,
          script: txIn.script,
          witness: txIn.witness,
        ),
      );
    }

    return txb;
  }

  /// network
  late NetworkType network;

  /// maximumFeeRate
  late int maximumFeeRate;
  late List<Input> _inputs;
  late Transaction _tx;
  final Map _prevTxSet = {};

  /// inputs
  List<Input> get inputs => _inputs;

  /// setVersion
  void setVersion(int version) {
    if (version < 0 || version > 0xFFFFFFFF) {
      throw SbtAuthException(
        'Expected Uint32',
      );
    }
    _tx.version = version;
  }

  ///setLockTime
  void setLockTime(int locktime) {
    if (locktime < 0 || locktime > 0xFFFFFFFF) {
      throw SbtAuthException(
        'Expected Uint32',
      );
    }
    // if any signatures exist, throw
    if (_inputs.map((input) {
      if (input.signatures == null) return false;
      return input.signatures!.map((s) {
        return s != null;
      }).contains(true);
    }).contains(true)) {
      throw SbtAuthException('No, this would invalidate signatures');
    }
    _tx.locktime = locktime;
  }

  /// add out put
  int addOutput(dynamic data, int value) {
    Uint8List scriptPubKey;
    if (data is String) {
      scriptPubKey = Address.addressToOutputScript(data, network);
    } else if (data is Uint8List) {
      scriptPubKey = data;
    } else {
      throw SbtAuthException('Address invalid');
    }
    if (!_canModifyOutputs()) {
      throw SbtAuthException('No, this would invalidate signatures');
    }
    return _tx.addOutput(scriptPubKey as Uint8List, value);
  }

  /// add input
  int addInput(
    dynamic txHash,
    int vout, [
    int? sequence,
    Uint8List? prevOutScript,
  ]) {
    if (!_canModifyInputs()) {
      throw SbtAuthException('No, this would invalidate signatures');
    }
    Uint8List hash;
    int? value;
    if (txHash is String) {
      hash = Uint8List.fromList(hexToBytes(txHash).reversed.toList());
    } else if (txHash is Uint8List) {
      hash = txHash;
    } else if (txHash is Transaction) {
      final txOut = txHash.outs[vout];
      prevOutScript = txOut.script;
      value = txOut.value;
      hash = txHash.getHash();
    } else {
      throw SbtAuthException('txHash invalid');
    }
    return _addInputUnsafe(
      hash,
      vout,
      Input(
        sequence: sequence,
        prevOutScript: prevOutScript,
        value: value,
      ),
    );
  }

  /// sign
  Future<void> sbtSign({
    required int vin,
    required Uint8List pubkey,
    required AuthCore core,
    int? witnessValue,
    int? hashType,
  }) async {
    _tx.version = 2;
    if (vin >= _inputs.length) {
      throw SbtAuthException('No input at index: $vin');
    }
    hashType = hashType ?? SIGHASH_ALL;
    if (_needsOutputs(hashType)) {
      throw SbtAuthException('Transaction needs outputs');
    }
    final input = _inputs[vin];
    if (!_canSign(input)) {
      if (witnessValue != null) {
        input.value = witnessValue;
      }
      input
        ..prevOutType = 'witnesspubkeyhash'
        ..hasWitness = true
        ..signatures = [null]
        ..pubkeys = [pubkey]
        ..signScript =
            P2PKH(data: PaymentData(pubkey: pubkey), network: network)
                .data
                .output;
    }
    Uint8List signatureHash;
    if (input.hasWitness ?? false) {
      signatureHash = _tx.hashForWitnessV0(
        vin,
        input.signScript!,
        input.value!,
        hashType,
      ) as Uint8List;
    } else {
      signatureHash = _tx.hashForSignature(
        vin,
        input.signScript!,
        hashType,
      ) as Uint8List;
    }

    // enforce in order signing of public keys
    var signed = false;
    for (var i = 0; i < input.pubkeys!.length; i++) {
      if (bytesToHex(pubkey).compareTo(bytesToHex(input.pubkeys![i]!)) != 0) {
        continue;
      }
      if (input.signatures?[i] != null) {
        throw SbtAuthException(
          'Signature already exists',
        );
      }

      final signature = await core.signDigest(signatureHash);
      final res = Uint8List.fromList(hexToList(signature)).sublist(0, 64);
      input.signatures?[i] = encodeSignature(res, hashType);
      signed = true;
    }
    if (!signed) throw SbtAuthException('Key pair cannot sign for this input');
  }

  /// hex to list
  List<int> hexToList(String hashHex) {
    var input = hashHex;
    if (hashHex.startsWith('0x')) input = hashHex.substring(2);
    final hash = List<int>.generate(
      input.length ~/ 2,
      (i) => int.parse(input.substring(i * 2, i * 2 + 2), radix: 16),
    );
    return hash;
  }

  /// build
  Transaction build() {
    return _build(false);
  }

  ///build incomplete
  Transaction buildIncomplete() {
    return _build(true);
  }

  Transaction _build(bool allowIncomplete) {
    if (!allowIncomplete) {
      if (_tx.ins.isEmpty) {
        throw SbtAuthException(
          'Transaction has no inputs',
        );
      }
      if (_tx.outs.isEmpty) {
        throw SbtAuthException(
          'Transaction has no outputs',
        );
      }
    }

    final tx = Transaction.clone(_tx);

    for (var i = 0; i < _inputs.length; i++) {
      if (_inputs[i].pubkeys != null &&
          _inputs[i].signatures != null &&
          _inputs[i].pubkeys!.isNotEmpty &&
          _inputs[i].signatures!.isNotEmpty) {
        final payment = P2WPKH(
          data: PaymentData(
            pubkey: _inputs[i].pubkeys?[0],
            signature: _inputs[i].signatures?[0],
          ),
          network: network,
        );
        tx
          ..setInputScript(i, payment.data.input!)
          ..setWitness(i, payment.data.witness);
      } else if (!allowIncomplete) {
        throw SbtAuthException('Transaction is not complete');
      }
    }

    if (!allowIncomplete) {
      // do not rely on this, its merely a last resort
      if (_overMaximumFees(tx.virtualSize())) {
        throw SbtAuthException('Transaction has absurd fees');
      }
    }

    return tx;
  }

  bool _overMaximumFees(int bytes) {
    final incoming = _inputs.fold(0, (cur, acc) => cur + (acc.value ?? 0));
    final outgoing = _tx.outs.fold(0, (cur, acc) => cur + (acc.value ?? 0));
    final fee = incoming - outgoing;
    final feeRate = fee ~/ bytes;
    return feeRate > maximumFeeRate;
  }

  bool _canModifyInputs() {
    return _inputs.every((input) {
      if (input.signatures == null) return true;
      return input.signatures!.every((signature) {
        if (signature == null) return true;
        return _signatureHashType(signature) & SIGHASH_ANYONECANPAY != 0;
      });
    });
  }

  bool _canModifyOutputs() {
    final nInputs = _tx.ins.length;
    final nOutputs = _tx.outs.length;
    return _inputs.every((input) {
      if (input.signatures == null) return true;
      return input.signatures!.every((signature) {
        if (signature == null) return true;
        final hashType = _signatureHashType(signature);
        final hashTypeMod = hashType & 0x1f;
        if (hashTypeMod == SIGHASH_NONE) return true;
        if (hashTypeMod == SIGHASH_SINGLE) {
          // if SIGHASH_SINGLE is set, and nInputs > nOutputs
          // some signatures would be invalidated by the addition
          // of more outputs
          return nInputs <= nOutputs;
        }
        return false;
      });
    });
  }

  bool _needsOutputs(int signingHashType) {
    if (signingHashType == SIGHASH_ALL) {
      return _tx.outs.isEmpty;
    }
    // if inputs are being signed with SIGHASH_NONE, we don't strictly need outputs
    // .build() will fail, but .buildIncomplete() is OK
    return (_tx.outs.isEmpty) &&
        _inputs.map((input) {
          if (input.signatures == null || input.signatures!.isEmpty) {
            return false;
          }
          return input.signatures!.map((signature) {
            if (signature == null) return false; // no signature, no issue
            final hashType = _signatureHashType(signature);
            if (hashType & SIGHASH_NONE != 0) {
              return false; // SIGHASH_NONE doesn't care about outputs
            }
            return true; // SIGHASH_* does care
          }).contains(true);
        }).contains(true);
  }

  bool _canSign(Input input) {
    return input.pubkeys != null &&
        input.signScript != null &&
        input.signatures != null &&
        input.signatures?.length == input.pubkeys?.length &&
        input.pubkeys!.isNotEmpty;
  }

  int _addInputUnsafe(Uint8List hash, int vout, Input options) {
    var txHash = bytesToHex(hash);
    Input input;
    if (isCoinbaseHash(hash)) {
      throw SbtAuthException('coinbase inputs not supported');
    }
    final prevTxOut = '$txHash:$vout';
    if (_prevTxSet[prevTxOut] != null) {
      throw SbtAuthException('Duplicate TxOut: $prevTxOut');
    }
    if (options.script != null) {
      input =
          Input.expandInput(options.script!, options.witness ?? EMPTY_WITNESS)!;
    } else {
      input = Input();
    }
    if (options.value != null) input.value = options.value;
    if (input.prevOutScript == null && options.prevOutScript != null) {
      if (input.pubkeys == null && input.signatures == null) {
        final expanded = Output.expandOutput(options.prevOutScript!);
        if (expanded!.pubkeys != null && expanded.pubkeys!.isNotEmpty) {
          input
            ..pubkeys = expanded.pubkeys
            ..signatures = expanded.signatures;
        }
      }
      input
        ..prevOutScript = options.prevOutScript
        ..prevOutType = 'witnesspubkeyhash';
    }
    final vin = _tx.addInput(hash, vout, options.sequence, options.script);
    _inputs.add(input);
    _prevTxSet[prevTxOut] = true;
    return vin;
  }

  int _signatureHashType(Uint8List buffer) {
    return buffer.buffer.asByteData().getUint8(buffer.length - 1);
  }

  /// tx
  Transaction get tx => _tx;

  /// prevTxSet
  Map get prevTxSet => _prevTxSet;
}
