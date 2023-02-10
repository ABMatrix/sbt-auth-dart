import 'dart:async';

import 'package:example/sign.dart';
import 'package:example/solana_sign.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class GrantAuthorizationPage extends StatefulWidget {
  final SbtAuth auth;
  final SbtChain chain;

  const GrantAuthorizationPage(
      {super.key, required this.auth, this.chain = SbtChain.EVM});

  @override
  State<StatefulWidget> createState() => GrantAuthorizationPageState();
}

class GrantAuthorizationPageState extends State<GrantAuthorizationPage> {
  String currentText = '';
  StreamController<ErrorAnimationType> errorController = StreamController();
  TextEditingController textEditingController = TextEditingController();

  bool emailConfirm = true;

  TextEditingController privateKeyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('choose Device'),
      ),
      body: emailConfirm
          ? Column(
              children: [
                FutureBuilder(
                    future: widget.auth.getDeviceList(),
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      // finish
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasError) {
                          // error
                          return Text("Error: ${snapshot.error}");
                        } else {
                          // success
                          return SizedBox(
                            height: 300,
                            child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data.length,
                                itemBuilder: (context, i) {
                                  return GestureDetector(
                                    onTap: () async {
                                      await widget.auth.api.sendAuthRequest(
                                        snapshot.data[i].deviceName!,
                                        keyType: widget.chain.name,
                                      );
                                    },
                                    child: Container(
                                      width: 800,
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 20),
                                      child: Text(
                                        snapshot.data[i].deviceName!,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }),
                          );
                        }
                      } else {
                        // loading
                        return const CircularProgressIndicator();
                      }
                    }),
                PinCodeTextField(
                  length: 6,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(5),
                    fieldHeight: 50,
                    fieldWidth: 40,
                    activeFillColor: Colors.white,
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  // backgroundColor: Colors.blue.shade50,
                  enableActiveFill: true,
                  errorAnimationController: errorController,
                  controller: textEditingController,
                  onCompleted: (v) {
                    debugPrint("Completed");
                    debugPrint(currentText);
                  },
                  onChanged: (value) {
                    debugPrint(value);
                    setState(() {
                      currentText = value;
                    });
                  },
                  beforeTextPaste: (text) {
                    debugPrint("Allowing to paste $text");
                    return true;
                  },
                  appContext: context,
                ),
                const SizedBox(
                  height: 30,
                ),
                TextButton(
                    onPressed: () {
                      setState(() {
                        emailConfirm = !emailConfirm;
                      });
                    },
                    child: const Text('Other way'))
              ],
            )
          : Column(
              children: [
                const SizedBox(
                  height: 80,
                ),
                TextField(
                  controller: privateKeyController,
                ),
                const SizedBox(
                  height: 30,
                ),
                TextButton(
                    onPressed: () {
                      setState(() {
                        emailConfirm = !emailConfirm;
                      });
                    },
                    child: const Text('Other way'))
              ],
            ),
      bottomNavigationBar: TextButton(
        onPressed: () async {
          if (emailConfirm) {
            await widget.auth.recoverWithDevice(
              currentText,
              chain: widget.chain,
            );
          } else {
            await widget.auth.recoverWidthBackup(
              privateKeyController.text.trim(),
              '123',
              chain: widget.chain,
            );
          }

          if (mounted) {
            if (widget.chain == SbtChain.EVM) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SignPage(
                            address: widget.auth.user!.publicKeyAddress['EVM']
                                    ['address'] ??
                                '',
                            sbtauth: widget.auth,
                          )));
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SolanaSignPage(
                    sbtauth: widget.auth,
                  ),
                ),
              );
            }
          }
        },
        child: const Text('finish'),
      ),
    );
  }
}
