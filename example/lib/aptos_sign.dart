import 'package:flutter/material.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';

import 'grant_authorization.dart';

class AptosSignPage extends StatefulWidget {
  final SbtAuth sbtauth;

  const AptosSignPage({required this.sbtauth, super.key});

  @override
  State<AptosSignPage> createState() => _AptosSignPageState();
}

class _AptosSignPageState extends State<AptosSignPage> {
  String hash = '';
  String tokenHash = '';
  String aptosAddress = '';

  @override
  void initState() {
    initAptos();
    super.initState();
  }

  initAptos() async {
    try {
      await widget.sbtauth.init(chain: SbtChain.APTOS);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (widget.sbtauth.aptosCore == null) {
      goToAuthorization();
    }
    setState(() {
      aptosAddress = widget.sbtauth.user!.publicKeyAddress['APTOS'] == null
          ? widget.sbtauth.aptosCore!
              .getAddress(isTestnet: widget.sbtauth.developMode)
          : widget.sbtauth.user!.publicKeyAddress['APTOS']['address'];
    });
    debugPrint(aptosAddress);
  }

  goToAuthorization() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GrantAuthorizationPage(
                  auth: widget.sbtauth,
                  chain: SbtChain.APTOS,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aptos Sign'),
      ),
      body: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth.recoverByOneDrive('123', chain: SbtChain.APTOS);
              },
              child: const Text('Recover by one drive')),
          const SizedBox(height: 40),
          Text(aptosAddress),
          TextButton(
            onPressed: _send,
            child: const Text('Send apt'),
          ),
          const SizedBox(height: 10),
          Text(hash),
          TextButton(
            onPressed: _sendToken,
            child: const Text('Send token'),
          ),
          const SizedBox(height: 10),
          Text(tokenHash),
        ],
      )),
    );
  }

  _send() async {
    final singer = widget.sbtauth.aptosSigner;
    final res = await singer!.transfer(
      aptosAddress,
      aptosAddress,
      BigInt.from(100000),
    );
    setState(() {
      hash = res;
    });
  }

  _sendToken() async {
    final singer = widget.sbtauth.aptosSigner;
    final res = await singer!.tokenTransfer(
      aptosAddress,
      '0xa2c66f30b1ab14e5008608c763cbccb3e5b2ec4849f4b5b6857d0a8bd202ceca',
      BigInt.from(100000),
      '0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9',
      'USDT'
    );
    setState(() {
      hash = res;
    });
  }
}
