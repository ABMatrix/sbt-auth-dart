import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:sbt_auth_dart/utils.dart';

class SignPage extends StatefulWidget {
  final String username;
  final SbtAuth sbtauth;

  const SignPage({required this.username, required this.sbtauth, super.key});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  String _signature = '';
  String _result = '';
  String _privateKey = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign'),
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.username),
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
          TextButton(
            onPressed: _getPrivateKey,
            child: const Text('Get privateKey'),
          ),
          Text(_privateKey),
          TextButton(
            onPressed: () async {
              final data = await Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SimpleBarcodeScannerPage(),
              ));
              final map = await widget.sbtauth.getLoginMessage(data as String);
              widget.sbtauth.approveLoginWithQrCode(map);
            },
            child: const Text('Scan'),
          ),
        ],
      )),
    );
  }

  _signMessage() async {
    final provider =
        SbtAuthProvider(signer: widget.sbtauth.core.signer, clientId: 'Test');
    final signature = await provider
        .request(RequestArgument(method: 'personal_sign', params: ['test']));
    setState(() {
      _signature = signature;
    });
  }

  _sendTransaction() async {
    final provider =
        SbtAuthProvider(signer: widget.sbtauth.core.signer, clientId: 'Test');
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

  _getPrivateKey() {
    setState(() {
      _privateKey = widget.sbtauth.core.getPrivateKey();
    });
  }
}
