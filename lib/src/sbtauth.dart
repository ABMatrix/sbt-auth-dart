import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:sbt_auth_dart/src/api.dart';
import 'package:sbt_auth_dart/src/core/core.dart';
import 'package:sbt_auth_dart/src/types/exception.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String get _baseUrl => developMode
      ? 'https://test-api.sbtauth.io/sbt-auth'
      : 'https://api.sbtauth.io/sbt-auth';

  /// Login with sbtauth
  Future<AuthCore?> login(
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
        launchUrl(
          Uri.parse(loginUrl),
        ),
      );
      final completer = Completer<String?>();
      final appLinks = AppLinks();
      final linkSubscription = appLinks.uriLinkStream.listen((uri) {
        if (uri.toString().startsWith('sbtauth')) {
          completer.complete(uri.queryParameters['token']);
        }
      });
      token = await completer.future;
      await closeInAppWebView();
      await linkSubscription.cancel();
    }
    // return token;
    if (token == null) return null;
    final api = SbtAuthApi(token: token, baseUrl: _baseUrl);
    final userInfo = await api.getUserInfo();
    final core = AuthCore();
    if (userInfo.publicKeyAddress == null) {
      final account = await core.generatePubKey();
      await api.uploadShares(account.shares, account.address);
    } else {
      final remoteShareInfo = await api.fetchRemoteShare();
      final init = await core.init(
        address: remoteShareInfo.address,
        remote: remoteShareInfo.remote,
      );
      if (!init) throw SbtAuthException('New device detected');
    }
    return core;
  }
}
