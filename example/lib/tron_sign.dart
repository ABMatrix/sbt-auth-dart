import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

import 'grant_authorization.dart';

class TronSignPage extends StatefulWidget {
  final SbtAuth sbtAuth;

  const TronSignPage({super.key, required this.sbtAuth});

  @override
  State<TronSignPage> createState() => _TronSignPageState();
}

class _TronSignPageState extends State<TronSignPage> {
  String hash = '';
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
              child: const Text('Send trx'),
            ),
            const SizedBox(height: 10),
            Text(hash),
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

  _send() async {
    final singer = widget.sbtAuth.tronSigner;
    final res = await singer!.sendTokenTest(10);
    setState(() {
      hash = res.toString();
    });
  }
}
