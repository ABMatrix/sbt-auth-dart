import 'package:flutter/material.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

class EditWhiteListPage extends StatefulWidget {
  final String? id;
  final SbtAuth sbtAuth;

  const EditWhiteListPage({super.key, this.id, required this.sbtAuth});

  @override
  State<StatefulWidget> createState() => EditWhiteListPageState();
}

class EditWhiteListPageState extends State<EditWhiteListPage> {
  TextEditingController addressController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController networkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      getInfo();
    }
  }

  Future<void> getInfo() async {
    final res = await widget.sbtAuth.api.getUserWhiteListItem(widget.id!);
    setState(() {
      addressController.text = res.userWhitelistAddress;
      nameController.text = res.userWhitelistName;
      networkController.text = res.userWhitelistNetwork;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Add white list' : 'Edit white list'),
        actions: [
          widget.id != null
              ? TextButton(
                  onPressed: () {
                    widget.sbtAuth.api.deleteUserWhiteList(widget.id!);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.black),
                  ))
              : Container()
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Address'),
          TextField(
            controller: addressController,
          ),
          const SizedBox(height: 20),
          const Text('Name'),
          TextField(
            controller: nameController,
          ),
          const SizedBox(height: 20),
          const Text('Network'),
          TextField(
            controller: networkController,
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: ElevatedButton(
        onPressed: () {
          widget.id == null
              ? widget.sbtAuth.api.createUserWhiteList(
                  addressController.text.trim(),
                  nameController.text.trim(),
                  networkController.text.trim())
              : widget.sbtAuth.api.editUserWhiteList(
                  addressController.text.trim(),
                  nameController.text.trim(),
                  widget.id!,
                  widget.sbtAuth.user!.userID,
                  networkController.text.trim());
          Navigator.pop(context);
        },
        child: const Text('Confirm'),
      ),
    );
  }
}
