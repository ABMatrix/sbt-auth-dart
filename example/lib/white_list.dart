import 'package:example/edit_white_list.dart';
import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class WhiteListPage extends StatefulWidget {
  final SbtAuth sbtAuth;

  const WhiteListPage({super.key, required this.sbtAuth});

  @override
  State<StatefulWidget> createState() => WhiteListPageState();
}

class WhiteListPageState extends State<WhiteListPage> {
  List whiteList = [];

  bool open = false;

  @override
  void initState() {
    super.initState();
    getList();
  }

  Future<void> getList() async {
    final res = await widget.sbtAuth.api.getUserWhiteList(1, 999);
    final result = await widget.sbtAuth.api.getUserInfo();
    setState(() {
      whiteList = res;
      open = result.userWhitelist;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('white list'),
        actions: [
          Switch(
              value: widget.sbtAuth.user!.userWhitelist,
              onChanged: (v) async {
                await widget.sbtAuth
                    .switchWhiteList('code', whitelistSwitch: v);
                final res = await widget.sbtAuth.api.getUserInfo();
                setState(() {
                  open = res.userWhitelist;
                });
              })
        ],
      ),
      body: !open
          ? const Text('data')
          : Column(
              children: [
                IconButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => EditWhiteListPage(
                                    sbtAuth: widget.sbtAuth,
                                  )));
                    },
                    icon: const Icon(Icons.add)),
                Expanded(
                  child: ListView.builder(
                      // shrinkWrap: true,
                      itemCount: whiteList.length,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 30),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return EditWhiteListPage(
                                  id: whiteList[i].userWhitelistID,
                                  sbtAuth: widget.sbtAuth,
                                );
                              }));
                            },
                            child: Column(
                              children: [
                                Text(whiteList[i].userWhitelistName),
                                Text(whiteList[i].userWhitelistAddress),
                                Text(whiteList[i].userWhitelistNetwork),
                              ],
                            ),
                          ),
                        );
                      }),
                )
              ],
            ),
    );
  }
}
