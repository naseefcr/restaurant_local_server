// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => ServerInfo(
  name: json['name'] as String,
  version: json['version'] as String,
  ipAddress: json['ipAddress'] as String,
  httpPort: (json['httpPort'] as num).toInt(),
  webSocketPort: (json['webSocketPort'] as num).toInt(),
  startTime: DateTime.parse(json['startTime'] as String),
  capabilities: json['capabilities'] as Map<String, dynamic>,
);

Map<String, dynamic> _$ServerInfoToJson(ServerInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'ipAddress': instance.ipAddress,
      'httpPort': instance.httpPort,
      'webSocketPort': instance.webSocketPort,
      'startTime': instance.startTime.toIso8601String(),
      'capabilities': instance.capabilities,
    };
