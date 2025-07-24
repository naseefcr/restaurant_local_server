// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocket_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebSocketMessage _$WebSocketMessageFromJson(Map<String, dynamic> json) =>
    WebSocketMessage(
      type: $enumDecode(_$WebSocketMessageTypeEnumMap, json['type']),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      clientId: json['clientId'] as String?,
      messageId: json['messageId'] as String?,
    );

Map<String, dynamic> _$WebSocketMessageToJson(WebSocketMessage instance) =>
    <String, dynamic>{
      'type': _$WebSocketMessageTypeEnumMap[instance.type]!,
      'data': instance.data,
      'timestamp': instance.timestamp.toIso8601String(),
      'clientId': instance.clientId,
      'messageId': instance.messageId,
    };

const _$WebSocketMessageTypeEnumMap = {
  WebSocketMessageType.entityCreated: 'entityCreated',
  WebSocketMessageType.entityUpdated: 'entityUpdated',
  WebSocketMessageType.entityDeleted: 'entityDeleted',
  WebSocketMessageType.entityStatusUpdate: 'entityStatusUpdate',
  WebSocketMessageType.dataUpdate: 'dataUpdate',
  WebSocketMessageType.dataSync: 'dataSync',
  WebSocketMessageType.fullSync: 'fullSync',
  WebSocketMessageType.syncRequest: 'syncRequest',
  WebSocketMessageType.syncResponse: 'syncResponse',
  WebSocketMessageType.systemMessage: 'systemMessage',
  WebSocketMessageType.heartbeat: 'heartbeat',
  WebSocketMessageType.clientConnect: 'clientConnect',
  WebSocketMessageType.clientDisconnect: 'clientDisconnect',
  WebSocketMessageType.customMessage: 'customMessage',
};
