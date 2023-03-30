// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:eth_sig_util/util/utils.dart';
import 'package:eventsource/eventsource.dart';
import 'package:flutter/cupertino.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/core/bitcoin_signer.dart';
import 'package:sbt_auth_dart/src/core/solana_signer.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:url_launcher/url_launcher.dart';

/// Develop app url
const DEVELOP_APP_URL = 'https://test-connect.sbtauth.io';

/// Production app url
const PRODUCTION_APP_URL = 'https://connect.sbtauth.io';

/// Develop app url
const DEVELOP_AUTH_URL = 'https://test-auth.safematrix.io';

/// Production app url
const PRODUCTION_AUTH_URL = 'https://auth.safematrix.io';

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

  /// Loading stream
  StreamController<bool> loadingStreamController = StreamController.broadcast();

  /// Login stream
  StreamController<bool> loginStreamController = StreamController.broadcast();

  /// Login user
  UserInfo? get user => _user;

  UserInfo? _user;

  /// User email
  String userEmail = '';

  /// core
  AuthCore? get core => _core;

  AuthCore? _core;

  /// solana core
  AuthCore? get solanaCore => _solanaCore;

  AuthCore? _solanaCore;

  /// bitcoin core
  AuthCore? get bitcoinCore => _bitcoinCore;

  AuthCore? _bitcoinCore;

  /// bitcoin core
  AuthCore? get dogecoinCore => _dogecoinCore;

  AuthCore? _dogecoinCore;

  EventSource? _eventSource;

  /// solana singer
  SolanaSinger? get solanaSinger => _solanaCore == null
      ? null
      : SolanaSinger(
          _solanaCore!,
          _solanaUrl,
          _solanaNetwork,
        );

  /// bitcoin singer
  BitcoinSinger? get bitcoinSinger => _bitcoinCore == null
      ? null
      : BitcoinSinger(
          _bitcoinCore!,
          developMode,
          true,
        );

  /// bitcoin singer
  BitcoinSinger? get dogecoinSinger => _dogecoinCore == null
      ? null
      : BitcoinSinger(
          _dogecoinCore!,
          developMode,
          false,
        );

  /// Grant authorization listen controller
  StreamController<String> authRequestStreamController =
      StreamController.broadcast();

  String get _baseUrl => developMode ? DEVELOP_BASE_URL : PRODUCTION_BASE_URL;

  String get _solanaUrl =>
      developMode ? DEVELOP_SOLANA_URL : PRODUCTION_SOLANA_URL;

  String get _solanaNetwork => developMode ? 'solana_devnet' : 'solana';

  Timer? _timer;

  /// token
  String get token => DBUtil.tokenBox.get(TOKEN_KEY) ?? '';

  /// SBTAuth api
  SbtAuthApi get api {
    if (token == '') throw SbtAuthException('User not logined');
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
          signer: core!.signer,
          clientId: _clientId,
        );

  /// Init sbtauth hive
  static Future<void> initHive() async {
    await DBUtil.init();
  }

  /// check user
  Future<bool> checkUser(String email, {String localLan = 'en-US'}) async {
    final res = await SbtAuthApi.queryUser(
      email,
      baseUrl: _baseUrl,
      localLan: localLan,
    );
    return res;
  }

  /// Init sbtauth
  Future<void> init({
    bool isLogin = false,
    SbtChain chain = SbtChain.EVM,
  }) async {
    _user = await api.getUserInfo();
    if (_user == null) throw SbtAuthException('User not logined');
    if (_user!.userLoginParams.contains('email')) {
      userEmail =
          (jsonDecode(_user!.userLoginParams) as Map)['email'] as String;
    }
    if (_user!.publicKeyAddress[chain.name] == null) {
      final core = getCore(chain);
      final account = await core.generatePubKey(testnet: developMode);
      await api.uploadShares(
        account.shares,
        account.address,
        jsonEncode(AuthCore.getRemoteKeypair(account.shares[1]).toJson()),
        keyType: chain.name,
      );
      switch (chain) {
        case SbtChain.EVM:
          _core = core;
          user!.backupPrivateKey = account.shares[2].privateKey;
          break;
        case SbtChain.SOLANA:
          _solanaCore = core;
          break;
        case SbtChain.BITCOIN:
          _bitcoinCore = core;
          break;
        case SbtChain.DOGECOIN:
          _dogecoinCore = core;
          break;
      }
    } else {
      final remoteLocalShareInfo =
          await api.fetchRemoteShare(keyType: chain.name);
      final core = getCore(chain);
      final inited = await core.init(
        address: remoteLocalShareInfo.address,
        remote: remoteLocalShareInfo.remote,
        isTestnet: developMode,
      );
      if (!isLogin) {
        if (!inited) throw SbtAuthException('Init error');
      }
      if (inited) {
        switch (chain) {
          case SbtChain.EVM:
            _core = core;
            _core!.setSignModel(user!.userWhitelist);
            break;
          case SbtChain.SOLANA:
            _solanaCore = core;
            _solanaCore!.setSignModel(user!.userWhitelist);
            break;
          case SbtChain.BITCOIN:
            _bitcoinCore = core;
            _bitcoinCore!.setSignModel(user!.userWhitelist);
            break;
          case SbtChain.DOGECOIN:
            _dogecoinCore = core;
            _dogecoinCore!.setSignModel(user!.userWhitelist);
            break;
        }
      }
    }
    await _authRequestListener();
  }

  /// Get core
  AuthCore getCore(SbtChain chain) {
    return AuthCore(
      mpcUrl: MpcUrl(
        url: _baseUrl,
        get: 'user/forward:query:data',
        set: 'user/forward:data',
      ),
      signUrl: '$_baseUrl/user:sign',
      token: token,
      chain: chain,
    );
  }

  /// Timer cancel
  void timerCancel() {
    _timer?.cancel();
  }

  ///Reset password
  Future<void> resetPwd(
    String emailAddress,
    String authCode,
    String password,
  ) async {
    await SbtAuthApi.resetPassword(
      emailAddress,
      authCode,
      password,
      _baseUrl,
      localLan: _getLocale(_locale),
    );
  }

  /// Get device list
  Future<List<Device>> getDeviceList() async {
    final deviceList = await api.getUserDeviceList(_clientId);
    return deviceList;
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
      final appUrl = developMode ? DEVELOP_AUTH_URL : PRODUCTION_AUTH_URL;
      final loginUrl =
          '$appUrl?loginType=${loginType.name}&developMode=$developMode&scheme=$_scheme&deviceName=$deviceName&clientId=$_clientId';
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
    _timer?.cancel();
    loadingStreamController.add(true);
    try {
      if (token == null) return;
      _saveToken(token);
      await init(isLogin: true);
    } catch (e) {
      rethrow;
    } finally {
      loadingStreamController.add(false);
    }
  }

  /// Send privateKey fragment
  Future<void> sendBackupPrivateKey(
    String password,
    String email,
    String code, {
    SbtChain chain = SbtChain.EVM,
    String googleCode = '',
  }) async {
    final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
    var backupPrivateKey = '';
    switch (chain) {
      case SbtChain.EVM:
        backupPrivateKey =
            await _core!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
      case SbtChain.SOLANA:
        backupPrivateKey =
            await _solanaCore!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
      case SbtChain.BITCOIN:
        backupPrivateKey =
            await _bitcoinCore!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
      case SbtChain.DOGECOIN:
        backupPrivateKey =
            await _dogecoinCore!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
    }
    final privateKey = await encryptMsg(backupPrivateKey, password);
    await api.backupShare(
      privateKey,
      email,
      code,
      keyType: chain.name,
      googleCode: googleCode,
    );
    userEmail = email;
  }

  /// Batch backup
  Future<void> batchBackup(
    String password,
    String email,
    String code, {
    String googleCode = '',
  }) async {
    final backupInfo = <String, dynamic>{};
    final coreList = <AuthCore?>[
      _core,
      _solanaCore,
      _bitcoinCore,
      _dogecoinCore
    ];
    for (var i = 0; i < SbtChain.values.length; i++) {
      if (coreList[i] == null) {
        backupInfo[SbtChain.values[i].name] = '';
      } else {
        final remoteShareInfo =
            await api.fetchRemoteShare(keyType: SbtChain.values[i].name);
        final backupPrivateKey =
            await coreList[i]!.getBackupPrivateKey(remoteShareInfo.backupAux);
        final privateKey = await encryptMsg(backupPrivateKey, password);
        backupInfo[SbtChain.values[i].name] = privateKey;
      }
    }
    await api.batchBackup(
      code,
      backupInfo,
      email,
      googleCode: googleCode,
    );
    userEmail = email;
  }

  /// Logout
  void logout() {
    DBUtil.tokenBox.delete(TOKEN_KEY);
    _user = null;
    _core = null;
    _solanaCore = null;
    _bitcoinCore = null;
    _dogecoinCore = null;
    _eventSource?.client.close();
    userEmail = '';
  }

  /// Approve auth request
  Future<String> approveAuthRequest(
    String deviceName, {
    SbtChain chain = SbtChain.EVM,
  }) async {
    var local = '';
    switch (chain) {
      case SbtChain.EVM:
        if (core == null) {
          throw SbtAuthException('Auth not inited');
        }
        local = core!.localShare!.privateKey;
        break;
      case SbtChain.SOLANA:
        if (solanaCore == null) {
          throw SbtAuthException('Solana auth not inited');
        }
        local = solanaCore!.localShare!.privateKey;
        break;
      case SbtChain.BITCOIN:
        if (bitcoinCore == null) {
          throw SbtAuthException('Bitcoin auth not inited');
        }
        local = bitcoinCore!.localShare!.privateKey;
        break;
      case SbtChain.DOGECOIN:
        if (dogecoinCore == null) {
          throw SbtAuthException('Bitcoin auth not inited');
        }
        local = dogecoinCore!.localShare!.privateKey;
        break;
    }
    final password = StringBuffer();
    for (var i = 0; i < 6; i++) {
      password.write(Random().nextInt(9).toString());
    }
    final encrypted = await encryptMsg(local, password.toString());
    await api.approveAuthRequest(deviceName, encrypted, chain.name);
    return password.toString();
  }

  /// Get login QrCode
  Future<String> getLoginQrCode() async {
    final qrCodeId = await SbtAuthApi.getLoginQrcode(_baseUrl, _clientId);
    final password = StringBuffer();
    for (var i = 0; i < 6; i++) {
      password.write(Random().nextInt(9).toString());
    }
    final controller = StreamController<StreamResponse>();
    final completer = Completer<String?>();
    _queryWhetherSuccess(password.toString(), qrCodeId, controller)
        .listen((event) {
      if (event.data != null) {
        completer.complete(event.data);
      }
    });
    final dataMap = {'qrCodeId': qrCodeId, 'password': password.toString()};
    return jsonEncode(dataMap);
  }

  /// Get login with qrcode encrypted message
  Future<void> approveLoginWithQrCode(String qrcode) async {
    final qrcodeData = jsonDecode(qrcode) as Map;
    final password = qrcodeData['password'] as String?;
    final qrCodeId = qrcodeData['qrCodeId'] as String?;
    if (password == null || qrCodeId == null) {
      throw SbtAuthException('Invalid QrCode');
    }
    final status = await SbtAuthApi.getQrCodeStatus(_baseUrl, qrCodeId);
    // if (int.parse(status.qrcodeExpireAt) >=
    //     DateTime.now().millisecondsSinceEpoch) {
    //   throw SbtAuthException('QrCode expired');
    // }
    if (status.qrcodeAuthToken != null && status.qrcodeAuthToken != '') {
      throw SbtAuthException('QrCode used already');
    }
    if (core == null) throw SbtAuthException('Auth not inited');
    final local = core!.localShare!.privateKey;
    final encrypted = await encryptMsg(local, password);
    await api.confirmLoginWithQrCode(qrCodeId, encrypted);
  }

  /// Send verify Code
  Future<void> sendVerifyCode(String email) async {
    await SbtAuthApi.sendEmailCode(email: email, baseUrl: _baseUrl);
  }

  /// Init local share
  Future<void> recoverWithDevice(
    String code, {
    SbtChain chain = SbtChain.EVM,
  }) async {
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
    final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
    final shareString = await decryptMsg(
      (jsonDecode(data) as Map)['encryptedFragment'].toString(),
      code,
    );
    final localShare = Share(
      privateKey: shareString,
      publicKey: remoteShareInfo.remote.publicKey,
      extraData: remoteShareInfo.localAux,
    );
    final core = getCore(chain);
    final hash = bytesToHex(
      hashMessage(ascii.encode(jsonEncode(localShare.toJson()))),
      include0x: true,
    );
    if (hash != remoteShareInfo.localHash) {
      throw SbtAuthException('Recover failed');
    }
    final inited = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      local: localShare,
      isTestnet: developMode,
    );
    switch (chain) {
      case SbtChain.EVM:
        _core = core;
        break;
      case SbtChain.SOLANA:
        _solanaCore = core;
        break;
      case SbtChain.BITCOIN:
        _bitcoinCore = core;
        break;
      case SbtChain.DOGECOIN:
        _dogecoinCore = core;
        break;
    }
    if (!inited) throw SbtAuthException('Init error');
    await _authRequestListener();
    await api.verifyIdentity(localShare, keyType: chain.name);
  }

  /// Recover with privateKey
  Future<void> recoverWidthBackup(
    String backupPrivateKey,
    String password, {
    SbtChain chain = SbtChain.EVM,
  }) async {
    final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
    var backup = '';
    if (backupPrivateKey.startsWith('0x')) {
      backup = backupPrivateKey;
    } else {
      backup = await decryptMsg(backupPrivateKey, password);
    }
    final core = getCore(chain);
    final backShare = Share(
      privateKey: backup,
      publicKey: remoteShareInfo.remote.publicKey,
      extraData: remoteShareInfo.backupAux,
    );
    final hash = bytesToHex(
      hashMessage(ascii.encode(jsonEncode(backShare.toJson()))),
      include0x: true,
    );
    if (hash != remoteShareInfo.backupHash) {
      throw SbtAuthException('Recover failed');
    }
    final inited = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
      backup: backShare,
      backupAux: remoteShareInfo.localAux,
      isTestnet: developMode,
    );
    switch (chain) {
      case SbtChain.EVM:
        _core = core;
        break;
      case SbtChain.SOLANA:
        _solanaCore = core;
        break;
      case SbtChain.BITCOIN:
        _bitcoinCore = core;
        break;
      case SbtChain.DOGECOIN:
        _dogecoinCore = core;
        break;
    }
    if (!inited) throw SbtAuthException('Init error');
    await _authRequestListener();
    await api.verifyIdentity(core.localShare!, keyType: chain.name);
  }

  /// Backup with one drive
  Future<void> backupWithOneDrive(
    String password, {
    SbtChain chain = SbtChain.EVM,
  }) async {
    final remoteShareInfo = await api.fetchRemoteShare(keyType: chain.name);
    var backupPrivateKey = '';
    switch (chain) {
      case SbtChain.EVM:
        backupPrivateKey =
            await _core!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
      case SbtChain.SOLANA:
        backupPrivateKey =
            await _solanaCore!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
      case SbtChain.BITCOIN:
        backupPrivateKey =
            await _bitcoinCore!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
      case SbtChain.DOGECOIN:
        backupPrivateKey =
            await _dogecoinCore!.getBackupPrivateKey(remoteShareInfo.backupAux);
        break;
    }
    final privateKey = await encryptMsg(backupPrivateKey, password);
    final baseUrl = developMode ? DEVELOP_APP_URL : PRODUCTION_APP_URL;
    final oneDriveUrl = '$baseUrl/onedrive?scheme=$_scheme';
    unawaited(
      launchUrl(
        Uri.parse(oneDriveUrl),
        mode: Platform.isAndroid
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      ),
    );
    final completer = Completer<String?>();
    final appLinks = AppLinks();
    final linkSubscription = appLinks.uriLinkStream.listen((uri) {
      if (uri.toString().startsWith(_scheme)) {
        completer.complete(jsonEncode(uri.queryParameters));
      }
    });
    final data = await completer.future;
    final dataMap = jsonDecode(data!) as Map<String, dynamic>;
    final code = dataMap['code'] as String;
    final state = dataMap['state'] as String;
    loadingStreamController.add(true);
    try {
      await api.backupByOneDrive(
        code,
        state == 'undefined' ? 'state' : state,
        privateKey,
        keyType: chain.name,
      );
      if (Platform.isIOS) {
        await closeInAppWebView();
      }
      await linkSubscription.cancel();
    } catch (e) {
      rethrow;
    } finally {
      loadingStreamController.add(false);
    }
  }

  /// One drive batch backup
  Future<void> oneDriveBatchBackup(String password) async {
    final backupInfo = <String, dynamic>{};
    final coreList = <AuthCore?>[
      _core,
      _solanaCore,
      _bitcoinCore,
      _dogecoinCore
    ];
    for (var i = 0; i < SbtChain.values.length; i++) {
      if (coreList[i] == null) {
        backupInfo[SbtChain.values[i].name] = '';
      } else {
        final remoteShareInfo =
            await api.fetchRemoteShare(keyType: SbtChain.values[i].name);
        final backupPrivateKey =
            await coreList[i]!.getBackupPrivateKey(remoteShareInfo.backupAux);
        final privateKey = await encryptMsg(backupPrivateKey, password);
        backupInfo[SbtChain.values[i].name] = privateKey;
      }
    }
    final baseUrl = developMode ? DEVELOP_APP_URL : PRODUCTION_APP_URL;
    final oneDriveUrl = '$baseUrl/onedrive?scheme=$_scheme';
    unawaited(
      launchUrl(
        Uri.parse(oneDriveUrl),
        mode: Platform.isAndroid
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      ),
    );
    final completer = Completer<String?>();
    final appLinks = AppLinks();
    final linkSubscription = appLinks.uriLinkStream.listen((uri) {
      if (uri.toString().startsWith(_scheme)) {
        completer.complete(jsonEncode(uri.queryParameters));
      }
    });
    final data = await completer.future;
    final dataMap = jsonDecode(data!) as Map<String, dynamic>;
    final code = dataMap['code'] as String;
    final state = dataMap['state'] as String;
    loadingStreamController.add(true);
    try {
      await api.oneDriveBatchBackup(
        code,
        state == 'undefined' ? 'state' : state,
        backupInfo,
      );
      if (Platform.isIOS) {
        await closeInAppWebView();
      }
      await linkSubscription.cancel();
    } catch (e) {
      rethrow;
    } finally {
      loadingStreamController.add(false);
    }
  }

  /// Recover by one drive
  Future<void> recoverByOneDrive(
    String password, {
    SbtChain chain = SbtChain.EVM,
  }) async {
    final baseUrl = developMode ? DEVELOP_APP_URL : PRODUCTION_APP_URL;
    final oneDriveUrl = '$baseUrl/onedrive?scheme=$_scheme';
    unawaited(
      launchUrl(
        Uri.parse(oneDriveUrl),
        mode: Platform.isAndroid
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      ),
    );
    final completer = Completer<String?>();
    final appLinks = AppLinks();
    final linkSubscription = appLinks.uriLinkStream.listen((uri) {
      if (uri.toString().startsWith(_scheme)) {
        completer.complete(jsonEncode(uri.queryParameters));
      }
    });
    final data = await completer.future;
    final dataMap = jsonDecode(data!) as Map<String, dynamic>;
    final code = dataMap['code'] as String;
    final state = dataMap['state'] as String;
    loadingStreamController.add(true);
    try {
      final privateKey = await api.recoverByOneDrive(
        code,
        state == 'undefined' ? 'state' : state,
        keyType: chain.name,
      );
      if (Platform.isIOS) {
        await closeInAppWebView();
      }
      await linkSubscription.cancel();
      await recoverWidthBackup(privateKey, password, chain: chain);
    } catch (e) {
      rethrow;
    } finally {
      loadingStreamController.add(false);
    }
  }

  /// Auth request listener
  Future<void> _authRequestListener() async {
    _eventSource =
        await EventSource.connect('$_baseUrl/sse:connect?access_token=$token');
    _eventSource!.listen((Event event) {
      if (event.event == 'AUTH_APPLY') {
        if (!authRequestStreamController.isClosed && event.id != null) {
          authRequestStreamController.add(event.data!);
          api.confirmEventReceived(event.id!, 'AUTH_APPLY');
        }
      }
    });
  }

  /// Switch white list
  Future<void> switchWhiteList(
    String code, {
    required bool whitelistSwitch,
    String googleCode = '',
  }) async {
    await api.switchUserWhiteList(
      userEmail,
      code,
      whitelistSwitch: whitelistSwitch,
      googleCode: googleCode,
    );
    await getUserInfo();
  }

  /// get user info
  Future<void> getUserInfo() async {
    _user = await api.getUserInfo();
    if (core != null) {
      core!.setSignModel(user!.userWhitelist);
    }
    if (solanaCore != null) {
      solanaCore!.setSignModel(user!.userWhitelist);
    }
    if (bitcoinCore != null) {
      bitcoinCore!.setSignModel(user!.userWhitelist);
    }
    if (dogecoinCore != null) {
      dogecoinCore!.setSignModel(user!.userWhitelist);
    }
  }

  /// Create white list
  Future<void> createWhiteList(
    String authCode,
    String address,
    String name,
    String network, {
    bool toLowerCase = true,
    String googleCode = '',
  }) async {
    await api.createUserWhiteList(
      userEmail,
      authCode,
      toLowerCase ? address.toLowerCase() : address,
      name,
      network,
      googleCode: googleCode,
    );
  }

  /// Delete white list
  Future<void> deleteWhiteList(
    String authCode,
    String userWhitelistID, {
    String googleCode = '',
  }) async {
    await api.deleteUserWhiteList(
      userEmail,
      authCode,
      userWhitelistID,
      googleCode: googleCode,
    );
  }

  /// Edit white list
  Future<void> editWhiteList(
    String authCode,
    String address,
    String name,
    String userWhitelistID,
    String userId,
    String network, {
    bool toLowerCase = true,
    String googleCode = '',
  }) async {
    await api.editUserWhiteList(
      userEmail,
      authCode,
      toLowerCase ? address.toLowerCase() : address,
      name,
      userWhitelistID,
      userId,
      network,
      googleCode: googleCode,
    );
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

  /// Get token list
  Future<List<TokenInfo>> getTokenList(
    int pageNo,
    int pageSize,
    String network,
    String condition,
  ) async {
    final res = await api.getTokenList(pageNo, pageSize, network, condition);
    return res.items;
  }

  /// Create strategy
  Future<void> createStrategy(
    List<Map<String, dynamic>> commandList, {
    String googleCode = '',
  }) async {
    await api.createStrategy(commandList, googleCode: googleCode);
  }

  /// Edit strategy
  Future<void> editStrategy(
    List<Map<String, dynamic>> commandList, {
    String googleCode = '',
  }) async {
    await api.editStrategy(commandList, googleCode: googleCode);
  }

  Stream<StreamResponse> _queryWhetherSuccess(
    String password,
    String qrcode,
    StreamController<StreamResponse> controller,
  ) {
    var counter = 0;
    const interval = Duration(seconds: 2);
    var result = QrCodeStatus(
      qrcodeName: '',
      qrcodeClientID: '',
      qrcodeExpireAt: '',
      fail: true,
      qrcodeEncryptedFragment: '',
    );

    Future<void> tick(_) async {
      counter++;
      debugPrint('trying $counter time');

      try {
        result = await SbtAuthApi.getQrCodeStatus(_baseUrl, qrcode);
      } catch (e) {
        _timer?.cancel();
      }
      if (result.qrcodeEncryptedFragment != '') {
        final token = result.qrcodeAuthToken!;
        _saveToken(token);
        await getUserInfo();
        final shareData = result.qrcodeEncryptedFragment!;
        final remoteShareInfo = await api.fetchRemoteShare();
        final shareString = await decryptMsg(
          shareData,
          password,
        );
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
          token: token,
        );
        final inited = await core.init(
          address: remoteShareInfo.address,
          remote: remoteShareInfo.remote,
          local: localShare,
          isTestnet: developMode,
        );
        _core = core;
        if (!inited) throw SbtAuthException('Init error');
        await _authRequestListener();
        loginStreamController.add(true);
      }

      if (result.qrcodeEncryptedFragment != '') {
        _timer?.cancel();
      }
    }

    void startTimer() {
      _timer = Timer.periodic(interval, tick);
    }

    void stopTimer() {
      _timer?.cancel();
      _timer = null;
    }

    controller = StreamController<StreamResponse>(
        onListen: startTimer,
        onPause: stopTimer,
        onResume: startTimer,
        onCancel: stopTimer);

    return controller.stream;
  }
}

/// Stream Response
class StreamResponse {
  /// Stream Response
  StreamResponse(this.time, this.data);

  /// time
  final int time;

  /// data
  final FutureOr<String?>? data;

  @override
  String toString() => 'StreamResponse(time: $time, data: $data)';
}
