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

  /// Query user
  static Future<bool> queryUser(
    String email, {
    required String baseUrl,
    required String localLan,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/user:email?email=$email'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept-Language': localLan
      },
    );
    return (_checkResponse(response) ?? false) as bool;
  }

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

  /// Get qrcode
  static Future<String> getLoginQrcode(String baseUrl, String clientID) async {
    final deviceName = await getDeviceName();
    final data = {
      'deviceName': deviceName,
      'clientID': clientID,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/user/create:qrcode'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8'
      },
      body: jsonEncode(data),
    );
    final qrcode = _checkResponse(response) as String;
    return qrcode;
  }

  /// Get qrcode status
  static Future<QrCodeStatus> getQrCodeStatus(
      String baseUrl, String qrCodeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/qrcode?qrCodeID=$qrCodeId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8'
      },
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
  static Future<void> resetPassword(
    String emailAddress,
    String authCode,
    String password,
    String baseUrl,
  ) async {
    final data = {
      'emailAddress': emailAddress,
      'authCode': authCode,
      'password': password
    };
    final response = await http.post(
      Uri.parse('$baseUrl/user/reset:password'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8'
      },
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Upload shares.
  Future<void> uploadShares(
      List<Share> shares, String address, String privateKey2Fragment,
      {String keyType = 'EVM'}) async {
    final params = {
      'privateKey1Fragment': shares[0].extraData,
      'privateKey2Fragment': privateKey2Fragment,
      'privateKey3Fragment': shares[2].extraData,
      'privateKey1FragmentHash': bytesToHex(
        hashMessage(ascii.encode(jsonEncode(shares[0].toJson()))),
        include0x: true,
      ),
      'privateKey3FragmentHash': bytesToHex(
        hashMessage(ascii.encode(jsonEncode(shares[2].toJson()))),
        include0x: true,
      ),
      'publicKeyAddress': address,
      'keyType': keyType
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/private-key-fragment-info'),
      headers: _headers,
      body: jsonEncode(params),
    );
    _checkResponse(response);
  }

  /// Fetch remote share
  Future<RemoteShareInfo> fetchRemoteShare({String keyType = 'EVM'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/private-key-fragment-info?keyType=$keyType'),
      headers: _headers,
    );
    final result = _checkResponse(response) as Map<String, dynamic>;
    final address = result['privateKeyFragmentInfoPublicKeyAddress'] as String;
    final share = result['privateKeyFragmentInfoPrivateKey2Fragment'] as String;
    final localAux =
        (result['privateKeyFragmentInfoPrivateKey1Fragment'] ?? '') as String;
    final backupAux =
        (result['privateKeyFragmentInfoPrivateKey3Fragment'] ?? '') as String;
    final remote = Share.fromMap(jsonDecode(share) as Map<String, dynamic>);
    return RemoteShareInfo(address, remote, localAux, backupAux);
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
  Future<void> sendAuthRequest(String deviceName,
      {String keyType = 'EVM'}) async {
    final params = {'oldDeviceName': deviceName, 'keyType': keyType};
    final response = await http.post(
      Uri.parse('$_baseUrl/user/apply:auth'),
      headers: _headers,
      body: jsonEncode(params),
    );
    _checkResponse(response);
  }

  /// Approve auth request
  Future<void> approveAuthRequest(
      String deviceName, String encrypted, String keyType) async {
    final params = {
      'newDeviceName': deviceName,
      'encryptedFragment': encrypted,
      'keyType': keyType,
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
  Future<void> verifyIdentity(Share share, {String keyType = 'EVM'}) async {
    final data = {
      'privateKeyFragmentHash': bytesToHex(
        hashMessage(ascii.encode(jsonEncode(share.toJson()))),
        include0x: true,
      ),
      'type': 'PRIVATE_KEY1',
      'keyType': keyType
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/verify:identity'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Create user whiteList
  Future<void> createUserWhiteList(
    String email,
    String authCode,
    String address,
    String name,
    String network,
  ) async {
    final data = {
      'email': email,
      'authCode': authCode,
      'address': address,
      'name': name,
      'network': network
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user-whitelist/user-whitelist'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Edit user whiteList
  Future<void> editUserWhiteList(
    String email,
    String authCode,
    String address,
    String name,
    String userWhitelistID,
    String userId,
    String network,
  ) async {
    final data = {
      'email': email,
      'authCode': authCode,
      'address': address,
      'name': name,
      'userWhitelistID': userWhitelistID,
      'userId': userId,
      'network': network
    };
    final response = await http.put(
      Uri.parse('$_baseUrl/user-whitelist/user-whitelist'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Delete user whiteList
  Future<void> deleteUserWhiteList(
    String email,
    String authCode,
    String userWhitelistID,
  ) async {
    final data = {
      'email': email,
      'authCode': authCode,
      'userWhitelistID': userWhitelistID
    };
    final response = await http.delete(
      Uri.parse('$_baseUrl/user-whitelist/user-whitelist'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Get user whiteList
  Future<List<UserWhiteListItem>> getUserWhiteList(
    int pageNo,
    int pageSize, {
    String network = '',
  }) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/user-whitelist/user-whitelists?pageNo=$pageNo&pageSize=$pageSize&network=$network',
      ),
      headers: _headers,
    );
    final data = _checkResponse(response) ?? <String, dynamic>{};
    final items = data['items'] as List?;
    return [
      for (var d in items ?? [])
        UserWhiteListItem.fromMap(d as Map<String, dynamic>)
    ];
  }

  /// Get user whiteList item
  Future<UserWhiteListItem> getUserWhiteListItem(String userWhitelistID) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/user-whitelist/user-whitelist?userWhitelistID=$userWhitelistID',
      ),
      headers: _headers,
    );
    final data = _checkResponse(response) as Map<String, dynamic>;
    return UserWhiteListItem.fromMap(data);
  }

  /// User white list switch
  Future<void> switchUserWhiteList(
    String email,
    String authCode, {
    required bool whitelistSwitch,
  }) async {
    final data = {
      'email': email,
      'authCode': authCode,
      'whitelistSwitch': whitelistSwitch,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/whitelist:switch'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Backup by one drive
  Future<void> backupByOneDrive(
    String code,
    String state,
    String privateKey3Fragment, {
    String keyType = 'EVM',
  }) async {
    final data = {
      'code': code,
      'state': state,
      'privateKey3Fragment': privateKey3Fragment,
      'keyType': keyType
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/user/microsoft:upload-file'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Recover by one drive
  Future<String> recoverByOneDrive(
    String code,
    String state, {
    String keyType = 'EVM',
  }) async {
    final data = {'code': code, 'state': state, 'keyType': keyType};
    final response = await http.post(
      Uri.parse('$_baseUrl/user/microsoft:query-file'),
      headers: _headers,
      body: jsonEncode(data),
    );

    final res = _checkResponse(response) as String;
    return res;
  }

  /// Get ERC20 list
  Future<TokenListInfo> getTokenList(
    int pageNo,
    int pageSize,
    String network,
    String condition,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/token-info/token-infos?pageNo=$pageNo&pageSize=$pageSize&network=$network&condition=$condition',
      ),
      headers: _headers,
    );
    final data = _checkResponse(response) as Map<String, dynamic>;
    return TokenListInfo.fromMap(data);
  }

  /// Import token
  Future<void> importToken(String network, String address) async {
    final data = {'network': network, 'address': address};
    final response = await http.post(
      Uri.parse('$_baseUrl/user-token/import:token'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkResponse(response);
  }

  /// Import token info
  Future<TokenInfo> importTokenInfo(String network, String address) async {
    final data = {'network': network, 'address': address};
    final response = await http.post(
      Uri.parse('$_baseUrl/token-info/token:import'),
      headers: _headers,
      body: jsonEncode(data),
    );
    final res = _checkResponse(response) as Map<String, dynamic>;
    return TokenInfo.fromMap(res);
  }

  /// Get token info
  Future<ERC20TokenInfo> getTokenInfo(String id) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/token-info?tokenInfoID=$id',
      ),
      headers: _headers,
    );
    final data = _checkResponse(response) as Map<String, dynamic>;
    return ERC20TokenInfo.fromMap(data);
  }

  /// Get user token list
  Future<List<UserToken>> getUserTokenList(
    int pageNo,
    int pageSize,
    String network,
    String keyType,
  ) async {
    final response = await http.get(
        Uri.parse(
            '$_baseUrl/user-token/user-tokens?pageNo=$pageNo&pageSize=$pageSize&network=$network&keyType=$keyType'),
        headers: _headers);
    final data = _checkResponse(response) as Map<String, dynamic>;
    return UserTokenList.fromMap(data).items;
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
