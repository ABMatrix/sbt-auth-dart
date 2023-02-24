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

  final TextEditingController _emailController = TextEditingController();

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
          TextButton(
              onPressed: () {
                widget.sbtauth
                    .backupWithOneDrive('123', chain: SbtChain.BITCOIN);
              },
              child: const Text('Backup by one drive')),
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth
                    .recoverByOneDrive('123', chain: SbtChain.BITCOIN);
              },
              child: const Text('Recover by one drive')),
          const SizedBox(height: 40),
          TextField(
            controller: _emailController,
          ),
          TextButton(
              onPressed: () {
                widget.sbtauth.sendBackupPrivateKey(
                  '123',
                  _emailController.text.trim(),
                  'code',
                  chain: SbtChain.BITCOIN,
                );
              },
              child: const Text('send')),
          const SizedBox(height: 20),
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
    final res = await btcSign.sendBtcTransaction(bitcoinAddress, 'tb1qfzl9x08y4lth4a3rl9727rwl0fe2d7qvz3vz6s', 515042);
    setState(() {
      hash = res;
    });
  }
}
