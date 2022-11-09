

/// Share for mpc
class Share {
  /// Share
  Share({
    required this.privateKey,
    this.publicKey='',
    required this.extraData,
  });

  /// Share from map.
  factory Share.fromMap(Map<dynamic, dynamic> map) {
    return Share(
      privateKey: map['privateKey'] as String,
      publicKey:( map['publicKey']??'') as String,
      extraData: map['extraData'] as String,
    );
  }

  /// Share private key
  final String privateKey;

  /// Share public key
  final String publicKey;

  /// Extra data for share, inlcude threshold
  final String extraData;

  /// Share tojson
  Map<String, String> toJson() {
    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
      'extraData': extraData
    };
  }
}

/// Mpc account
class MpcAccount {
  /// Mpc account
  MpcAccount({
    required this.address,
    required this.shares,
  });

  /// Address
  final String address;

  /// Shares for the account
  final List<Share> shares;
}

/// Saved share
class SavedShare {
  /// Saved share
  SavedShare({
    required this.address,
    required this.share,
  });

  /// Address
  final String address;

  /// Share
  final Share share;
}
