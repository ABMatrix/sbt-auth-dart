import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/core/core.dart';
import 'package:sbt_auth_dart/src/db_util.dart';
import 'package:sbt_auth_dart/src/types/api.dart';
import 'package:sbt_auth_dart/src/types/exception.dart';
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
  late AppLinks _appLinks;

  /// Login user
  late UserInfo user;

  /// Backup privateKey fragment3
  late String privateKeyFragment3;

  /// core
  AuthCore core = AuthCore();

  String get _baseUrl => developMode
      ? 'https://test-api.sbtauth.io/sbt-auth'
      : 'https://api.sbtauth.io/sbt-auth';

  /// Init sbtauth
  Future<void> init() async {
    await _initDeepLinks();
    await DBUtil.install();
    await DBUtil.getInstance();
    await SbtAuthApi.init();
  }

  Future<void> _initUser() async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    user = await api.getUserInfo();
    if (user.publicKeyAddress == null) {
      final account = await core.generatePubKey();
      await api.uploadShares(account.shares, account.address);
      privateKeyFragment3 = account.shares[2].privateKey;
    } else {
      core = await initCore();
    }
  }

  Future<void> _saveToken(String token) async {
    final dbUtil = await DBUtil.getInstance();
    await dbUtil.tokenBox.put(TOKEN_KEY, token);
  }

  /// Login with sbtauth
  Future<bool> loginWithSocial(LoginType loginType,
      {String? email, String? verityCode}) async {
    String? token;
    if (loginType == LoginType.email) {
      await _login(loginType, email: email, code: verityCode ?? 'das');
      final dbUtil = await DBUtil.getInstance();
      token = dbUtil.tokenBox.get(TOKEN_KEY);
    } else {
      try {
        await _login(loginType);
        final dbUtil = await DBUtil.getInstance();
        token = dbUtil.tokenBox.get(TOKEN_KEY);
      } catch (e) {
        if (e is SbtAuthException) {
          log('message');
        }
      }
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
      if (Platform.isIOS) {
        final completer = Completer<String?>();
        final appLinks = AppLinks();
        final linkSubscription = appLinks.uriLinkStream.listen((uri) {
          if (uri.toString().startsWith(_scheme)) {
            completer.complete(uri.queryParameters['token']);
          }
        });
        token = await completer.future;
        await closeInAppWebView();
        await linkSubscription.cancel();
      }
    }
    if (token == null) return;
    await _saveToken(token);
    await SbtAuthApi.init();
    await _initUser();
  }

  /// Send privateKey fragment
  Future<bool> sendBackupPrivateKey(String privateKey, String email) async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    try {
      await api.backupShare(privateKey, email);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Init deep links
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    var token = '';

    // Check initial link if app was in cold state (terminated)
    final appLink = await _appLinks.getInitialAppLink();
    if (appLink != null) {
      debugPrint('getInitialAppLink: $appLink');
      token = appLink.queryParameters['token'] ?? '';
      if (token != '') {
        await _saveToken(token);
        await SbtAuthApi.init();
        await _initUser();
      }
    }

    // Handle link when app is in warm state (front or background)
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('onAppLink: $uri');
      token = uri.queryParameters['token'] ?? '';
      if (token != '') {
        _saveToken(token);
        SbtAuthApi.init();
        _initUser();
      }
    });
  }

  /// Init core
  Future<AuthCore> initCore() async {
    final api = SbtAuthApi(baseUrl: _baseUrl);
    final remoteShareInfo = await api.fetchRemoteShare();
    final init = await core.init(
      address: remoteShareInfo.address,
      remote: remoteShareInfo.remote,
    );
    if (!init) throw SbtAuthException('New device detected');
    return core;
  }
}
