import 'package:flutter/material.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';

import 'grant_authorization.dart';

class NearSignPage extends StatefulWidget {
  final SbtAuth sbtauth;

  const NearSignPage({required this.sbtauth, super.key});

  @override
  State<NearSignPage> createState() => _NearSignPageState();
}

class _NearSignPageState extends State<NearSignPage> {
  String hash = '';
  String tokenHash = '';
  String registerHash = '';
  String nearAddress = '';

  @override
  void initState() {
    initNear();
    super.initState();
  }

  initNear() async {
    try {
      await widget.sbtauth.init(chain: SbtChain.NEAR);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (widget.sbtauth.nearCore == null) {
      goToAuthorization();
    }
    setState(() {
      nearAddress = widget.sbtauth.user!.publicKeyAddress['NEAR'] == null
          ? widget.sbtauth.nearCore!
              .getAddress(isTestnet: widget.sbtauth.developMode)
          : widget.sbtauth.user!.publicKeyAddress['NEAR']['address'];
    });
    debugPrint(nearAddress);
  }

  goToAuthorization() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GrantAuthorizationPage(
                  auth: widget.sbtauth,
                  chain: SbtChain.NEAR,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Near Sign'),
      ),
      body: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth.recoverByOneDrive('123', chain: SbtChain.NEAR);
              },
              child: const Text('Recover by one drive')),
          const SizedBox(height: 40),
          Text(nearAddress),
          TextButton(
            onPressed: _send,
            child: const Text('Send near'),
          ),
          const SizedBox(height: 10),
          Text(hash),
          const SizedBox(height: 10),
          Text(registerHash),
        ],
      )),
    );
  }

  _send() async {
    final singer = widget.sbtauth.nearSigner;
    final res = await singer!.sendTokens(0.1, 'AyuKQw1JeAEFhADoqmVf99R52hXjs4VgT1rVv41owQ6Q');
    setState(() {
      hash = res.toString();
    });
  }
}
