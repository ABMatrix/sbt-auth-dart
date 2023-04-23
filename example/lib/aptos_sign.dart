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
  String registerHash = '';
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
          TextButton(
            onPressed: _registerToken,
            child: const Text('Register token'),
          ),
          const SizedBox(height: 10),
          Text(registerHash),
        ],
      )),
    );
  }

  _send() async {
    final singer = widget.sbtauth.aptosSigner;
    final res = await singer!.transfer(
      aptosAddress,
      '0x8043a732812814f7d8fc6b16ed8a522b7d158b077d8a4856beb30992b98292e2',
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
        '0x8043a732812814f7d8fc6b16ed8a522b7d158b077d8a4856beb30992b98292e2',
        BigInt.from(10000),
        '0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9',
        'USDT');
    setState(() {
      tokenHash = res;
    });
  }

  _registerToken() async {
    final singer = widget.sbtauth.aptosSigner;
    final res = await singer!.registerToken(
        aptosAddress,
        '0x43417434fd869edee76cca2a4d2301e528a1551b1d719b75c350c3c97d15b8b9',
        'USDT');
    setState(() {
      registerHash = res;
    });
  }
}
