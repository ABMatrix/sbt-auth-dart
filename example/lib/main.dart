import 'dart:convert';
import 'dart:developer';

import 'package:example/confirm_auth.dart';
import 'package:example/grant_authorization.dart';
import 'package:example/sign.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SbtAuth.initHive();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController _controller;
  final sbtAuth =
      SbtAuth(developMode: true, clientId: 'Demo', scheme: 'sbtauth');
  String code = '';

  @override
  void initState() {
    super.initState();
    getCode();
    _controller = TextEditingController();
    _controller.text = '30min18@gmail.com';
    sbtAuth.authRequestStreamController.stream.listen((event) {
      if (event.contains('deviceName')) {
        final deviceName = jsonDecode(event)['deviceName'];
        final keyType = jsonDecode(event)['keyType'];
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ConfirmAuthPage(
                      deviceName: deviceName,
                      auth: sbtAuth,
                      keyType: keyType,
                    )));
      }
    });
    sbtAuth.loginStreamController.stream.listen((event) {
      if (event) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignPage(
              address: sbtAuth.user!.publicKeyAddress['EVM']['address'] ??
                  sbtAuth.core!.getAddress(isTestnet: sbtAuth.developMode),
              sbtauth: sbtAuth,
            ),
          ),
        );
      }
    });
  }

  getCode() async {
    final res = await sbtAuth.getLoginQrCode();
    setState(() {
      code = res;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              GestureDetector(
                onTap: () async {
                  final res = await sbtAuth.getLoginQrCode();
                  setState(() {
                    code = res;
                  });
                },
                child: QrImageView(data: code),
              ),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Email',
                ),
              ),
              ElevatedButton(
                  onPressed: () {
                    _login(LoginType.email, email: _controller.text.trim());
                  },
                  child: const Text('Login with email')),
              ElevatedButton(
                  onPressed: () {
                    _login(LoginType.google);
                  },
                  child: const Text('Login with Google')),
              ElevatedButton(
                  onPressed: () {
                    _login(LoginType.facebook);
                  },
                  child: const Text('Login With Facebook')),
              ElevatedButton(
                  onPressed: () {
                    _login(LoginType.twitter);
                  },
                  child: const Text('Login With Twitter')),
            ],
          ),
        ),
      ),
    );
  }

  _login(LoginType loginType, {String? email, String? password}) async {
    try {
      await sbtAuth.login(
        loginType,
        email: email,
        code: '203687',
        password: password,
        create: false,
      );
      if (mounted) {
        if (sbtAuth.provider == null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => GrantAuthorizationPage(
                        auth: sbtAuth,
                      )));
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignPage(
                address: sbtAuth.user!.publicKeyAddress['EVM'] == null
                    ? sbtAuth.core!.getAddress(isTestnet: sbtAuth.developMode)
                    : sbtAuth.user!.publicKeyAddress['EVM']['address'],
                sbtauth: sbtAuth,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (e is SbtAuthException) {
        log(e.toString());
        if (e.toString() == 'New device detected') {}
      }
    }
  }
}
