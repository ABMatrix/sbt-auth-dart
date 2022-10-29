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
// 初始化 sbtAuth 前需要先调用 initHive 方法
await SbtAuth.initHive();
// init sbtAuth
SbtAuth auth = SbtAuth(developMode: true, clientId: 'Demo', scheme: 'custom scheme');
```

## 登录创建sbt账户

SBTAuth 目前支持邮箱登录、Google Account、Facebook、Twitter。 如果使用邮箱验证码登录，需要先获取验证码

```dart
//  传入邮箱 email 发送验证码
await auth.api.sendVerifyCode(email);
```

```dart
// 使用邮箱登录，传入邮箱 email，然后传入验证码 code 或者密码 password 进行登录
await auth.login({email, code: '121212', password: '123456'});
```

登录成功后会获取用户信息，如果是新用户会直接创建账户进入 APP，可以设置登录密码,并且设置安全码，得到加密后的私钥碎片,支持发送加密碎片到邮箱

```dart
// 传入密码 password 来设置账户的登录密码
await auth.setLoginPassword(password);
// 获取私钥碎片 privateKey
final privateKey = auth.exportBackupPrivateKey();
// 传入安全码 password 来加密私钥碎片
final encryptPrivateKey = await encryptMsg(privateKey,password);
// 传入加密的私钥碎片 encryptPrivateKey，邮箱 email，和邮箱验证码 code来发送备份的私钥碎片
await auth.api.sendBackupPrivateKey(encryptPrivateKey, email, code);
```

如果是老用户，并且在新设备登录，则需要恢复私钥碎片，可以通过老设备授权的方式恢复，也可以通过原来用安全码加密后的私钥碎片进行恢复

```dart
// 1.老设备授权恢复
// 需要先获取老设备列表
fianl deviceList = await auth.api.getUserDeviceList();
// 从列表中选择设备，传人设备名 deviceName，调用方法来请求老设备授权
await auth.api.sendAuthRequest(deviceName);
// 输入老设备生成的授权码 code 获取授权
await auth.recoverWithDevice(code);

// 2.通过保存的私钥碎片恢复,获取碎片 backupPrivateKey 和密码 password 进行恢复
await auth.recoverWidthBackup(backupPrivateKey, password);
```

老设备在账户登录之后，或者在 APP 初始化且账户登录未过期时添加监听

```dart
sbtAuth.authRequestStreamController.stream.listen((event) {
  // 如果包含 deviceName 说明有新设备请求授权
      if (event.contains('deviceName')) {
        final deviceName = jsonDecode(event)['deviceName'];
        // 获取新设备名称后传入得到的设备名 deviceName 需要生成授权码授权新设备登录
            final authCode = await sbtAuth.approveAuthRequest(deviceName);
      }
    }
```

## sbt账户进行签名发送交易操作

调用 personal_sign 方法对消息进行签名

```dart
final provider = auth.provider;
// 传人要签名的数据 message 来获取签名
final signature = await provider?.request(RequestArgument(method: 'personal_sign', params: [message]));
```

创建并发送交易

```dart
final provider = auth.provider;
// 发送交易之前首先要设置16进制的 chainId
provider?.setChainId(chainId);
// 传入 交易的信息之后调用 sendTransaction 方法即可获取交易 hash
final txHash = await provider?.sendTransaction(
    to: to ,
    value: value,
    data: data,
    gasPrice: gasPrice ,
    gasLimit: gasLimit);
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
