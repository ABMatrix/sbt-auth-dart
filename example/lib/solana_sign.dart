import 'package:flutter/material.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:solana/solana.dart';

import 'grant_authorization.dart';

class SolanaSignPage extends StatefulWidget {
  final SbtAuth sbtauth;

  const SolanaSignPage({required this.sbtauth, super.key});

  @override
  State<SolanaSignPage> createState() => _SolanaSignPageState();
}

class _SolanaSignPageState extends State<SolanaSignPage> {
  String _signature = '';
  String _result = '';
  String hash = '';
  String solanaAddress = '';

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    initSolana();
    super.initState();
  }

  initSolana() async {
    try {
      await widget.sbtauth.init(chain: SbtChain.SOLANA);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (widget.sbtauth.solanaSinger == null) {
      goToAuthorization();
    }
    setState(() {
      solanaAddress = widget.sbtauth.user!.publicKeyAddress['SOLANA'] == null
          ? widget.sbtauth.solanaCore!.getAddress()
          : widget.sbtauth.user!.publicKeyAddress['SOLANA']['address'];
    });
    debugPrint(solanaAddress);
  }

  goToAuthorization() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GrantAuthorizationPage(
                  auth: widget.sbtauth,
                  chain: SbtChain.SOLANA,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana Sign'),
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
              onPressed: () {
                widget.sbtauth.backupWithOneDrive('123', chain: SbtChain.SOLANA);
              },
              child: const Text('Backup by one drive')),
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth.recoverByOneDrive('123', chain: SbtChain.SOLANA);
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
                  chain: SbtChain.SOLANA,
                );
              },
              child: const Text('send')),
          const SizedBox(height: 20),
          Text(solanaAddress),
          TextButton(
            onPressed: _sendSol,
            child: const Text('Send sol'),
          ),
          const SizedBox(height: 10),
          Text(hash),
          const SizedBox(height: 10),
          Text(_signature),
          const SizedBox(height: 10),
          Text(_result),
          const SizedBox(height: 10),
        ],
      )),
    );
  }

  _sendSol() async {
    final singer = widget.sbtauth.solanaSinger;
    final fromAddress = Ed25519HDPublicKey.fromBase58(solanaAddress);
    final toAddress = Ed25519HDPublicKey.fromBase58(solanaAddress);
    final instruction = SystemInstruction.transfer(
      fundingAccount: fromAddress,
      recipientAccount: toAddress,
      lamports: 0,
    );
    final res = await singer!.sendTransaction(instruction, fromAddress);
    setState(() {
      hash = res;
    });
  }
}
