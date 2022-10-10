import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class SignPage extends StatefulWidget {
  final String username;
  final AuthCore core;
  const SignPage({required this.username, required this.core, super.key});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign')),
      body: Center(
          child: Column(
        children: [Text(widget.username)],
      )),
    );
  }
}
