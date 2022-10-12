import 'dart:convert';
import 'dart:developer';

import 'package:hive/hive.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

/// Share hive adapter
class ShareAdapter extends TypeAdapter<Share> {
  @override
  final typeId = 1;

  @override
  Share read(BinaryReader reader) {
    final data = reader.readString();
    if (data != '') return Share(privateKey: '', extraData: '');
    return Share.fromMap(jsonDecode(data) as Map<String, dynamic>);
  }

  @override
  void write(BinaryWriter writer, Share obj) {
    writer.writeMap(obj.toJson());
  }
}
