import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aes_dart/aes_dart.dart';
import 'package:app_links/app_links.dart';
import 'package:eventsource/eventsource.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Login types
enum LoginType {
  /// Login with google account
  google,

  /// Login with facebook
  facebook,

  /// Login with email
  email,

  /// Login with twitter
  twitter
}

/// SbtAuth class
class SbtAuth {
  /// SBTAuth, you need to set your own custom scheme.
  SbtAuth({
    required this.developMode,
    required String clientId,
    required String scheme,
  }) {
    _clientId = clientId;
    _scheme = scheme;
  }

  /// If you set developMode true, the use registered is on test site, can only
  /// access to testnet.
  late bool developMode;

  late String _clientId;
  late String _scheme;

  /// Login user
  late UserInfo user;

  /// Backup privateKey fragment3
  late String privateKeyFragment3;

  /// core
  AuthCore core = AuthCore();

  /// Grant authorization listen controller
  StreamController<String> streamController = StreamController.broadcast();

  String? _grantData;

  /// Device list
  late List<Device> deviceList;

  String get _baseUrl => developMode
      ? 'https://test-api.sbtauth.io/sbt-auth'
      : 'https://api.sbtauth.io/sbt-auth';

  /// provider
  SbtAuthProvider get provider =>
      SbtAuthProvider(signer: core.signer, clientId: _clientId);

  /// Init sbtauth
  Future<void> init() async {
    await DBUtil.install();
    await DBUtil.getInstance();
    await SbtAuthApi.init();
    await _authRequestListener();
    // streamController.stream.listen((event) {
    //   print(event);
    //   print('****************************************');
    // });
  }

  Future<void> _initUser() async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    user = await api.getUserInfo();
    if (user.publicKeyAddress == null) {
      final account = await core.generatePubKey();
      await api.uploadShares(_clientId, account.shares, account.address);
      privateKeyFragment3 = '0x${account.shares[2].privateKey}';
    } else {
      core = await initCore();
    }
  }

  Future<void> _saveToken(String token) async {
    final dbUtil = await DBUtil.getInstance();
    await dbUtil.tokenBox.put(TOKEN_KEY, token);
  }

  /// Login with sbtAuth
  Future<bool> loginWithSocial(
    LoginType loginType, {
    String? email,
    String? verityCode,
  }) async {
    String? token;
    if (loginType == LoginType.email) {
      await _login(loginType, email: email, code: verityCode ?? '');
      final dbUtil = await DBUtil.getInstance();
      token = dbUtil.tokenBox.get(TOKEN_KEY);
    } else {
      await _login(loginType);
      final dbUtil = await DBUtil.getInstance();
      token = dbUtil.tokenBox.get(TOKEN_KEY);
    }
    return token != null;
  }

  Future<void> _login(
    LoginType loginType, {
    String? email,
    String? code,
  }) async {
    assert(
      loginType != LoginType.email ||
          (loginType == LoginType.email && email != null && code != null),
      'Email and code required',
    );
    String? token;
    if (loginType == LoginType.email) {
      token = await SbtAuthApi.userLogin(
        email: email!,
        code: code!,
        clientId: _clientId,
        baseUrl: _baseUrl,
      );
    } else {
      final appUrl = developMode
          ? 'https://test-connect.sbtauth.io/login'
          : 'https://connect.sbtauth.io/login';
      final loginUrl = '$appUrl?loginType=${loginType.name}&scheme=$_scheme';
      unawaited(
        launchUrlString(
          loginUrl,
          mode: Platform.isAndroid
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        ),
      );
      final completer = Completer<String?>();
      final appLinks = AppLinks();
      final linkSubscription = appLinks.uriLinkStream.listen((uri) {
        if (uri.toString().startsWith(_scheme)) {
          completer.complete(uri.queryParameters['token']);
        }
      });
      token = await completer.future;
      if (Platform.isIOS) {
        await closeInAppWebView();
      }
      await linkSubscription.cancel();
    }

    if (token == null) return;
    await _saveToken(token);
    await SbtAuthApi.init();
    await _initUser();
    await _authRequestListener();
  }

  /// Send privateKey fragment
  Future<void> sendBackupPrivateKey(String privateKey, String email) async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    await api.backupShare(privateKey, email);
  }

  /// Init core
  Future<AuthCore> initCore() async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    final remoteShareInfo = await api.fetchRemoteShare(_clientId);
    final init = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
    );
    if (!init) {
      throw SbtAuthException('New device detected');
    }
    return core;
  }

  /// Logout
  Future<void> logout() async {
    await _saveToken('');
    await SbtAuthApi.init();
  }

  /// Approve auth request
  Future<String> approveAuthRequest(String deviceName) async {
    core = await initCore();
    final local = core.localShare;
    if (local == null) throw SbtAuthException('User not login');
    final api = SbtAuthApi(baseUrl: _baseUrl);
    final password = StringBuffer();
    for (var i = 0; i < 6; i++) {
      password.write(Random().nextInt(9).toString());
    }
    final encrypted =
        await encryptMsg(jsonEncode(local.toJson()), password.toString());
    await api.approveAuthRequest(deviceName, encrypted);
    return password.toString();
  }

  /// Auth request listener
  Future<void> _authRequestListener() async {
    final dbUtil = await DBUtil.getInstance();
    final token = dbUtil.tokenBox.get(TOKEN_KEY);
    final api = SbtAuthApi(baseUrl: _baseUrl);
    final eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    eventSource.listen((Event event) {
      try {
        if (!streamController.isClosed && event.id != null) {
          streamController.add(event.data!);
          api.confirmEventReceived(event.id!, 'AUTH_APPLY');
        }
      } catch (e) {
        rethrow;
      }
    });
  }

  /// Auth reply listener
  Future<void> _authReplyListener() async {
    final dbUtil = await DBUtil.getInstance();
    final token = dbUtil.tokenBox.get(TOKEN_KEY);
    final api = SbtAuthApi(baseUrl: _baseUrl);

    final eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    // listen for events
    eventSource.listen((Event event) {
      print('New event:');
      print('  event: ${event.event}');
      print('  data: ${event.data}');
      if (event.id != null) {
        api.confirmEventReceived(event.id!, 'AUTH_CONFIRM');
        _grantData = event.data;
      }
    });
  }

  /// Init local share
  Future<void> initLocalShare(String code) async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    final remoteShareInfo = await api.fetchRemoteShare(_clientId);
    if (_grantData == null) throw SbtAuthException('Verification Code error');
    final shareString = await decryptMsg(
      (jsonDecode(_grantData!) as Map)['encryptedFragment'].toString(),
      code,
    );
    final localShare = Share.fromMap(jsonDecode(shareString) as Map);
    final init = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      local: localShare,
    );
    if (!init) throw SbtAuthException('Init error');
    await _initUser();
  }

  /// Encrypt
  Future<String> encryptMsg(String msg, String password) async {
    final encprypted = await aesEncrypt(msg, password);
    return encprypted;
  }

  /// Decrypt
  Future<String> decryptMsg(String? encrypted, String password) async {
    if (encrypted == null) throw SbtAuthException('Verification Code error');
    try {
      final decrypted = await aesDecrypt(encrypted, password);
      return decrypted;
    } catch (e) {
      if (e.toString().contains('Invalid or corrupted pad block')) {
        throw SbtAuthException('Verification Code error');
      }
      rethrow;
    }
  }

  /// Recover with Device
  Future<void> recoverWithDevice(String deviceName) async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    await api.sendAuthRequest(deviceName);
    await _authReplyListener();
  }

  /// Recover with privateKey
  Future<void> recoverWidthBackup(
      String backupPrivateKey, String password) async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    final remoteShareInfo = await api.fetchRemoteShare(_clientId);
    final shareString = await decryptMsg(backupPrivateKey, password);
    final localShare = Share.fromMap(jsonDecode(shareString) as Map);
    final init = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      local: localShare,
    );
    if (!init) throw SbtAuthException('Init error');
  }

  /// Get Device list
  Future<void> getDeviceList() async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    deviceList = await api.getUserDeviceList();
  }
}
