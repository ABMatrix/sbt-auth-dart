// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:eventsource/eventsource.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/core/local_core.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/api.dart';
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

/// Local type
enum LocaleType {
  /// en
  en_US,

  /// zh_cn
  zh_CN,

  /// zh_TW
  zh_TW
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
  LocaleType _locale = LocaleType.en_US;

  /// Login user
  UserInfo? get user => _user;

  UserInfo? _user;

  /// core
  dynamic get core => _core;

  dynamic _core;

  EventSource? _eventSource;

  /// Grant authorization listen controller
  StreamController<String> authRequestStreamController =
      StreamController.broadcast();

  String get _baseUrl => developMode ? DEVELOP_BASE_URL : PRODUCTION_BASE_URL;

  /// SBTAuth api
  SbtAuthApi get api {
    final token = DBUtil.tokenBox.get(TOKEN_KEY);
    if (token == null) throw SbtAuthException('User not logined');
    return SbtAuthApi(
      baseUrl: _baseUrl,
      token: token,
      local: _getLocale(_locale),
    );
  }

  /// provider
  SbtAuthProvider? get provider => core == null
      ? null
      : SbtAuthProvider(
          signer: core is AuthCore
              ? (core as AuthCore).signer
              : (core as LocalAuthCore).signer,
          clientId: _clientId,
        );

  /// Init sbtauth hive
  static Future<void> initHive() async {
    await DBUtil.init();
  }

  /// Init sbtauth
  Future<void> init({bool isLogin = true}) async {
    final token = DBUtil.tokenBox.get(TOKEN_KEY);
    _user = await api.getUserInfo();
    if (_user == null) throw SbtAuthException('User not logined');
    var inited = false;
    if (_user!.publicKeyAddress == null) {
      final core = AuthCore(
        mpcUrl: MpcUrl(
          url: _baseUrl,
          get: 'user/forward:query:data',
          set: 'user/forward:data',
        ),
        signUrl: '$_baseUrl/user:sign',
        token: token!,
      );
      final account = await core.generatePubKey();
      await api.uploadShares(
        _clientId,
        account.shares,
        account.address,
        jsonEncode(AuthCore.getRemoteKeypair(account.shares[1]).toJson()),
      );
      _core = core;
      user!.backupPrivateKey = '0x${account.shares[2].privateKey}';
    } else {
      final remoteLocalShareInfo = await api.fetchRemoteShare();
      if (remoteLocalShareInfo.localAux == '') {
        final core = LocalAuthCore();
        inited = await core.init(
          address: remoteLocalShareInfo.address,
          remote: remoteLocalShareInfo.remote,
        );
        if (inited) {
          _core = core;
        }
      } else {
        final core = AuthCore(
          mpcUrl: MpcUrl(
            url: _baseUrl,
            get: 'user/forward:query:data',
            set: 'user/forward:data',
          ),
          signUrl: '$_baseUrl/user:sign',
          token: token!,
        );
        inited = await core.init(
          address: remoteLocalShareInfo.address,
          remote: remoteLocalShareInfo.remote,
        );
        if (inited) {
          _core = core;
        }
      }
    }
    if (!isLogin) {
      if (!inited) throw SbtAuthException('Init error');
    }
    await _authRequestListener();
  }

  /// Login
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
        localLan: _getLocale(_locale),
      );
    } else {
      final deviceName = await getDeviceName();
      final appUrl = developMode ? DEVELOP_APP_URL : PRODUCTION_APP_URL;
      final loginUrl =
          '$appUrl?loginType=${loginType.name}&scheme=$_scheme&deviceName=$deviceName&clientId=$_clientId';
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
    String password,
    String email,
    String code,
  ) async {
    var backupPrivateKey = user?.backupPrivateKey;
    if (backupPrivateKey == null) {
      final remoteShareInfo = await api.fetchRemoteShare();
      backupPrivateKey = remoteShareInfo.localAux == ''
          ? (_core as LocalAuthCore).getBackupPrivateKey()
          : remoteShareInfo.localAux;
    }
    final privateKey = await encryptMsg(backupPrivateKey, password);
    await api.backupShare(privateKey, email, code);
  }

  /// Logout
  void logout() {
    DBUtil.tokenBox.delete(TOKEN_KEY);
    _user = null;
    _core = null;
    _eventSource?.client.close();
  }

  /// Approve auth request
  Future<String> approveAuthRequest(String deviceName) async {
    if (core == null) throw SbtAuthException('Auth not inited');
    dynamic local = core is AuthCore
        ? (core as AuthCore).localShare!.privateKey
        : (core as LocalAuthCore).localShare;
    if (local == null) throw SbtAuthException('User not login');
    final password = StringBuffer();
    for (var i = 0; i < 6; i++) {
      password.write(Random().nextInt(9).toString());
    }
    var encrypted = '';
    if (core is AuthCore) {
      encrypted = await encryptMsg(local, password.toString());
    } else {
      encrypted =
          await encryptMsg(jsonEncode(local.toJson()), password.toString());
    }
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
    dynamic local = core is AuthCore
        ? (core as AuthCore).localShare!.privateKey
        : (core as LocalAuthCore).localShare;
    if (local == null) throw SbtAuthException('SBTAuth not inited');
    var encrypted = '';
    if (core is AuthCore) {
      encrypted = await encryptMsg(local, password.toString());
    } else {
      encrypted =
      await encryptMsg(jsonEncode(local.toJson()), password.toString());
    }
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
    var inited = false;
    if (remoteShareInfo.localAux == '' || remoteShareInfo.backupAux == '') {
      final localShare = Share.fromMap(jsonDecode(shareString) as Map);
      final core = LocalAuthCore();
      inited = await core.init(
        address: remoteShareInfo.address,
        remote: remoteShareInfo.remote,
        local: localShare,
      );
      _core = core;
    } else {
      final localShare = Share(
        privateKey: shareString,
        publicKey: remoteShareInfo.remote.publicKey,
        extraData: remoteShareInfo.localAux,
      );
      final core = AuthCore(
        mpcUrl: MpcUrl(
          url: _baseUrl,
          get: 'user/forward:query:data',
          set: 'user/forward:data',
        ),
        signUrl: '$_baseUrl/user:sign',
        token: token!,
      );
      inited = await core.init(
        address: remoteShareInfo.address,
        remote: remoteShareInfo.remote,
        local: localShare,
      );
      _core = core;
    }
    if (!inited) throw SbtAuthException('Init error');
    await _authRequestListener();
  }

  /// Recover with privateKey
  Future<void> recoverWidthBackup(
    String backupPrivateKey,
    String password,
  ) async {
    final remoteShareInfo = await api.fetchRemoteShare();
    final token = DBUtil.tokenBox.get(TOKEN_KEY);
    var backup = '';
    if (backupPrivateKey.startsWith('0x')) {
      backup = backupPrivateKey;
    } else {
      backup = await decryptMsg(backupPrivateKey, password);
    }
    if (backup.startsWith('0x')) {
      backup = backup.substring(2);
    }
    var inited = false;
    if (remoteShareInfo.localAux == '' || remoteShareInfo.backupAux == '') {
      final core = LocalAuthCore();
      inited = await core.init(
        address: remoteShareInfo.address,
        remote: remoteShareInfo.remote,
        backup: backup,
      );
      _core = core;
    } else {
      final core = AuthCore(
        mpcUrl: MpcUrl(
          url: _baseUrl,
          get: 'user/forward:query:data',
          set: 'user/forward:data',
        ),
        signUrl: '$_baseUrl/user:sign',
        token: token!,
      );
      final backShare = Share(
        privateKey: backup,
        publicKey: remoteShareInfo.remote.publicKey,
        extraData: remoteShareInfo.backupAux,
      );
      inited = await core.init(
        address: remoteShareInfo.address,
        remote: remoteShareInfo.remote,
        backup: backShare,
        backupAux: remoteShareInfo.localAux,
      );
      _core = core;
    }
    if (!inited) throw SbtAuthException('Init error');
  }

  // /// Export privateKey
  // String exportPrivateKey() {
  //   return core!.getPrivateKey();
  // }

  // /// Export backup privateKey
  // String exportBackupPrivateKey() {
  //   return core!.getBackupPrivateKey();
  // }

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

  /// Switch white list
  Future<void> switchWhiteList({required bool whitelistSwitch}) async {
    await api.switchUserWhiteList(whitelistSwitch: whitelistSwitch);
    _user = await api.getUserInfo();
  }

  String _getLocale(LocaleType localType) {
    switch (localType) {
      case LocaleType.en_US:
        return 'en-US';
      case LocaleType.zh_CN:
        return 'zh-CN';
      case LocaleType.zh_TW:
        return 'zh-TW';
    }
  }

  /// Set local
  void setLocale(LocaleType localeType) {
    _locale = localeType;
  }

  void _saveToken(String token) {
    DBUtil.tokenBox.put(TOKEN_KEY, token);
  }
}
