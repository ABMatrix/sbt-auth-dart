import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/api.dart';
import 'package:sbt_auth_dart/utils.dart';
import 'package:web3dart/crypto.dart';

/// SBTAuth apis
class SbtAuthApi {
  /// SBTAuth apis used inside project.
  SbtAuthApi({required String baseUrl}) {
    _baseUrl = baseUrl;
  }

  static late DBUtil _dbUtil;

  /// Init
  static Future<void> init() async {
    _dbUtil = await DBUtil.getInstance();
  }

  String? get _token => _dbUtil.tokenBox.get(TOKEN_KEY);
  late String _baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'authorization': 'Bearer $_token'
      };

  /// Send email verification code
  static Future<void> sendEmailCode({
    required String email,
    required String baseUrl,
  }) async {
    final data = {'emailAddress': email};
    final response = await http.post(
      Uri.parse('$baseUrl/user:auth-code'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
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
      },
      body: jsonEncode(data),
    );
    final token = _checkResponse(response) as String;
    return token;
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
    final data = {'emailAddress': password};
    final response = await http.put(Uri.parse('$_baseUrl/user/user'),
        headers: _headers, body: jsonEncode(data));
    _checkResponse(response);
  }

  /// Reset password
  Future<void> resetPassword(
      String emailAddress, String authCode, String password) async {
    final data = {
      'emailAddress': emailAddress,
      'authCode': authCode,
      'password': password
    };
    final response = await http.post(Uri.parse('$_baseUrl/user/reset:password'),
        headers: _headers, body: jsonEncode(data));
    _checkResponse(response);
  }

  /// Upload shares.
  Future<void> uploadShares(
      String clientId, List<Share> shares, String address) async {
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
  Future<RemoteShareInfo> fetchRemoteShare(String clientId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/private-key-fragment-info?clientID=$clientId'),
      headers: _headers,
    );
    final result = _checkResponse(response) as Map<String, dynamic>;
    final address = result['privateKeyFragmentInfoPublicKeyAddress'] as String;
    final share = result['privateKeyFragmentInfoPrivateKey2Fragment'] as String;
    final remote = Share.fromMap(jsonDecode(share) as Map<String, dynamic>);
    return RemoteShareInfo(address, remote);
  }

  /// Backup share via email
  Future<void> backupShare(String privateKey, String email) async {
    final params = {'emailAddress': email, 'privateKey3Fragment': privateKey};
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

  static dynamic _checkResponse(Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != '000') {
      throw SbtAuthException((body['msg'] ?? '') as String);
    }
    return body['data'];
  }
}
