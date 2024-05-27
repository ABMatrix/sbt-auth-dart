import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';
// ignore: depend_on_referenced_packages
import 'package:fixnum/fixnum.dart';

import 'grant_authorization.dart';

class TronSignPage extends StatefulWidget {
  final SbtAuth sbtAuth;

  const TronSignPage({super.key, required this.sbtAuth});

  @override
  State<TronSignPage> createState() => _TronSignPageState();
}

class _TronSignPageState extends State<TronSignPage> {
  String hash = '', hash2 = '';
  String tokenHash = '';
  String registerHash = '';
  String tronAddress = '';

  @override
  void initState() {
    initTron();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tron Sign')),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            TextButton(
                onPressed: () => widget.sbtAuth
                    .recoverByOneDrive('123', chain: SbtChain.TRON),
                child: const Text('Recover by one drive')),
            const SizedBox(height: 40),
            SelectableText(tronAddress),
            TextButton(
              onPressed: _send,
              child: const Text('Send 1 TRX'),
            ),
            const SizedBox(height: 10),
            SelectableText(hash),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _sendToken,
              child: const Text('Send 1 USDT'),
            ),
            const SizedBox(height: 10),
            SelectableText(hash2),
            const SizedBox(height: 10),
            Text(registerHash),
          ],
        ),
      ),
    );
  }

  initTron() async {
    try {
      await widget.sbtAuth.init(chain: SbtChain.TRON);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (widget.sbtAuth.tronCore == null) {
      goToAuthorization();
    }
    setState(() {
      tronAddress = widget.sbtAuth.user!.publicKeyAddress['TRON'] == null
          ? widget.sbtAuth.tronCore!
              .getAddress(isTestnet: widget.sbtAuth.developMode)
          : widget.sbtAuth.user!.publicKeyAddress['TRON']['address'];
    });
    debugPrint(tronAddress);
  }

  goToAuthorization() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GrantAuthorizationPage(
                  auth: widget.sbtAuth,
                  chain: SbtChain.TRON,
                )));
  }

  static const testAddress1 = 'TTW2v4AVnxyL4MJpXXBXViK8UAfHZE5Qgp';

  _send() async {
    final singer = widget.sbtAuth.tronSigner;
    // 发送 1 TRX
    final res = await singer!.sendTrx(
      ownerAddress: tronAddress,
      toAddress: testAddress1,
      amount: Int64(1000000),
    );
    setState(() {
      hash = res.toString();
    });
  }

  _sendToken() async {
    final singer = widget.sbtAuth.tronSigner;
    // 发送 1 USDT
    final res = await singer!.sendToken(
      amount: BigInt.from(1000000),
      ownerAddress: tronAddress,
      toAddress: testAddress1,
      contractAddress: 'TG3XXyExBkPp9nzdajDZsozEu4BkaSJozs',
    );
    setState(() {
      hash2 = res.toString();
    });
  }
}
