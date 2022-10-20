import 'dart:convert';
import 'dart:developer';

import 'package:example/confirm_auth.dart';
import 'package:example/grant_authorization.dart';
import 'package:example/sign.dart';
import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

void main() async {
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
      SbtAuth(developMode: true, clientId: 'SBT', scheme: 'sbtauth');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.text = '30min18@gmail.com';
    sbtAuth.init();
    sbtAuth.streamController.stream.listen((event) {
      if (event.contains('deviceName')) {
        final deviceName = jsonDecode(event)['deviceName'];
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ConfirmAuthPage(deviceName: deviceName)));
      }
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
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

  _login(LoginType loginType, {String? email}) async {
    late bool loginSuccess;
    try {
      loginSuccess = await sbtAuth.loginWithSocial(loginType,
          email: email, verityCode: 'verityCode');
    } catch (e) {
      if (e is SbtAuthException) {
        log(e.toString());
        if (e.toString() == 'New device detected') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const GrantAuthorizationPage()));
        }
      }
    }
    if (mounted && loginSuccess) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SignPage(
                  username: sbtAuth.core.getAddress(), core: sbtAuth.core)));
    }
  }
}
