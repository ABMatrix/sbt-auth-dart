import 'dart:convert';

import 'package:sbt_auth_dart/src/types/account.dart';

/// Remote share info
class RemoteShareInfo {
  /// Remote share info stored on server.
  RemoteShareInfo(
    this.address,
    this.remote,
    this.localAux,
    this.backupAux,
    this.localHash,
    this.backupHash,
  );

  /// Wallet address.
  final String address;

  /// Remote share
  final Share remote;

  /// Local aux
  final String localAux;

  /// Back up aux
  final String backupAux;

  /// local hash
  final String localHash;

  /// backup hash
  final String backupHash;
}

/// User info
class UserInfo {
  /// User info
  UserInfo({
    required this.userLoginName,
    required this.userID,
    required this.username,
    required this.avatar,
    required this.email,
    required this.userLoginType,
    required this.publicKeyAddress,
    required this.whitelistSwitch,
    required this.tokenTime,
    required this.paymentPwd,
    required this.userOtp,
    required this.keyGenerate,
    required this.oldDevice,
  });

  /// User from map
  factory UserInfo.fromMap(Map<dynamic, dynamic> map) {
    return UserInfo(
      userLoginName: map['userLoginName'] as String,
      userID: map['userID'] as String,
      username: map['username'] as String,
      avatar: map['avatar'] as String?,
      email: (map['email'] ?? '') as String,
      userLoginType: map['userLoginType'] as String,
      publicKeyAddress: map['publicKeyAddress'] as Map<dynamic, dynamic>,
      whitelistSwitch: (map['userWhitelist'] ?? false) as bool,
      tokenTime: (map['tokenTime'] ?? '0') as String,
      paymentPwd: (map['paymentPwd'] ?? false) as bool,
      userOtp: (map['userOtp'] ?? false) as bool,
      keyGenerate: (map['keyGenerate'] ?? false) as bool,
      oldDevice: (map['oldDevice'] ?? true) as bool,
    );
  }

  /// User to json
  Map<String, dynamic> toJson() {
    return {
      'userLoginName': userLoginName,
      'userID': userID,
      'username': username,
      'avatar': avatar,
      'email': email,
      'userLoginType': userLoginType,
      'publicKeyAddress': publicKeyAddress,
      'whitelistSwitch': whitelistSwitch,
      'tokenTime': tokenTime,
      'paymentPwd': paymentPwd,
      'userOtp': userOtp,
      'keyGenerate': keyGenerate,
      'oldDevice': oldDevice,
    };
  }

  /// User login name
  String userLoginName;

  /// User id
  String userID;

  /// Username, email address or twitter name.
  String username;

  /// Avatar
  String? avatar;

  /// Email
  String email;

  /// Login type, google | twitter | facebook | email
  String userLoginType;

  /// User wallet address
  Map<dynamic, dynamic> publicKeyAddress;

  /// White list switch
  bool whitelistSwitch;

  /// Token time
  String? tokenTime;

  /// Use payment password
  bool paymentPwd;

  /// Use otp
  bool userOtp;

  /// Backup private key
  String? backupPrivateKey;

  /// Export privatekry
  bool keyGenerate;

  /// Old device
  bool oldDevice;
}

/// Login QrCode status
class QrCodeStatus {
  /// QrCode status
  QrCodeStatus({
    required this.qrcodeName,
    required this.qrcodeClientID,
    required this.qrcodeExpireAt,
    required this.fail,
    required this.qrcodeEncryptedFragment,
    this.qrcodeAuthToken,
  });

  /// QrCode status from map
  factory QrCodeStatus.fromMap(Map<String, dynamic> map) {
    return QrCodeStatus(
      qrcodeName: (map['qrcodeName'] ?? '') as String,
      qrcodeClientID: (map['qrcodeClientID'] ?? '') as String,
      qrcodeExpireAt: (map['qrcodeExpireAt'] ?? '') as String,
      qrcodeAuthToken: (map['qrcodeAuthToken'] ?? '') as String,
      qrcodeEncryptedFragment: (map['qrcodeEncryptedFragment'] ?? '') as String,
      fail: (map['fail'] ?? false) as bool,
    );
  }

  /// QrCode name
  String qrcodeName;

  /// Clientid
  String qrcodeClientID;

  /// QrCode expire data
  String qrcodeExpireAt;

  ///  QrCode data
  String? qrcodeAuthToken;

  /// QrCode
  bool fail;

  /// qrcode EncryptedFragment
  String? qrcodeEncryptedFragment;
}

/// Device
class Device {
  /// Device
  Device({
    required this.deviceJoinTime,
    required this.userId,
    required this.deviceID,
    required this.deviceName,
  });

  /// Device from map
  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      deviceJoinTime: (map['deviceJoinTime'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      deviceID: (map['deviceID'] ?? '') as String,
      deviceName: (map['deviceName'] ?? '') as String,
    );
  }

  /// Join time
  String? deviceJoinTime;

  /// User id
  String? userId;

  /// Device id
  String? deviceID;

  /// Device name
  String? deviceName;
}

/// UserWhiteListItem
class UserWhiteListItem {
  /// UserWhiteListItem
  UserWhiteListItem({
    required this.userWhitelistName,
    required this.userWhitelistNetwork,
    required this.userWhitelistUserId,
    required this.userWhitelistID,
    required this.userWhitelistAddress,
  });

  /// UserWhiteListItem from map
  factory UserWhiteListItem.fromMap(Map<String, dynamic> map) {
    return UserWhiteListItem(
      userWhitelistName: (map['userWhitelistName'] ?? '') as String,
      userWhitelistNetwork: (map['userWhitelistNetwork'] ?? '') as String,
      userWhitelistUserId: (map['userWhitelistUserId'] ?? '') as String,
      userWhitelistID: (map['userWhitelistID'] ?? '') as String,
      userWhitelistAddress: (map['userWhitelistAddress'] ?? '') as String,
    );
  }

  /// Name
  String userWhitelistName;

  /// Network
  String userWhitelistNetwork;

  /// UserId
  String userWhitelistUserId;

  /// Id
  String userWhitelistID;

  /// Address
  String userWhitelistAddress;
}

/// Token list info
class TokenListInfo {
  /// Token list info
  TokenListInfo({
    required this.hasPrev,
    required this.pageNo,
    required this.totalPage,
    required this.pageSize,
    required this.hasNext,
    required this.totalCount,
    required this.items,
  });

  /// TokenListInfo from map
  factory TokenListInfo.fromMap(Map<String, dynamic> map) {
    return TokenListInfo(
      hasPrev: (map['hasPrev'] ?? false) as bool,
      pageNo: (map['pageNo'] ?? 1) as int,
      totalPage: (map['totalPage'] ?? 0) as int,
      pageSize: (map['pageSize'] ?? 0) as int,
      hasNext: (map['hasNext'] ?? false) as bool,
      totalCount: (map['totalCount'] ?? '0') as String,
      items: [
        for (final t in map['items'] as List? ?? [])
          TokenInfo.fromMap(t as Map<String, dynamic>),
      ],
    );
  }

  /// Has prev
  late bool hasPrev;

  /// PageNo
  late int pageNo;

  /// Total page
  late int totalPage;

  /// Page size
  late int pageSize;

  /// Has next
  late bool hasNext;

  /// Total count
  late String totalCount;

  /// Items
  late List<TokenInfo> items;
}

/// Token info
class TokenInfo {
  /// Token info
  TokenInfo({
    required this.name,
    required this.tokenID,
    required this.symbol,
    required this.iconUrl,
    required this.network,
    required this.address,
    required this.tokenType,
    required this.decimals,
    required this.description,
    required this.additionalInfo,
    required this.totalSupply,
  });

  /// TokenInfo from map
  factory TokenInfo.fromMap(Map<String, dynamic> map) {
    return TokenInfo(
      name: (map['name'] ?? map['tokenInfoName'] ?? '') as String,
      tokenID: (map['tokenID'] ?? map['tokenInfoID'] ?? '') as String,
      symbol: (map['symbol'] ?? map['tokenInfoSymbol'] ?? '') as String,
      iconUrl: (map['iconUrl'] ?? map['tokenInfoIconUrl'] ?? '') as String,
      network: (map['network'] ?? map['tokenInfoNetwork'] ?? '') as String,
      address: (map['address'] ?? map['tokenInfoAddress'] ?? '') as String,
      tokenType:
          (map['tokenType'] ?? map['tokenInfoTokenType'] ?? '') as String,
      decimals: (map['decimals'] ?? 0) as int,
      description: (map['description'] ?? '') as String,
      additionalInfo: (map['additionalInfo'] ?? '') as String,
      totalSupply: (map['totalSupply'] ?? '') as String,
    );
  }

  /// Id
  String? tokenID;

  /// Name
  String? name;

  /// Network
  String? network;

  /// Address
  String? address;

  /// Symbol
  String? symbol;

  /// Icon
  String? iconUrl;

  /// Type
  String? tokenType;

  /// Decimals
  int? decimals;

  /// Description
  String? description;

  /// Additional info
  String? additionalInfo;

  /// Total supply
  String? totalSupply;

  /// to json
  String toJson() => json.encode(toMap());

  /// to map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tokenID': tokenID,
      'symbol': symbol,
      'iconUrl': iconUrl,
      'network': network,
      'address': address,
      'tokenType': tokenType,
      'decimals': decimals,
      'description': description,
      'additionalInfo': additionalInfo,
      'totalSupply': totalSupply,
    };
  }
}

/// User Token List
class UserTokenList {
  /// User Token List
  UserTokenList({
    required this.hasPrev,
    required this.pageNo,
    required this.totalPage,
    required this.pageSize,
    required this.hasNext,
    required this.totalCount,
    required this.items,
  });

  /// UserTokenList from map
  factory UserTokenList.fromMap(Map<String, dynamic> map) {
    return UserTokenList(
      hasPrev: (map['hasPrev'] ?? false) as bool,
      pageNo: (map['pageNo'] ?? 1) as int,
      totalPage: (map['totalPage'] ?? 0) as int,
      pageSize: (map['pageSize'] ?? 0) as int,
      hasNext: (map['hasNext'] ?? false) as bool,
      totalCount: (map['totalCount'] ?? '0') as String,
      items: [
        for (final t in map['items'] as List? ?? [])
          UserToken.fromMap(t as Map<String, dynamic>),
      ],
    );
  }

  /// Has prev
  late bool hasPrev;

  /// PageNo
  late int pageNo;

  /// Total page
  late int totalPage;

  /// Page size
  late int pageSize;

  /// Has next
  late bool hasNext;

  /// Total count
  late String totalCount;

  /// Items
  late List<UserToken> items;
}

/// User Token
class UserToken {
  /// User Token
  UserToken({
    required this.userTokenID,
    required this.userTokenUserID,
    required this.userTokenTokenID,
    required this.userTokenName,
    required this.network,
    required this.address,
    required this.symbol,
    required this.tokenType,
    required this.iconUrl,
    required this.amount,
    required this.decimals,
    required this.limitDay,
    required this.limitSingle,
    required this.strategyID,
  });

  /// TokenInfo from map
  factory UserToken.fromMap(Map<String, dynamic> map) {
    return UserToken(
      userTokenID: (map['userTokenID'] ?? '') as String,
      userTokenUserID: (map['userTokenUserID'] ?? '') as String,
      userTokenTokenID: (map['userTokenTokenID'] ?? '') as String,
      userTokenName: (map['userTokenName'] ?? '') as String,
      network: (map['network'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      symbol: (map['symbol'] ?? '') as String,
      tokenType: (map['tokenType'] ?? '') as String,
      iconUrl: (map['iconUrl'] ?? '') as String,
      amount: (map['amount'] ?? '') as String,
      decimals: (map['decimals'] ?? 0) as int,
      limitDay: (map['limitDay']) as String?,
      limitSingle: (map['limitSingle']) as String?,
      strategyID: (map['strategyID']) as String?,
    );
  }

  /// Id
  String? userTokenID;

  /// User id
  String? userTokenUserID;

  /// Token id
  String? userTokenTokenID;

  /// Name
  String? userTokenName;

  /// Network
  String? network;

  /// Address
  String? address;

  /// Symbol
  String? symbol;

  /// Token Type
  String? tokenType;

  /// IconUrl
  String? iconUrl;

  /// Amount
  String? amount;

  /// Decimals
  int? decimals;

  /// Limit Day
  String? limitDay;

  /// Limit Single
  String? limitSingle;

  /// Strategy id
  String? strategyID;

  /// to json
  String toJson() => json.encode(toMap());

  /// to map
  Map<String, dynamic> toMap() {
    return {
      'userTokenID': userTokenID,
      'userTokenUserID': userTokenUserID,
      'userTokenTokenID': userTokenTokenID,
      'userTokenName': userTokenName,
      'network': network,
      'address': address,
      'symbol': symbol,
      'tokenType': tokenType,
      'iconUrl': iconUrl,
      'amount': amount,
      'decimals': decimals,
      'limitDay': limitDay,
      'limitSingle': limitSingle,
      'strategyID': strategyID,
    };
  }
}

/// ERC20TokenInfo
class ERC20TokenInfo {
  /// ERC20TokenInfo
  ERC20TokenInfo({
    required this.tokenInfoName,
    required this.tokenInfoID,
    required this.tokenInfoSymbol,
    required this.tokenInfoIconUrl,
    required this.tokenInfoNetwork,
    required this.tokenInfoAddress,
    required this.tokenInfoTokenType,
  });

  /// from map
  factory ERC20TokenInfo.fromMap(Map<String, dynamic> map) {
    return ERC20TokenInfo(
      tokenInfoName: (map['tokenInfoName'] ?? '') as String,
      tokenInfoID: (map['tokenInfoID'] ?? '') as String,
      tokenInfoSymbol: (map['tokenInfoSymbol'] ?? '') as String,
      tokenInfoIconUrl: (map['tokenInfoIconUrl'] ?? '') as String,
      tokenInfoNetwork: (map['tokenInfoNetwork'] ?? '') as String,
      tokenInfoAddress: (map['tokenInfoAddress'] ?? '') as String,
      tokenInfoTokenType: (map['tokenInfoTokenType'] ?? '') as String,
    );
  }

  /// Token Info Name
  String tokenInfoName;

  /// Token Info ID
  String tokenInfoID;

  /// Token Info Symbol
  String tokenInfoSymbol;

  /// Token Info IconUrl
  String tokenInfoIconUrl;

  /// Token Info Network
  String tokenInfoNetwork;

  /// Token Info Address
  String tokenInfoAddress;

  /// Token Info TokenType
  String tokenInfoTokenType;
}

/// Strategys
class SbtStrategy {
  ///Strategys
  SbtStrategy({
    required this.strategyUserID,
    required this.strategyType,
    required this.strategyStrategyInfo,
    required this.strategyNetwork,
    required this.strategyID,
  });

  /// Strategys from map
  factory SbtStrategy.fromMap(Map<String, dynamic> map) {
    return SbtStrategy(
      strategyUserID: (map['strategyUserID'] ?? '') as String,
      strategyType: (map['strategyType'] ?? '') as String,
      strategyStrategyInfo: (map['strategyStrategyInfo'] ?? '') as String,
      strategyNetwork: (map['strategyNetwork'] ?? '') as String,
      strategyID: (map['strategyID'] ?? '') as String,
    );
  }

  /// Strategy User ID
  String strategyUserID;

  /// Strategy Type
  String strategyType;

  /// Strategy Info
  String strategyStrategyInfo;

  /// Strategy Network
  String strategyNetwork;

  /// Strategy ID
  String strategyID;
}
