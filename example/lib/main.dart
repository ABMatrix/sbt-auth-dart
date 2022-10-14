import 'package:example/sign.dart';
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
    _controller.text = '30min18@gmail.com';
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
                    _loginWithSocial(LoginType.email);
                  },
                  child: const Text('Login with email')),
              ElevatedButton(
                  onPressed: () {
                    _loginWithSocial(LoginType.google);
                  },
                  child: const Text('Login with Google')),
              ElevatedButton(
                  onPressed: () {
                    _loginWithSocial(LoginType.facebook);
                  },
                  child: const Text('Login With Facebook')),
              ElevatedButton(
                  onPressed: () {
                    _loginWithSocial(LoginType.twitter);
                  },
                  child: const Text('Login With Twitter')),
            ],
          ),
        ),
      ),
    );
  }

  _loginWithSocial(LoginType loginType) async {
    final sbtAuth = SbtAuth(developMode: true, clientId: 'Demo');
    AuthCore core;
    if (loginType == LoginType.email) {
      final email = _controller.text;
      const code = '121212';
      core = await sbtAuth.login(loginType, email: email, code: code);
    } else {
      core = await sbtAuth.login(loginType);
    }
    if (mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  SignPage(username: core.getAddress(), core: core)));
    }
  }
}
