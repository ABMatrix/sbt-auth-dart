import 'package:flutter/material.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';

import 'grant_authorization.dart';

class BitcoinSignPage extends StatefulWidget {
  final SbtAuth sbtauth;

  const BitcoinSignPage({required this.sbtauth, super.key});

  @override
  State<BitcoinSignPage> createState() => _BitcoinSignPageState();
}

class _BitcoinSignPageState extends State<BitcoinSignPage> {
  String hash = '';
  String bitcoinAddress = '';

  @override
  void initState() {
    initBitcoin();
    super.initState();
  }

  initBitcoin() async {
    try {
      await widget.sbtauth.init(chain: SbtChain.BITCOIN);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (widget.sbtauth.bitcoinSinger == null) {
      goToAuthorization();
    }
    setState(() {
      bitcoinAddress = widget.sbtauth.user!.publicKeyAddress['BITCOIN'] == null
          ? widget.sbtauth.bitcoinCore!
              .getAddress(isTestnet: widget.sbtauth.developMode)
          : widget.sbtauth.user!.publicKeyAddress['BITCOIN']['address'];
    });
    debugPrint(bitcoinAddress);
  }

  goToAuthorization() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GrantAuthorizationPage(
                  auth: widget.sbtauth,
                  chain: SbtChain.BITCOIN,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitcoin Sign'),
      ),
      body: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth
                    .recoverByOneDrive('123', chain: SbtChain.BITCOIN);
              },
              child: const Text('Recover by one drive')),
          const SizedBox(height: 40),
          Text(bitcoinAddress),
          TextButton(
            onPressed: _sendBtc,
            child: const Text('Send btc'),
          ),
          const SizedBox(height: 10),
          Text(hash),
          const SizedBox(height: 10),
        ],
      )),
    );
  }

  _sendBtc()async{
    final btcSign = widget.sbtauth.bitcoinSinger!;
    final res = await btcSign.sendBtcTransaction(bitcoinAddress, 'tb1qkzftqpmn5z078twuf48ktj55clztr8fgfxm0vq', 100000);
    setState(() {
      hash = res;
    });
  }
}
