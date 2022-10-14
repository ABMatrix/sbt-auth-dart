import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/types/api.dart';
import 'package:sbt_auth_dart/src/types/exception.dart';
import 'package:sbt_auth_dart/utils.dart';
import 'package:web3dart/crypto.dart';

/// SBTAuth apis
class SbtAuthApi {
  /// SBTAuth apis used inside project.
  SbtAuthApi({required String token, required String baseUrl}) {
    _token = token;
    _baseUrl = baseUrl;
  }

  late String _token;
  late String _baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'authorization': 'Bearer $_token'
      };

  /// Login with email
  static Future<String> userLogin({
    required String email,
    required String code,
    required String clientId,
    required String baseUrl,
  }) async {
    final deviceName = await getDeviceName();
    final data = {
      'emailAddress': email,
      'authCode': code,
      'deviceName': deviceName,
      'clientID': clientId
    };
    final response = await http.post(
      Uri.parse('$baseUrl/user:login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );
    final token =
        _checkResponse(response) as String;
    return token;
  }

  /// Get user info.
  Future<UserInfo> getUserInfo() async {
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'authorization': 'Bearer $_token'
    };
    final response =
        await http.get(Uri.parse('$_baseUrl/user/user'), headers: headers);

    final user = _checkResponse(response) as Map<String, dynamic>;
    return UserInfo.fromMap(user);
  }

  /// Upload shares.
  Future<void> uploadShares(List<Share> shares, String address) async {
    final params = {
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
  Future<void> backupShare(String privateKey, String email) async {
    final params = {'emailAddress': email, 'privateKey3Fragment': privateKey};
    final response = await http.post(
      Uri.parse('$_baseUrl/user:backup'),
      headers: _headers,
      body: params,
    );
    _checkResponse(response);
  }

  static dynamic _checkResponse(Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != '000') {
      throw SbtAuthException(body['error'] as String);
    }
    return body['data'];
  }
}
