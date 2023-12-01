import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:aptos/utils/sha.dart';
import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_bitcoin/flutter_bitcoin.dart';
import 'package:flutter_bitcoin/src/crypto.dart' as bcrypto;
import 'package:mpc_dart/mpc_dart.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/signer.dart';
import 'package:sbt_encrypt/sbt_encrypt.dart';
import 'package:solana/base58.dart';
import 'package:web3dart/crypto.dart';

const _messagePrefix = '\u0019Ethereum Signed Message:\n';

/// Check private key format
bool validPrivateKey(String privateKey) {
  final regexp = RegExp(r'^[A-Fa-f0-9]{32,64}$');
  return regexp.hasMatch(privateKey);
}

/// Uint8ListFromList
Uint8List uint8ListFromList(List<int> data) {
  if (data is Uint8List) return data;
  return Uint8List.fromList(data);
}

/// Convert keypair to share
Share keyToShare(MultiKeypair key) {
  return Share(
    privateKey: key.sk,
    publicKey: key.pk,
    extraData: jsonEncode(key.aux),
  );
}

/// Convert share to keypair
MultiKeypair shareToKey(Share share, {int index = 1}) {
  return MultiKeypair(
    sk: share.privateKey,
    pk: share.publicKey,
    partyInd: index,
    threshold: 1,
    sharCount: 3,
    aux: jsonDecode(share.extraData) as Map<String, dynamic>,
  );
}

/// Keccak hash
Uint8List hashMessage(Uint8List message) {
  final prefix = _messagePrefix + message.length.toString();
  final prefixBytes = ascii.encode(prefix);
  return keccak256(Uint8List.fromList(prefixBytes + message));
}

/// Keccak hash
Uint8List uit8Message(Uint8List message) {
  final prefix = _messagePrefix + message.length.toString();
  final prefixBytes = ascii.encode(prefix);
  return Uint8List.fromList(prefixBytes + message);
}

/// Rpc encoder for EIP1559 transaction.
List<dynamic> encodeEIP1559ToRlp(
  UnsignedTransaction transaction,
  int chainId, [
  Signature? signature,
]) {
  final list = [
    BigInt.from(chainId),
    int.parse(transaction.nonce!),
    BigInt.parse(transaction.maxPriorityFeePerGas!),
    BigInt.parse(transaction.maxFeePerGas!),
    int.parse(transaction.gasLimit!),
  ];

  if (transaction.to != null) {
    list.add(hexToBytes(transaction.to!));
  } else {
    list.add('');
  }

  list
    ..add(BigInt.parse(transaction.value!))
    ..add(transaction.data == null ? [0] : hexToBytes(transaction.data!))
    ..add([]); // access list

  if (signature != null) {
    list
      ..add(signature.v)
      ..add(signature.rValue)
      ..add(signature.sValue);
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

/// Pad Unit8 To 32
Uint8List padUnit8ListTo32(Uint8List data) {
  assert(data.length <= 32, 'Wrong data length');
  if (data.length == 32) return data;
  return Uint8List(32)..setRange(32 - data.length, 32, data);
}

/// Parse unit
BigInt parseUnit(String amount, {int decimals = 18}) {
  return (Decimal.parse(amount) *
          Decimal.parse(math.pow(10, decimals).toString()))
      .toBigInt();
}

/// Bigint to hex string
String bigIntToHex(BigInt input) {
  return '0x${input.toRadixString(16)}';
}

/// Get device name
Future<String> getDeviceName() async {
  var deviceName = DBUtil.deviceNameBox.get(DEVICE_KEY);
  if (deviceName == null) {
    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.appName;
    final packageName = packageInfo.packageName;
    deviceName =
        '''${Platform.operatingSystem}${Platform.operatingSystemVersion}-$appName-$packageName''';
    await DBUtil.tokenBox.put(DEVICE_KEY, deviceName);
  }

  return deviceName;
}

/// Encrypt
Future<String> encryptMsg(String msg, String password) async {
  final encprypted = await encrypt(msg, password);
  return encprypted;
}

/// Decrypt
Future<String> decryptMsg(String encrypted, String password) async {
  try {
    final decrypted = await decrypt(encrypted, password);
    return decrypted;
  } catch (e) {
    throw SbtAuthException('Verification Code error');
  }
}

/// List to hex
String listToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final part in bytes) {
    if (part & 0xff != part) {
      throw const FormatException('Non-byte integer detected');
    }
    buffer.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
  }
  return '0x$buffer';
}

/// dogecoin testnet
final dogecoinTestnet = NetworkType(
  messagePrefix: '\u0019DOgecoin Signed Message:\n',
  bech32: 'doge',
  bip32: Bip32Type(public: 0x043587CF, private: 0x04358394),
  pubKeyHash: 0x71,
  scriptHash: 0xC4,
  wif: 0xF1,
);

/// dogecoin mainnet
final dogecoinMainnet = NetworkType(
  messagePrefix: '\u0019Dogecoin Signed Message:\n',
  bech32: 'doge',
  bip32: Bip32Type(public: 0x02FACAFD, private: 0x02FAC398),
  pubKeyHash: 0x1E,
  scriptHash: 0x16,
  wif: 0x9E,
);

/// Get aptos address
String aptosAddressFromPubKey(String pubKey) {
  final pubKeyBytes = hexToBytes(pubKey);
  final emptyList = <int>[...pubKeyBytes, 0];
  final bytes = Uint8List.fromList(emptyList);
  final hash = sha3Hash.process(bytes);
  final address = bytesToHex(hash);
  return '0x$address';
}

/// Get near address
String nearAddressFromPubKey(String pubKey) {
  return pubKey.substring(2);
}

/// 将公钥转换为Tron地址
String tronPublicKeyToAddress(String pubKey) {
  // 1. 使用keccak256函数哈希公钥，并提取结果的最后20个字节。
  // 2. 将41添加到字节数组的开头。 初始地址的长度应为21个字节。
  var publicKeyBytes = decompressPublicKey(hexToBytes(pubKey.substring(2)));
  if (publicKeyBytes.length == 65) publicKeyBytes = publicKeyBytes.sublist(1);
  final hashedPublicKey = keccak256(Uint8List.fromList(publicKeyBytes));
  final addressBytes = [
    0x41,
    ...hashedPublicKey.sublist(hashedPublicKey.length - 20),
  ];
  // 3. 使用sha256函数对地址进行两次哈希，并将前4个字节作为验证码。
  final doubleHashedAddress =
      sha256.convert(sha256.convert(addressBytes).bytes).bytes;
  final checksum = doubleHashedAddress.sublist(0, 4);
  // 4. 将验证码添加到初始地址的末尾，并通过base58编码获取base58check格式的地址。
  // 5. 编码的主网地址以T开头，长度为34个字节。
  addressBytes.addAll(checksum);
  final base58checkAddress = base58encode(addressBytes);
  return base58checkAddress;
}

/// Save friend share
void saveFriendShare(String userId, String shareData) {
  DBUtil.friendShareBox.put(userId, shareData);
}

/// Get friend share
String? getFriendShare(String userId) {
  return DBUtil.friendShareBox.get(userId);
}

///To WIF
String toWif(String key, {bool isBtc = true}) {
  if (key.startsWith('0x')) {
    key = key.substring(2);
  }
  final initKey = isBtc ? '80${key}01' : '9e${key}01';
  final hash1 = bcrypto.hash256(hexToBytes(initKey));
  final hexHash = listToHex(hash1).substring(2, 10);
  final hexKey = '$initKey$hexHash';
  return base58encode(hexToBytes(hexKey));
}
