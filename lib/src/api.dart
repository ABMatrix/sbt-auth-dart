// ignore_for_file: constant_identifier_names
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/types/api.dart';
import 'package:web3dart/crypto.dart';

/// Develop mode base url
const DEVELOP_BASE_URL = 'https://test-api.sbtauth.io/sbt-auth';

/// Production mode base url
const PRODUCTION_BASE_URL = 'https://api.sbtauth.io/sbt-auth';

/// SBTAuth apis
class SbtAuthApi {
  /// SBTAuth apis used inside project.
  SbtAuthApi({
    required String baseUrl,
    required String token,
    required String local,
  }) {
    _baseUrl = baseUrl;
    _token = token;
    _local = local;
  }

  late String _baseUrl;
  late String _token;
  late String _local;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'authorization': 'Bearer $_token',
        'Accept-Language': _local
      };

  /// Send email verification code
  static Future<void> sendEmailCode({
    required String email,
    required String baseUrl,
    String localLan = 'en-US',
  }) async {
    final data = {'emailAddress': email};
    final response = await http.post(
      Uri.parse('$baseUrl/user:auth-code'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept-Language': localLan,
      },
      body: jsonEncode(data),
    );
    _checkResponse(response) as String;
  }

  /// Login with email
  static Future<String> userLogin({
    required String email,
    String? code,
    required String clientId,
    required String baseUrl,
    String? password,
    String localLan = 'en-US',
  }) async {
    final deviceName = await getDeviceName();
    final data = {
      'emailAddress': email,
      'authCode': code,
      'deviceName': deviceName,
      'clientID': clientId,
      'password': password
    };
    final response = await http.post(
      Uri.parse('$baseUrl/user:login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept-Language': localLan,
      },
      body: jsonEncode(data),
    );
    final token = _checkResponse(response) as String;
    return token;
  }

  /// Confirm to login with qrcode on new device
  Future<void> confirmLoginWithQrCode(
    String qrCodeId,
    String encryptedFragment,
  ) async {
    final data = {'qrCodeID': qrCodeId, 'encryptedFragment': encryptedFragment};

    final response = await http.post(
      Uri.parse('$_baseUrl/user/confirm:qrcode'),
      headers: _headers,
      body: jsonEncode(data),
    );

    _checkResponse(response) as Map<String, dynamic>;
  }

  /// Get qrcode status
  Future<QrCodeStatus> getQrCodeStatus(String qrCodeId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/qrcode?qrCodeID=$qrCodeId'),
      headers: _headers,
    );

    final result = _checkResponse(response) as Map<String, dynamic>;
    return QrCodeStatus.fromMap(result);
  }

  /// Get user info.
  Future<UserInfo> getUserInfo() async {
    final response =
        await http.get(Uri.parse('$_baseUrl/user/user'), headers: _headers);

    final user = _checkResponse(response) as Map<String, dynamic>;
    return UserInfo.fromMap(user);
  }

  /// Set user password.
  Future<void> setPassword(String password) async {
    final data = {'password': password};
    final response = await http.put(
      Uri.parse('$_baseUrl/user/user'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Reset password
  Future<void> resetPassword(
    String emailAddress,
    String authCode,
    String password,
  ) async {
    final data = {
      'emailAddress': emailAddress,
      'authCode': authCode,
      'password': password
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/reset:password'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Upload shares.
  Future<void> uploadShares(
    String clientId,
    List<Share> shares,
    String address,
  ) async {
    final params = {
      'clientID': clientId,
      'privateKey2Fragment': jsonEncode(shares[1].toJson()),
      'privateKey1FragmentHash': bytesToHex(
        hashMessage(ascii.encode(jsonEncode(shares[0].toJson()))),
        include0x: true,
      ),
      'privateKey3FragmentHash': bytesToHex(
        hashMessage(ascii.encode(jsonEncode(shares[2].toJson()))),
        include0x: true,
      ),
      'publicKeyAddress': address,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/private-key-fragment-info'),
      headers: _headers,
      body: jsonEncode(params),
    );
    _checkResponse(response);
  }

  /// Fetch remote share
  Future<RemoteShareInfo> fetchRemoteShare() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/private-key-fragment-info'),
      headers: _headers,
    );
    final result = _checkResponse(response) as Map<String, dynamic>;
    final address = result['privateKeyFragmentInfoPublicKeyAddress'] as String;
    final share = result['privateKeyFragmentInfoPrivateKey2Fragment'] as String;
    final remote = Share.fromMap(jsonDecode(share) as Map<String, dynamic>);
    return RemoteShareInfo(address, remote);
  }

  /// Backup share via email
  Future<void> backupShare(String privateKey, String email, String code) async {
    final params = {
      'emailAddress': email,
      'privateKey3Fragment': privateKey,
      'authCode': code
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user:back-up'),
      headers: _headers,
      body: jsonEncode(params),
    );
    _checkResponse(response);
  }

  /// Get userDevice list
  Future<List<Device>> getUserDeviceList() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/devices?pageNo=1&pageSize=9999'),
      headers: _headers,
    );
    final data = _checkResponse(response) as Map<String, dynamic>;
    final items = data['items'] as List?;
    return [
      for (var d in items ?? []) Device.fromMap(d as Map<String, dynamic>)
    ];
  }

  /// Send auth request
  Future<void> sendAuthRequest(String deviceName) async {
    final params = {'oldDeviceName': deviceName};
    final response = await http.post(
      Uri.parse('$_baseUrl/user/apply:auth'),
      headers: _headers,
      body: jsonEncode(params),
    );
    _checkResponse(response);
  }

  /// Approve auth request
  Future<void> approveAuthRequest(String deviceName, String encrypted) async {
    final params = {
      'newDeviceName': deviceName,
      'encryptedFragment': encrypted,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/confirm:auth'),
      headers: _headers,
      body: jsonEncode(params),
    );
    _checkResponse(response);
  }

  /// Confirm event received
  Future<void> confirmEventReceived(String eventID, String eventType) async {
    final deviceName = await getDeviceName();
    final params = {
      'deviceName': deviceName,
      'eventType': eventType,
      'eventID': eventID,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/receive:auth'),
      headers: _headers,
      body: jsonEncode(params),
    );
    _checkResponse(response);
  }

  /// Verify identity
  Future<void> verifyIdentity(Share share) async {
    final data = {
      'privateKeyFragmentHash': bytesToHex(
        hashMessage(ascii.encode(jsonEncode(share.toJson()))),
        include0x: true,
      ),
      'type': 'PRIVATE_KEY1'
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/verify:identity'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  static dynamic _checkResponse(Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['code'] != '000') {
      throw SbtAuthException((body['msg'] ?? '') as String);
    }
    return body['data'];
  }
}
