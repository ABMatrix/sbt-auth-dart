import 'package:example/bitcoin_sign.dart';
import 'package:example/dogecoin_sign.dart';
import 'package:example/solana_sign.dart';
import 'package:example/white_list.dart';
import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';

import 'main.dart';

class SignPage extends StatefulWidget {
  final String address;
  final SbtAuth sbtauth;

  const SignPage({required this.address, required this.sbtauth, super.key});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  String _signature = '';
  String _result = '';
  String hash = '';
  String _privateKey = '';

  @override
  void initState() {
    print(widget.address);
    super.initState();
    print(widget.sbtauth.toWif(
        '1e99423a4ed27608a15a2616a2b0e9e52ced330ac530edcc32c8ffc6a526aedd'));
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
      body: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth.recoverByOneDrive('123');
              },
              child: const Text('Recover by one drive')),
          const SizedBox(height: 40),
          Text(widget.address),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _initSolana,
            child: const Text('Init solana'),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _initBitcoin,
            child: const Text('Init bitcoin'),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _initDogecoin,
            child: const Text('Init dogecoin'),
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
              await widget.sbtauth.approveLoginWithQrCode(data as String);
            },
            child: const Text('Scan'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _logout,
            child: const Text('Logout'),
          ),
        ],
      )),
    );
  }

  _getPrivateKey() async {
    final res = await widget.sbtauth.getPrivateKey(
        '0xb89bc496038d1713cf8cbac60224189886d56971',
        'LHnkfr9HyQdShMPu8mpqa3yfZmJLBnWMRsy7DBSjhTSTXVUV6uesonsUK4eGRezIAPMiUwXe1SnAycAy/EgqJrlnpMDHv4MNm85eTN4a',
        '123');
    setState(() {
      _privateKey = res;
    });
    print(_privateKey);
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

  _initSolana() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SolanaSignPage(
          sbtauth: widget.sbtauth,
        ),
      ),
    );
  }

  _initBitcoin() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BitcoinSignPage(
          sbtauth: widget.sbtauth,
        ),
      ),
    );
  }

  _initDogecoin() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DogecoinSignPage(
          sbtauth: widget.sbtauth,
        ),
      ),
    );
  }

  _logout() {
    widget.sbtauth.logout();
    Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const MyApp(),
        ));
  }
}
