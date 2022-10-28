# Sbt Auth Dart

[![Pub Version](https://img.shields.io/pub/v/sbt_auth_dart?color=blueviolet)](https://pub.dev/packages/sbt_auth_dart)
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![License: MIT][license_badge]][license_link]

SBTAuth SDK for flutter.

## Setup

### iOS

Add custom url scheme to Info.plist.

```
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Viewer</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>{your custom scheme}</string>
    </array>
  </dict>
</array>
```

### Android

Add intent-filter inside activity

```
<activity ...>
  <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW" />
          <category android:name="android.intent.category.DEFAULT" />
          <category android:name="android.intent.category.BROWSABLE" />
          <data android:scheme="{your custom scheme}" />
  </intent-filter>
</activity>
```

## Get started

## Running Tests 🧪

For first time users, install the [very_good_cli][very_good_cli_link]:

```sh
dart pub global activate very_good_cli
```

To run all unit tests:

```sh
very_good test --coverage
```

To view the generated coverage report you can use [lcov](https://github.com/linux-test-project/lcov)
.

```sh
# Generate Coverage Report
genhtml coverage/lcov.info -o coverage/

# Open Coverage Report
open coverage/index.html
```

## 初始化 SBTAuth

注意：如果 developMode 为 true，则连接至测试服务，测试服务邮箱登录无需验证码，同时测试服务仅可连接至测试网。请在正式发布时确保 developMode 为 false。
SBTAuth Wallet 目前支持网络包括 Ethereum Polygon BNB Smart Chain。

```dart
// init sbtAuth
SbtAuth auth =SbtAuth(developMode: true, clientId: 'Demo', scheme: 'custom scheme');
```

## 登录创建sbt账户

SBTAuth 目前支持邮箱登录、Google Account、Facebook、Twitter。 如果使用邮箱验证码登录，需要先获取验证码

```dart
//  Send verify Code
await sendVerifyCode(email);
```

```dart
// User login
await sbtauth.login({email,code:'121212',password:'123456'});
```

登录成功后会获取用户信息，如果是新用户会直接创建账户进入APP，可以设置登录密码,并且设置安全码，得到加密后的私钥碎片,支持发送加密碎片到邮箱

```dart
// Set password
await setLoginPassword(password);
// Get privateKeyFragment3
final privateKeyFragment = await getPrivateKeyFragment3(password);
// Send privateKey fragment
await sendBackupPrivateKey(privateKey,email,code);
```

如果是老用户，并且在新设备登录，则需要恢复私钥碎片，可以通过老设备授权的方式恢复，也可以通过原来用安全码加密后的私钥碎片进行恢复

```dart

```

[flutter_install_link]: https://docs.flutter.dev/get-started/install

[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg

[license_link]: https://opensource.org/licenses/MIT

[logo_black]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_black.png#gh-light-mode-only

[logo_white]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_white.png#gh-dark-mode-only

[mason_link]: https://github.com/felangel/mason

[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg

[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis

[very_good_cli_link]: https://pub.dev/packages/very_good_cli

[very_good_coverage_link]: https://github.com/marketplace/actions/very-good-coverage

[very_good_ventures_link]: https://verygood.ventures

[very_good_ventures_link_light]: https://verygood.ventures#gh-light-mode-only

[very_good_ventures_link_dark]: https://verygood.ventures#gh-dark-mode-only

[very_good_workflows_link]: https://github.com/VeryGoodOpenSource/very_good_workflows
