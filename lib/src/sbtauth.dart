// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:eventsource/eventsource.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/api.dart';
import 'package:sbt_auth_dart/utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Develop app url
const DEVELOP_APP_URL = 'https://test-connect.sbtauth.io/login';

/// Production app url
const PRODUCTION_APP_URL = 'https://connect.sbtauth.io/login';

/// Login types
enum LoginType {
  /// Login with google account
  google,

  /// Login with facebook
  facebook,

  /// Login with email
  email,

  /// Login with twitter
  twitter,
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
  UserInfo? get user => _user;

  UserInfo? _user;

  /// core
  AuthCore? get core => _core;

  AuthCore? _core;

  EventSource? _eventSource;

  /// Grant authorization listen controller
  StreamController<String> authRequestStreamController =
      StreamController.broadcast();

  String get _baseUrl => developMode ? DEVELOP_BASE_URL : PRODUCTION_BASE_URL;

  /// SBTAuth api
  SbtAuthApi get api {
    final token = DBUtil.tokenBox.get(TOKEN_KEY);
    if (token == null) throw SbtAuthException('User not logined');
    return SbtAuthApi(baseUrl: _baseUrl, token: token);
  }

  /// provider
  SbtAuthProvider? get provider => core == null
      ? null
      : SbtAuthProvider(signer: core!.signer, clientId: _clientId);

  /// Init sbtauth hive
  static Future<void> initHive() async {
    await DBUtil.init();
  }

  /// Init sbtauth
  Future<void> init() async {
    _user = await api.getUserInfo();
    if (_user == null) throw SbtAuthException('User not logined');
    final core = AuthCore();
    if (_user!.publicKeyAddress == null) {
      final account = await core.generatePubKey();
      await api.uploadShares(_clientId, account.shares, account.address);
      _core = core;
      user!.backupPrivateKey = '0x${account.shares[2].privateKey}';
    } else {
      final remoteShareInfo = await api.fetchRemoteShare();
      final core = AuthCore();
      final inited = await core.init(
        address: remoteShareInfo.address,
        remote: remoteShareInfo.remote,
      );
      if (inited) {
        _core = core;
      }
    }
    await _authRequestListener();
  }

  ///
  Future<void> login(
    LoginType loginType, {
    String? email,
    String? code,
    String? password,
  }) async {
    assert(
      loginType != LoginType.email ||
          (loginType == LoginType.email &&
              email != null &&
              !(code == null && password == null)),
      'Password or code required if login with email',
    );
    String? token;
    if (loginType == LoginType.email) {
      token = await SbtAuthApi.userLogin(
        email: email!,
        code: code,
        password: password,
        clientId: _clientId,
        baseUrl: _baseUrl,
      );
    } else {
      final deviceName = await getDeviceName();
      final appUrl = developMode ? DEVELOP_APP_URL : PRODUCTION_APP_URL;
      final loginUrl =
          '$appUrl?loginType=${loginType.name}&scheme=$_scheme&deviceName=$deviceName';
      unawaited(
        launchUrl(
          Uri.parse(loginUrl),
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
    _saveToken(token);
    await init();
  }

  /// Send privateKey fragment
  Future<void> sendBackupPrivateKey(
    String privateKey,
    String email,
    String code,
  ) async {
    await api.backupShare(privateKey, email, code);
  }

  /// Logout
  void logout() {
    _saveToken('');
    _user = null;
    _core = null;
    _eventSource?.client.close();
  }

  /// Approve auth request
  Future<String> approveAuthRequest(String deviceName) async {
    if (core == null) throw SbtAuthException('Auth not inited');
    final local = core!.localShare;
    if (local == null) throw SbtAuthException('User not login');
    final password = StringBuffer();
    for (var i = 0; i < 6; i++) {
      password.write(Random().nextInt(9).toString());
    }
    final encrypted =
        await encryptMsg(jsonEncode(local.toJson()), password.toString());
    await api.approveAuthRequest(deviceName, encrypted);
    return password.toString();
  }

  /// Get login with qrcode encrypted message
  Future<void> approveLoginWithQrCode(String qrcode) async {
    final qrcodeData = jsonDecode(qrcode) as Map;
    final password = qrcodeData['password'] as String?;
    final qrCodeId = qrcodeData['qrCodeId'] as String?;
    if (password == null || qrCodeId == null) {
      throw SbtAuthException('Invalid QrCode');
    }
    final status = await api.getQrCodeStatus(qrCodeId);
    // if (int.parse(status.qrcodeExpireAt) >=
    //     DateTime.now().millisecondsSinceEpoch) {
    //   throw SbtAuthException('QrCode expired');
    // }
    if (status.qrcodeAuthToken != null && status.qrcodeAuthToken != '') {
      throw SbtAuthException('QrCode used already');
    }
    final local = core?.localShare;
    if (local == null) throw SbtAuthException('SBTAuth not inited');
    final encrypted = await encryptMsg(jsonEncode(local.toJson()), password);
    await api.confirmLoginWithQrCode(qrCodeId, encrypted);
  }

  /// Send verify Code
  Future<void> sendVerifyCode(String email) async {
    await SbtAuthApi.sendEmailCode(email: email, baseUrl: _baseUrl);
  }

  /// Init local share
  Future<void> recoverWithDevice(String code) async {
    final token = DBUtil.tokenBox.get(TOKEN_KEY);
    final eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    final completer = Completer<String>();
    eventSource.listen((Event event) {
      if (event.id != null) {
        api.confirmEventReceived(event.id!, 'AUTH_CONFIRM');
        completer.complete(event.data);
        eventSource.client.close();
      }
    });
    final data = await completer.future;
    final remoteShareInfo = await api.fetchRemoteShare();
    final shareString = await decryptMsg(
      (jsonDecode(data) as Map)['encryptedFragment'].toString(),
      code,
    );
    final localShare = Share.fromMap(jsonDecode(shareString) as Map);
    final core = AuthCore();
    final inited = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      local: localShare,
    );
    if (!inited) throw SbtAuthException('Init error');
    _core = core;
    await _authRequestListener();
  }

  /// Recover with privateKey
  Future<void> recoverWidthBackup(
    String backupPrivateKey,
    String password,
  ) async {
    final remoteShareInfo = await api.fetchRemoteShare();
    var backup = await decryptMsg(backupPrivateKey, password);
    if (backup.startsWith('0x')) {
      backup = backup.substring(2, backup.length);
    }
    final core = AuthCore();
    final inited = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      backup: backup,
    );
    if (!inited) throw SbtAuthException('Init error');
    _core = core;
  }

  /// Export privateKey
  String exportPrivateKey() {
    return core!.getPrivateKey();
  }

  /// Export backup privateKey
  String exportBackupPrivateKey() {
    return core!.getBackupPrivateKey();
  }

  /// Auth request listener
  Future<void> _authRequestListener() async {
    final token = DBUtil.tokenBox.get(TOKEN_KEY);
    _eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    _eventSource!.listen((Event event) {
      if (event.event == 'AUTH_APPLY') {
        if (!authRequestStreamController.isClosed && event.id != null) {
          authRequestStreamController.add(event.data!);
        }
        api.confirmEventReceived(event.id!, 'AUTH_APPLY');
      }
    });
  }

  void _saveToken(String token) {
    DBUtil.tokenBox.put(TOKEN_KEY, token);
  }
}
