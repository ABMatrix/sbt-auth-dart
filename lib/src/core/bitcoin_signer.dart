// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:eth_sig_util/util/utils.dart';
import 'package:flutter_bitcoin/flutter_bitcoin.dart';
import 'package:flutter_bitcoin/src/crypto.dart' as bcrypto;
import 'package:flutter_bitcoin/src/utils/script.dart' as bscript;
import 'package:flutter_bitcoin/src/utils/varuint.dart' as varuint;
import 'package:http/http.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

/// bitcoin url
const MAINNET_URL = 'https://api.safff.xyz/safff/';

/// bitcoin test url
const TESTNET_URL = 'https://test-api.safff.xyz/safff/';

/// input rate
const INPUT_RATE = 68;

/// output rate
const OUTPUT_RATE = 31;

/// Bitcoin Signer
class BitcoinSigner {
  /// Bitcoin Signer
  BitcoinSigner(this._core, this._isTestnet, this._isBtc, {String? url}) {
    _url = url;
  }

  final AuthCore _core;

  final bool _isTestnet;

  final bool _isBtc;

  String? _url;

  /// network
  NetworkType get network {
    if (_isTestnet) {
      if (_isBtc) {
        return testnet;
      } else {
        return dogecoinMainnet;
      }
    } else {
      if (_isBtc) {
        return bitcoin;
      } else {
        return dogecoinMainnet;
      }
    }
  }

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
    final txb = TransactionBuilder(network: network)..setVersion(1);
    final btcApi = Api(
      isTestnet: _isTestnet,
      isBtc: _isBtc,
      url: _url ?? (_isTestnet ? TESTNET_URL : MAINNET_URL),
    );
    final utxos = await btcApi.getUtxo(from);
    final result = getUsedUtxos(utxos, amount, feeRate: feeRate);
    final inputUtxos = result[0] as List<Utxo>;
    final left = result[1] as int;
    final p2wpkh = P2WPKH(
      data: PaymentData(pubkey: _core.getPubkey()),
      network: network,
    ).data;
    for (var i = 0; i < inputUtxos.length; i++) {
      txb.addInput(
        inputUtxos[i].txid,
        inputUtxos[i].vout,
        null,
        network == dogecoinMainnet ? null : p2wpkh.output,
      );
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
        witnessValue:
            network == dogecoinMainnet ? null : int.parse(inputUtxos[i].amount),
        toList: [to],
        amount: amount.toString(),
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
    required this.txHex,
  });

  /// Utxo from map
  factory Utxo.fromMap(Map<String, dynamic> map) {
    return Utxo(
      txid: (map['txid'] ?? '') as String,
      vout: (map['vout'] ?? '0') as int,
      amount: (map['amount'] ?? '0') as String,
      confirmations: (map['confirmations'] ?? 0) as int,
      script: (map['script'] ?? '') as String,
      txHex: (map['txHex']) as String?,
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

  /// txHex
  final String? txHex;
}

/// bitcoin api
class Api {
  ///api
  Api({
    required this.isTestnet,
    required this.isBtc,
    required this.url,
  });

  /// is testnet
  final bool isTestnet;

  /// is btc
  final bool isBtc;

  /// url
  final String url;

  String get _network {
    if (isTestnet) {
      if (isBtc) {
        return 'btc_testnet';
      } else {
        return 'dogecoin';
      }
    } else {
      if (isBtc) {
        return 'btc';
      } else {
        return 'dogecoin';
      }
    }
  }

  /// get utxo
  Future<List<Utxo>> getUtxo(String address) async {
    final network = _network;
    final response = await get(
      Uri.parse(
        '${url}wallet/unspent?address=$address&network=$network',
      ),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
    );
    final data = _checkResponse(response) as List;
    return [for (final i in data) Utxo.fromMap(i as Map<String, dynamic>)];
  }

  /// send transaction
  Future<String> sendTransaction(String singedData) async {
    final network = _network;
    final data = {'singedData': singedData, 'network': network};
    final response = await post(
      Uri.parse('$url/wallet/transfer'),
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

  String get _network {
    if (network == bitcoin) {
      return 'btc';
    } else if (network == testnet) {
      return 'btc_testnet';
    } else if (network == dogecoinMainnet) {
      return 'dogecoin';
    } else if (network == dogecoinTestnet) {
      return 'dogecoin';
    } else {
      return '';
    }
  }

  /// maximumFeeRate
  late int maximumFeeRate;
  late List<Input> _inputs;
  late Transaction _tx;
  final Map<dynamic, dynamic> _prevTxSet = {};

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
    return _tx.addOutput(scriptPubKey, value);
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
    required List<String> toList,
    required String amount,
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
      if (witnessValue != null) {
        input
          ..prevOutType = 'witnesspubkeyhash'
          ..hasWitness = true
          ..signatures = [null]
          ..pubkeys = [pubkey]
          ..signScript =
              P2PKH(data: PaymentData(pubkey: pubkey), network: network)
                  .data
                  .output;
      } else {
        final prevOutScript = pubkeyToOutputScript(pubkey, network);
        input
          ..prevOutType = 'pubkeyhash'
          ..signatures = [null]
          ..pubkeys = [pubkey]
          ..signScript = prevOutScript;
      }
    }
    Uint8List signatureHash;
    if (input.hasWitness ?? false) {
      signatureHash = _tx.hashForWitnessV0(
        vin,
        input.signScript!,
        input.value!,
        hashType,
      ) as Uint8List;
      // signatureHash = _hashForWitnessV0(
      //   vin,
      //   input.signScript!,
      //   input.value!,
      //   hashType,
      //   tx,
      // );
    } else {
      signatureHash = _tx.hashForSignature(
        vin,
        input.signScript!,
        hashType,
      ) as Uint8List;
      // signatureHash = _hashForSignature(
      //   vin,
      //   input.signScript!,
      //   hashType,
      //   tx,
      // );
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

      final signature = await core.signDigest(
        signatureHash,
        network: _network,
        toList,
        amount,
      );
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

  Uint8List _hashForWitnessV0(
    int inIndex,
    Uint8List prevOutScript,
    int value,
    int hashType,
    Transaction tx,
  ) {
    var tbuffer = Uint8List.fromList([]);
    var toffset = 0;
    // Any changes made to the ByteData will also change the buffer, and vice versa.
    // https://api.dart.dev/stable/2.7.1/dart-typed_data/ByteBuffer/asByteData.html
    ByteData bytes = tbuffer.buffer.asByteData();
    var hashOutputs = ZERO;
    var hashPrevouts = ZERO;
    var hashSequence = ZERO;

    writeSlice(Iterable<int> slice) {
      tbuffer.setRange(
          toffset, (toffset + (slice.length)), slice);
      toffset += slice.length;
    }

    // writeUInt8(int i) {
    //   bytes.setUint8(toffset, i);
    //   toffset++;
    // }

    writeUInt32(int i) {
      bytes.setUint32(toffset, i, Endian.little);
      toffset += 4;
    }

    // writeInt32(i) {
    //   bytes.setInt32(toffset, i as int, Endian.little);
    //   toffset += 4;
    // }

    void writeUInt64(int i) {
      bytes.setUint64(toffset, i, Endian.little);
      toffset += 8;
    }

    void writeVarInt(int i) {
      varuint.encode(i, tbuffer, toffset);
      toffset += varuint.encodingLength(i);
    }

    void writeVarSlice(Iterable<int> slice) {
      writeVarInt(slice.length);
      writeSlice(slice);
    }

    // writeVector(vector) {
    //   writeVarInt(vector.length);
    //   vector.forEach((buf) {
    //     writeVarSlice(buf);
    //   });
    // }

    if ((hashType & SIGHASH_ANYONECANPAY) == 0) {
      tbuffer = Uint8List(36 * tx.ins.length);
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;

      for (final txIn in tx.ins) {
        writeSlice(txIn!.hash!);
        writeUInt32(txIn.index!);
      }
      hashPrevouts = bcrypto.hash256(tbuffer);
    }

    if ((hashType & SIGHASH_ANYONECANPAY) == 0 &&
        (hashType & 0x1f) != SIGHASH_SINGLE &&
        (hashType & 0x1f) != SIGHASH_NONE) {
      tbuffer = Uint8List(4 * tx.ins.length);
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;
      for (final txIn in tx.ins) {
        writeUInt32(txIn!.sequence!);
      }
      hashSequence = bcrypto.hash256(tbuffer);
    }

    if ((hashType & 0x1f) != SIGHASH_SINGLE &&
        (hashType & 0x1f) != SIGHASH_NONE) {
      final txOutsSize = tx.outs.fold(
          0, (sum, output) => (sum) + 8 + varSliceSize(output.script!));
      tbuffer = Uint8List(txOutsSize);
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;
      for (final txOut in tx.outs) {
        writeUInt64(txOut.value!);
        writeVarSlice(txOut.script!);
      }
      hashOutputs = bcrypto.hash256(tbuffer);
    } else if ((hashType & 0x1f) == SIGHASH_SINGLE &&
        inIndex < tx.outs.length) {
      // SIGHASH_SINGLE only hash that according output
      final output = tx.outs[inIndex];
      tbuffer = Uint8List(8 + varSliceSize(output.script!));
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;
      writeUInt64(output.value!);
      writeVarSlice(output.script!);
      hashOutputs = bcrypto.hash256(tbuffer);
    }

    tbuffer = Uint8List(156 + varSliceSize(prevOutScript));
    bytes = tbuffer.buffer.asByteData();
    toffset = 0;
    final input = tx.ins[inIndex];
    writeUInt32(tx.version);
    writeSlice(hashPrevouts);
    writeSlice(hashSequence);
    writeSlice(input!.hash!);
    writeUInt32(input.index!);
    writeVarSlice(prevOutScript);
    writeUInt64(value);
    writeUInt32(input.sequence!);
    writeSlice(hashOutputs);
    writeUInt32(tx.locktime);
    writeUInt32(hashType);

    return tbuffer;
  }

  Uint8List _hashForSignature(
      int inIndex, Uint8List prevOutScript, int hashType, Transaction tx) {
    if (inIndex >= tx.ins.length) return Uint8List.fromList(ONE);
    // ignore OP_CODESEPARATOR
    final ourScript =
        bscript.compile(bscript.decompile(prevOutScript)!.where((x) {
      return x != 0xab;
    }).toList());
    final txTmp = Transaction.clone(tx);
    // SIGHASH_NONE: ignore all outputs? (wildcard payee)
    if ((hashType & 0x1f) == SIGHASH_NONE) {
      txTmp.outs = [];
      // ignore sequence numbers (except at inIndex)
      for (var i = 0; i < txTmp.ins.length; i++) {
        if (i != inIndex) {
          txTmp.ins[i]?.sequence = 0;
        }
      }

      // SIGHASH_SINGLE: ignore all outputs, except at the same index?
    } else if ((hashType & 0x1f) == SIGHASH_SINGLE) {
      // https://github.com/bitcoin/bitcoin/blob/master/src/test/sighash_tests.cpp#L60
      if (inIndex >= tx.outs.length) return Uint8List.fromList(ONE);

      // truncate outputs after
      txTmp.outs.length = inIndex + 1;

      // 'blank' outputs before
      for (var i = 0; i < inIndex; i++) {
        txTmp.outs[i] = BLANK_OUTPUT;
      }
      // ignore sequence numbers (except at inIndex)
      for (var i = 0; i < txTmp.ins.length; i++) {
        if (i != inIndex) {
          txTmp.ins[i]?.sequence = 0;
        }
      }
    }

    // SIGHASH_ANYONECANPAY: ignore inputs entirely?
    if (hashType & SIGHASH_ANYONECANPAY != 0) {
      txTmp.ins = [txTmp.ins[inIndex]];
      txTmp.ins[0]?.script = ourScript;
      // SIGHASH_ALL: only ignore input scripts
    } else {
      // 'blank' others input scripts
      for (final input in txTmp.ins) {
        input?.script = EMPTY_SCRIPT;
      }
      txTmp.ins[inIndex]?.script = ourScript;
    }
    // serialize and hash
    final buffer = Uint8List(txTmp.virtualSize() + 4);
    buffer.buffer
        .asByteData()
        .setUint32(buffer.length - 4, hashType, Endian.little);
    return buffer;
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
        if (_inputs[i].prevOutType == 'pubkeyhash') {
          final payment = P2PKH(
            data: PaymentData(
                pubkey: _inputs[i].pubkeys?[0],
                signature: _inputs[i].signatures?[0]),
            network: network,
          );
          tx
            ..setInputScript(i, payment.data.input!)
            ..setWitness(i, payment.data.witness);
        } else if (_inputs[i].prevOutType == 'witnesspubkeyhash') {
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
        }
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
    final txHash = bytesToHex(hash);
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
  Map<dynamic, dynamic> get prevTxSet => _prevTxSet;
}
