import 'package:flutter/material.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';

import 'grant_authorization.dart';

class DogecoinSignPage extends StatefulWidget {
  final SbtAuth sbtauth;

  const DogecoinSignPage({required this.sbtauth, super.key});

  @override
  State<DogecoinSignPage> createState() => _DogecoinSignPageState();
}

class _DogecoinSignPageState extends State<DogecoinSignPage> {
  String hash = '';
  String dogecoinAddress = '';

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    initDogecoin();
    super.initState();
  }

  initDogecoin() async {
    try {
      await widget.sbtauth.init(chain: SbtChain.DOGECOIN);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (widget.sbtauth.dogecoinSinger == null) {
      goToAuthorization();
    }
    setState(() {
      dogecoinAddress = widget.sbtauth.user!.publicKeyAddress['DOGECOIN'] == null
          ? widget.sbtauth.dogecoinCore!
          .getAddress(isTestnet: widget.sbtauth.developMode)
          : widget.sbtauth.user!.publicKeyAddress['DOGECOIN']['address'];
    });
    debugPrint(dogecoinAddress);
  }

  goToAuthorization() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GrantAuthorizationPage(
              auth: widget.sbtauth,
              chain: SbtChain.DOGECOIN,
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dogecoin Sign'),
      ),
      body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                  onPressed: () {
                    widget.sbtauth
                        .backupWithOneDrive('123', chain: SbtChain.DOGECOIN);
                  },
                  child: const Text('Backup by one drive')),
              const SizedBox(height: 40),
              TextButton(
                  onPressed: () {
                    widget.sbtauth
                        .recoverByOneDrive('123', chain: SbtChain.DOGECOIN);
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
              Text(dogecoinAddress),
              TextButton(
                onPressed: _sendDoge,
                child: const Text('Send doge'),
              ),
              const SizedBox(height: 10),
              Text(hash),
              const SizedBox(height: 10),
            ],
          )),
    );
  }

  _sendDoge()async{
    final dogeSign = widget.sbtauth.dogecoinSinger!;
    final res = await dogeSign.sendBtcTransaction(dogecoinAddress, 'DQnjTDX2CkJBBCjicNJMiFYk2W7cTojYFJ', 30000);
    setState(() {
      hash = res;
    });
  }
}
