import 'package:json_annotation/json_annotation.dart';

part 'websocket_message.g.dart';

/// Generic WebSocket message types for real-time communication.
/// 
/// These message types provide a foundation for different types of
/// real-time updates and system communication.
enum WebSocketMessageType {
  // Entity updates - generic CRUD operations
  entityCreated,
  entityUpdated,
  entityDeleted,
  entityStatusUpdate,
  
  // Data synchronization
  dataUpdate,
  dataSync,
  fullSync,
  syncRequest,
  syncResponse,
  
  // System messages
  systemMessage,
  heartbeat,
  clientConnect,
  clientDisconnect,
  
  // Custom application-specific messages
  customMessage,
}

/// Generic WebSocket message for real-time communication.
/// 
/// This model provides a flexible structure for sending various types
/// of messages over WebSocket connections while maintaining type safety
/// and JSON serialization capabilities.
@JsonSerializable()
class WebSocketMessage {
  /// Type of the message indicating its purpose
  final WebSocketMessageType type;
  
  /// Message payload containing the actual data
  final Map<String, dynamic> data;
  
  /// Timestamp when the message was created
  final DateTime timestamp;
  
  /// Optional client identifier for message routing
  final String? clientId;
  
  /// Optional message identifier for tracking
  final String? messageId;

  WebSocketMessage({
    required this.type,
    required this.data,
    required this.timestamp,
    this.clientId,
    this.messageId,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) =>
      _$WebSocketMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WebSocketMessageToJson(this);

  /// Creates a generic entity creation message.
  factory WebSocketMessage.entityCreated({
    required String entityType,
    required Map<String, dynamic> entityData,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.entityCreated,
      data: {
        'entityType': entityType,
        'entity': entityData,
        'action': 'created',
      },
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a generic entity update message.
  factory WebSocketMessage.entityUpdated({
    required String entityType,
    required Map<String, dynamic> entityData,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.entityUpdated,
      data: {
        'entityType': entityType,
        'entity': entityData,
        'action': 'updated',
      },
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a generic entity deletion message.
  factory WebSocketMessage.entityDeleted({
    required String entityType,
    required String entityId,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.entityDeleted,
      data: {
        'entityType': entityType,
        'entityId': entityId,
        'action': 'deleted',
      },
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a generic entity status update message.
  factory WebSocketMessage.entityStatusUpdate({
    required String entityType,
    required String entityId,
    required String status,
    Map<String, dynamic>? additionalData,
    String? clientId,
    String? messageId,
  }) {
    final data = <String, dynamic>{
      'entityType': entityType,
      'entityId': entityId,
      'status': status,
      'action': 'status_updated',
    };
    
    if (additionalData != null) {
      data.addAll(additionalData);
    }

    return WebSocketMessage(
      type: WebSocketMessageType.entityStatusUpdate,
      data: data,
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a generic data update message.
  factory WebSocketMessage.dataUpdate({
    required String dataType,
    required Map<String, dynamic> updateData,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.dataUpdate,
      data: {
        'dataType': dataType,
        'updateData': updateData,
        'action': 'data_updated',
      },
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a system message.
  factory WebSocketMessage.systemMessage({
    required String message,
    String? level,
    Map<String, dynamic>? additionalData,
    String? clientId,
    String? messageId,
  }) {
    final data = <String, dynamic>{
      'message': message,
      'level': level ?? 'info',
    };
    
    if (additionalData != null) {
      data.addAll(additionalData);
    }

    return WebSocketMessage(
      type: WebSocketMessageType.systemMessage,
      data: data,
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a heartbeat message for connection health monitoring.
  factory WebSocketMessage.heartbeat({
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.heartbeat,
      data: {'ping': 'pong'},
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a client connection message.
  factory WebSocketMessage.clientConnect({
    required String clientId,
    required String clientType,
    Map<String, dynamic>? clientMetadata,
    String? messageId,
  }) {
    final data = <String, dynamic>{
      'clientId': clientId,
      'clientType': clientType,
    };
    
    if (clientMetadata != null) {
      data['metadata'] = clientMetadata;
    }

    return WebSocketMessage(
      type: WebSocketMessageType.clientConnect,
      data: data,
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a client disconnection message.
  factory WebSocketMessage.clientDisconnect({
    required String clientId,
    String? reason,
    String? messageId,
  }) {
    final data = <String, dynamic>{'clientId': clientId};
    
    if (reason != null) {
      data['reason'] = reason;
    }

    return WebSocketMessage(
      type: WebSocketMessageType.clientDisconnect,
      data: data,
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a sync request message.
  factory WebSocketMessage.syncRequest({
    required String syncType,
    Map<String, dynamic>? parameters,
    String? clientId,
    String? messageId,
  }) {
    final data = <String, dynamic>{
      'syncType': syncType,
      'requestId': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    if (parameters != null) {
      data['parameters'] = parameters;
    }

    return WebSocketMessage(
      type: WebSocketMessageType.syncRequest,
      data: data,
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a sync response message.
  factory WebSocketMessage.syncResponse({
    required String syncType,
    required Map<String, dynamic> syncData,
    required String requestId,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.syncResponse,
      data: {
        'syncType': syncType,
        'syncData': syncData,
        'requestId': requestId,
      },
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a full data sync message.
  factory WebSocketMessage.fullSync({
    required Map<String, dynamic> allData,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.fullSync,
      data: {
        'allData': allData,
        'syncTimestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a custom message with arbitrary data.
  factory WebSocketMessage.custom({
    required String customType,
    required Map<String, dynamic> customData,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: WebSocketMessageType.customMessage,
      data: {
        'customType': customType,
        'customData': customData,
      },
      timestamp: DateTime.now(),
      clientId: clientId,
      messageId: messageId,
    );
  }

  /// Creates a copy of this message with optionally updated fields.
  WebSocketMessage copyWith({
    WebSocketMessageType? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    String? clientId,
    String? messageId,
  }) {
    return WebSocketMessage(
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      clientId: clientId ?? this.clientId,
      messageId: messageId ?? this.messageId,
    );
  }

  /// Gets a value from the message data.
  T? getValue<T>(String key) {
    return data[key] as T?;
  }

  /// Checks if the message data contains a specific key.
  bool hasKey(String key) {
    return data.containsKey(key);
  }

  /// Gets the entity type for entity-related messages.
  String? get entityType => getValue<String>('entityType');

  /// Gets the action for action-based messages.
  String? get action => getValue<String>('action');

  /// Gets the custom type for custom messages.
  String? get customType => getValue<String>('customType');

  @override
  String toString() {
    return 'WebSocketMessage(type: $type, data: $data, timestamp: $timestamp, '
           'clientId: $clientId, messageId: $messageId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebSocketMessage &&
        other.type == type &&
        other.clientId == clientId &&
        other.messageId == messageId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        clientId.hashCode ^
        messageId.hashCode ^
        timestamp.hashCode;
  }
}