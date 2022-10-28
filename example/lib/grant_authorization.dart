import 'dart:async';

import 'package:example/sign.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class GrantAuthorizationPage extends StatefulWidget {
  const GrantAuthorizationPage({super.key});

  @override
  State<StatefulWidget> createState() => GrantAuthorizationPageState();
}

class GrantAuthorizationPageState extends State<GrantAuthorizationPage> {
  SbtAuth auth = SbtAuth(developMode: true, clientId: 'SBT', scheme: 'sbtauth');

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
                    future: auth.api.getUserDeviceList(),
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
                                      await auth.api.sendAuthRequest(
                                          snapshot.data[i].deviceName!);
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
                    print("Completed");
                    print(currentText);
                  },
                  onChanged: (value) {
                    print(value);
                    setState(() {
                      currentText = value;
                    });
                  },
                  beforeTextPaste: (text) {
                    print("Allowing to paste $text");
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
          await auth.recoverWithDevice(currentText);
          if (mounted) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SignPage(
                          username: auth.user!.username,
                          sbtauth: auth,
                        )));
          }
        },
        child: const Text('finish'),
      ),
    );
  }
}
