import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class ConfirmAuthPage extends StatefulWidget {
  final String deviceName;

  ConfirmAuthPage({super.key, required this.deviceName});

  @override
  State<StatefulWidget> createState() => ConfirmAuthPageState();
}

class ConfirmAuthPageState extends State<ConfirmAuthPage> {
  final sbtAuth =
      SbtAuth(developMode: true, clientId: 'Demo', scheme: 'sbtauth');

  String code = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(
            height: 50,
          ),
          Text(widget.deviceName),
          const SizedBox(
            height: 50,
          ),
          Text(code),
          const SizedBox(
            height: 50,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                  onPressed: () async {
                    final authCode =
                        await sbtAuth.approveAuthRequest(widget.deviceName);
                    setState(() {
                      code = authCode;
                    });
                  },
                  child: const Text('confirm')),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('cancel')),
            ],
          ),
        ],
      ),
    );
  }
}
