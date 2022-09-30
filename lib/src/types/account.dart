/// Share for mpc
class Share {
  /// Share
  Share({
    required this.privateKey,
    required this.extraData,
  });
  /// Share private key
  final String privateKey;
  /// Extra data for share, inlcude threshold
  final String extraData;
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
