import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:sbt_auth_dart/sbt_auth_dart.dart';

/// Share hive adapter
class ShareAdapter extends TypeAdapter<Share> {
  @override
  final typeId = 16;

  @override
  Share read(BinaryReader reader) {
    final data = reader.readString();
    return Share.fromMap(jsonDecode(data) as Map<String, dynamic>);
  }

  @override
  void write(BinaryWriter writer, Share obj) {
    writer.writeMap(obj.toJson());
  }
}
