import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class ConfirmAuthPage extends StatefulWidget {
  final SbtAuth auth;
  final String deviceName;
  final String keyType;

  const ConfirmAuthPage({
    super.key,
    required this.deviceName,
    required this.auth,
    required this.keyType,
  });

  @override
  State<StatefulWidget> createState() => ConfirmAuthPageState();
}

class ConfirmAuthPageState extends State<ConfirmAuthPage> {
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
                    final authCode = await widget.auth.approveAuthRequest(
                        widget.deviceName,
                        chain: SbtChain.values.byName(widget.keyType));
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
