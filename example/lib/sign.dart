import 'package:example/white_list.dart';
import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:solana/solana.dart';

class SignPage extends StatefulWidget {
  final String address;
  final String solanaAddress;
  final SbtAuth sbtauth;

  const SignPage(
      {required this.address,
      this.solanaAddress = '**',
      required this.sbtauth,
      super.key});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  String _signature = '';
  String _result = '';
  String hash = '';

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    print(widget.address);
    print(widget.solanaAddress);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => WhiteListPage(
                              sbtAuth: widget.sbtauth,
                            )));
              },
              child: const Text(
                'White list',
                style: TextStyle(color: Colors.black),
              ))
        ],
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
              onPressed: () {
                widget.sbtauth.backupWithOneDrive('123');
              },
              child: const Text('Backup by one drive')),
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth.recoverByOneDrive('123');
              },
              child: const Text('Recover by one drive')),
          const SizedBox(height: 40),
          TextField(
            controller: _emailController,
          ),
          TextButton(
              onPressed: () {
                widget.sbtauth.sendBackupPrivateKey(
                    '123', _emailController.text.trim(), 'code');
              },
              child: const Text('send')),
          const SizedBox(height: 40),
          Text(widget.address),
          const SizedBox(height: 20),
          Text(widget.solanaAddress),
          TextButton(
            onPressed: _sendSol,
            child: const Text('Send sol'),
          ),
          const SizedBox(height: 10),
          Text(hash),
          TextButton(
            onPressed: _signMessage,
            child: const Text('Sign message'),
          ),
          const SizedBox(height: 10),
          Text(_signature),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _sendTransaction,
            child: const Text('Send transaction'),
          ),
          Text(_result),
          const SizedBox(height: 10),
          // TextButton(
          //   onPressed: _getPrivateKey,
          //   child: const Text('Get privateKey'),
          // ),
          // Text(_privateKey),
          TextButton(
            onPressed: () async {
              final data = await Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SimpleBarcodeScannerPage(),
              ));
              await widget.sbtauth.approveLoginWithQrCode(data as String);
            },
            child: const Text('Scan'),
          ),
        ],
      )),
    );
  }

  _signMessage() async {
    final provider = widget.sbtauth.provider;
    if (provider == null) return;
    final signature = await provider
        .request(RequestArgument(method: 'personal_sign', params: ['test']));
    setState(() {
      _signature = signature;
    });
  }

  _sendTransaction() async {
    final provider = widget.sbtauth.provider;
    if (provider == null) return;
    final result = await provider.sendTransaction(
        to: "0x8316e9b2789a7cc3e61c80b6bab9a6e1735701b2",
        value: '0x0',
        data: '0x',
        maxPriorityFeePerGas: bigIntToHex(parseUnit('1', decimals: 9)),
        maxFeePerGas: '0x0737be7600');
    setState(() {
      _result = result;
    });
  }

  _sendSol() async {
    final singer = widget.sbtauth.solanaSinger;
    final fromAddress = Ed25519HDPublicKey.fromBase58(widget.solanaAddress);
    final toAddress = Ed25519HDPublicKey.fromBase58(widget.solanaAddress);
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
