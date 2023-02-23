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


## 初始化 SBTAuth

注意：如果 `developMode` 为 `true`，则连接至测试服务，测试服务邮箱登录无需验证码，同时测试服务仅可连接至测试网。请在正式发布时确保 `developMode` 为 `false`。
SBTAuth Wallet 目前支持网络包括 Ethereum Polygon BNB Smart Chain。

```dart

// 初始化 SBTAuth 前需要先调用 initHive 方法，一般放在 main.dart 中
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SbtAuth.initHive();
  runApp(const MyApp());
}

// init sbtAuth
  SbtAuth auth = SbtAuth(developMode: true, clientId: 'Demo', scheme: 'Custom scheme');
```

## 登录 SBTAuth 账户

SBTAuth 目前支持邮箱登录、Google Account、Facebook、Twitter。 如果使用邮箱验证码登录，需要先获取验证码。

```dart

  //  传入邮箱 email 发送验证码
  await auth.api.sendVerifyCode(email);
```

```dart

  // 使用邮箱登录，传入邮箱 email，然后传入验证码 code 或者密码 password 进行登录
  await auth.login(LoginType.email,{email:'example@gmail.com', code: '121212'});

  // 使用第三方登录，只需要传入 LoginType
  await auth.login(LoginType.google);
```

登录成功后会获取用户信息，如果是新用户会直接创建账户进入 APP，可以设置登录密码,并且设置安全码，得到加密后的私钥碎片,支持发送加密碎片到邮箱。

```dart

if(auth.user?.backupPrivateKey != null){
  // 说明是新注册用户，推荐此时提醒用户通过邮箱备份。备份私钥时需用户输入安全密码，安全密码用于对私钥进行加密，保证备份私钥安全。
  // 传入密码 password 来设置账户的登录密码,同时可以设置支付密码 paymentPassword , paymentSwitch 表示是否开启密码
  await auth.api.setPassword(password, paymentPassword:"123456", paymentSwitch:true);
  
  // 如果用户开启了支付密码(auth.user.paymentSwitch == true),那么交易之前需要先验证支付密码 paymentPassword ,验证密码正确后再发起交易
  await auth.api.checkPaymentPassword(paymentPassword);
}

  // 传入加密的私钥碎片 encryptPrivateKey，邮箱 email，和邮箱验证码 code来发送备份的私钥碎片
  // chan 为备份的碎片的链,不传默认为 EVM
  await auth.sendBackupPrivateKey(encryptPrivateKey, email, code, chain: chian);
```

如果是已注册用户，并且在新设备登录，则需要恢复私钥碎片，可以通过已登录设备授权的方式恢复，也可以通过原来备份的私钥碎片进行恢复。

1. 已登录设备授权恢复

```dart

  // 需要先获取已登录设备列表
  fianl deviceList = await auth.api.getUserDeviceList();

  // 从列表中选择设备，传入设备名 deviceName ,需要恢复的链 chain 调用方法来请求已登录设备授权
  await auth.api.sendAuthRequest(deviceName, chain:chain);

  // 输入已登录设备生成的授权码 code ,要恢复的链 chain 获取授权完成恢复
  await auth.recoverWithDevice(code, chain:chain);
```

2. 通过保存的私钥碎片恢复,获取碎片 `backupPrivateKey` 和密码 `password` 进行恢复。

```dart

  // chain 表示需要恢复的链,不传默认恢复 EVM
  await auth.recoverWidthBackup(backupPrivateKey, password, chain:chain);
```

已登录设备在账户登录之后，或者在 APP 初始化且账户登录未过期时添加监听。

```dart

  sbtAuth.authRequestStreamController.stream.listen((event) {
    // 获取新设备名 deviceName
    final deviceName = jsonDecode(event)['deviceName'];
    // 获取请求授权恢复的链 keyType
    final keyType = jsonDecode(event)['keyType'];
    // 获取新设备名称后传入得到的设备名 deviceName ,链名 keyType 需要生成授权码授权新设备登录
    final authCode = await sbtAuth.approveAuthRequest(deviceName,chain:SbtChain.values.byName(keyType));
  }
```

## 使用 SBTAuth 钱包

### 调用 `personal_sign` 方法对消息进行签名

```dart

  final provider = auth.provider;

  // 传入要签名的数据 message 来获取签名
  final signature = await provider.request(RequestArgument(method: 'personal_sign', params: [message]));
```

### 发送交易

```dart

  /// EVM
  final provider = auth.provider;

  // 发送交易之前首先要设置 chainId 如：'0x5'
  provider.setChainId(chainId);

  // 传入交易的信息之后调用 sendTransaction() 方法即可获取交易 hash
  final txHash = await provider.sendTransaction(
      to: to ,
      value: value,
      data: data,
      gasPrice: gasPrice);

  /// SOLANA
  // Solana 的原生币和代币转账是不一样的,代币转账需要先查询自己和收款方的代币关联账户,并用自己的关联账户向对方关联账户转账代币,
  // 如果收款方没有关联账户,则需要先调用 createAssociatedTokenAccount() 方法给收款方创建关联账户
  // 所有的交易只需要构造 Instruction 调用 sendTransaction() 方法来发送交易
  final singer = sbtauth.solanaSinger!;
  
  
  // 转账需要传入构造的交易 instruction 和发送方 from
  final hash = await singer!.sendTransaction(instruction, from);
  
  // 创建关联账户只需要传入交易发送方 from 交易接收方 to 以及代币地址 tokenAddress 即可
  final hash =  await singer!.createAssociatedTokenAccount(from, to, tokenAddress);
  // * 注意 创建关联账户 hash 需要上链成功之后才可以进行代币转账


  /// BITCOIN
  final btcSign = sbtauth.bitcoinSinger!;
  
  // Bitcoin 转账只需要传入交易发送方 from ,交易接收方 to 以及交易数量 amount 即可
  // amount 不得小于 1000
  final hash = await btcSign.sendBtcTransaction(from, to, amount);
```

## 白名单相关功能

交易白名单是更高级的安全模式，开启白名单之后账户只能对白名单内的地址进行转账交易

```dart

  // 开启修改关闭等对白名单的操作都需要进行邮箱验证码验证，所以如果用户没有绑定邮箱，则需要提示用户先备份私钥并绑定邮箱

  // 输入加密私钥的安全码 password，邮箱 email，邮箱验证码 code
  await sbtauth.sendBackupPrivateKey(password, email, code);

  // 开启/关闭白名单
  // 输入邮箱验证码 authCode，白名单开启关闭状态 whitelistSwitch 来开启或关闭白名单
  await sbtauth.switchWhiteList(authCode, whitelistSwitch：whitelistSwitch);

  // 获取白名单列表
  // 可选参数 network，输入即可查询对应网络的白名单列表,不输即为所有网络的白名单列表
  fianl whiteList = await sbtauth.api.getUserWhiteList(page, pageSize, network:network);

  // 获取单个白名单详情
  // 输入白名单的 id userWhitelistID 来获取详情
  final whiteListItem = await sbtAuth.api.getUserWhiteListItem(userWhitelistID);

  // 新增白名单
  // 输入邮箱验证码 authCode，白名单地址 address，白名单名称 name，白名单网络 network 新增白名单地址, tolowerCase 表示是否需要小写, EVM 系需小写
  await sbtauth.createWhiteList(authCode, address, name, network, tolowerCase:false);

  // 删除白名单
  // 输入邮箱验证码 authCode，白名单 id userWhitelistID 来删除白名单
  await sbtauth.deleteWhiteList(authCode, userWhitelistID);

  // 修改白名单
  // 输入邮箱验证码 authCode,白名单地址 address，白名单名称 name，白名单 id userWhitelistID，用户 id userId 和白名单网络 network 来修改白名单, tolowerCase 表示是否需要小写, EVM 系需小写
  await sbtAuth.editWhiteList(authCode, address, name, userWhitelistID, userId, network, tolowerCase:true);
```


## 其他功能

可以设置登录有效期，延长或缩短登录过期时间

```dart

  // 只需要调用 setUserToken() 方法,传入登录有效时间 tokenTime (单位:分钟)
  await auth.api.setUserToken(tokenTime);
```

### 目前支持的网络以及网络名称 network

```

    //以太坊
    ETH("eth", 1),

    //币安链
    BSC("bsc", 56),

    //Polygon
    Polygon("polygon", 137),

    //Solana
    Solana("solana")
    
    ///Bitcoin
    Bitcoin("bitcoin")

    //以太坊测试网 Goerli
    Goerli("eth_goerli", 5),

    //币安链测试网
    BSC_test("bsc_chapel", 97),

    //Polygon testnet
    Polygon_test("polygon_mumbai", 80001),

    //Solana devnet
    Solana_devnet("solana_devnet")
    
    //Bitcoin testnet
    Bitcoin_testnet("btc_testnet")
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
