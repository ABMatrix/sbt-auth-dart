import 'dart:convert';

import 'package:example/sign.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.text = '30min12@gmail.com';
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
              ElevatedButton(onPressed: login, child: const Text('Login'))
            ],
          ),
        ),
      ),
    );
  }

  login() async {
    final email = _controller.text;
    final data = {
      'emailAddress': email,
      'authCode': '121212',
      'deviceName': 'Device',
      'clientID': 'Safematrix'
    };
    const baseUrl = 'https://test-api.sbtauth.io/sbt-auth';
    final result = await http.post(Uri.parse('$baseUrl/user:login'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(data));
    final token = jsonDecode(result.body)['data'];

    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'authorization': 'Bearer $token'
    };
    final userRes =
        await http.get(Uri.parse('$baseUrl/user/user'), headers: headers);
    final user = jsonDecode(userRes.body);
    final core = AuthCore();
    if (user['publicKeyAddress'] == null) {
      final account = await core.generatePubKey();

      /// Go to backup page
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  SignPage(username: account.address, core: core)));
    } else {
      final remoteRes = await http.get(
          Uri.parse('$baseUrl/user/private-key-fragment-info'),
          headers: headers);
      final address =
          jsonDecode(remoteRes.body)['privateKeyFragmentInfoPublicKeyAddress'];
      final remote =
          jsonDecode(remoteRes.body)['privateKeyFragmentInfoPublicKeyAddress'];
      core.init(remote: Share.fromMap(remote), address: address);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => SignPage(username: address, core: core)));
    }
  }
}
