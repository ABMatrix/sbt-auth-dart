import 'package:sbt_auth_dart/src/types/account.dart';

/// Remote share info
class RemoteShareInfo {
  /// Remote share info stored on server.
  RemoteShareInfo(this.address, this.remote);

  /// Wallet address.
  final String address;

  /// Remote share
  final Share remote;
}

/// User info
class UserInfo {
  /// User info
  UserInfo({
    required this.userLoginName,
    required this.userID,
    required this.username,
    required this.avatar,
    required this.userLoginParams,
    required this.userLoginType,
    required this.publicKeyAddress,
  });

  /// User from map
  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      userLoginName: map['userLoginName'] as String,
      userID: map['userID'] as String,
      username: map['username'] as String,
      avatar: map['avatar'] as String?,
      userLoginParams: map['userLoginParams'] as String,
      userLoginType: map['userLoginType'] as String,
      publicKeyAddress: map['publicKeyAddress'] as String?,
    );
  }

  /// User login name
  String userLoginName;

  /// User id
  String userID;

  /// Username, email address or twitter name.
  String username;

  /// Avatar
  String? avatar;

  /// Login params
  String userLoginParams;

  /// Login type, google | twitter | facebook | email
  String userLoginType;

  /// User wallet address
  String? publicKeyAddress;
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