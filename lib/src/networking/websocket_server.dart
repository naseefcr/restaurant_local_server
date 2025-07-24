import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/websocket_message.dart';

/// Configuration options for the WebSocket server.
class WebSocketServerConfig {
  /// Port to bind the server to
  final int port;
  
  /// Heartbeat interval in seconds
  final int heartbeatIntervalSeconds;
  
  /// Default client type for new connections
  final String defaultClientType;
  
  /// Whether to enable verbose logging
  final bool enableLogging;
  
  /// Maximum number of concurrent clients (0 for unlimited)
  final int maxClients;
  
  /// Timeout for client connections in seconds
  final int clientTimeoutSeconds;

  const WebSocketServerConfig({
    this.port = 8081,
    this.heartbeatIntervalSeconds = 30,
    this.defaultClientType = 'client',
    this.enableLogging = true,
    this.maxClients = 0,
    this.clientTimeoutSeconds = 120,
  });
}

/// Client information and statistics.
class ClientInfo {
  /// Unique client identifier
  final String id;
  
  /// Type of client (e.g., 'mobile_app', 'web_client', etc.)
  final String type;
  
  /// When the client connected
  final DateTime connectedAt;
  
  /// Last activity timestamp
  DateTime lastSeen;
  
  /// Client user agent string
  final String? userAgent;
  
  /// Client's remote IP address
  final String? remoteAddress;
  
  /// Custom metadata associated with the client
  final Map<String, dynamic> metadata;

  ClientInfo({
    required this.id,
    required this.type,
    required this.connectedAt,
    required this.lastSeen,
    this.userAgent,
    this.remoteAddress,
    this.metadata = const {},
  });

  /// Get the duration since the client connected
  Duration get connectionDuration => DateTime.now().difference(connectedAt);
  
  /// Get the duration since last activity
  Duration get idleDuration => DateTime.now().difference(lastSeen);
  
  /// Check if the client is considered stale based on timeout
  bool isStale(Duration timeout) => idleDuration > timeout;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'connectedAt': connectedAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'userAgent': userAgent,
      'remoteAddress': remoteAddress,
      'metadata': metadata,
      'connectionDurationMs': connectionDuration.inMilliseconds,
      'idleDurationMs': idleDuration.inMilliseconds,
    };
  }
}

/// Event handler callbacks for WebSocket server events.
class WebSocketServerEventHandlers {
  /// Called when a client connects
  final void Function(String clientId, ClientInfo clientInfo)? onClientConnect;
  
  /// Called when a client disconnects
  final void Function(String clientId, String? reason)? onClientDisconnect;
  
  /// Called when a message is received from a client
  final void Function(String clientId, WebSocketMessage message)? onMessage;
  
  /// Called when a client error occurs
  final void Function(String clientId, dynamic error)? onClientError;
  
  /// Called when the server starts
  final void Function(int port)? onServerStart;
  
  /// Called when the server stops
  final void Function()? onServerStop;

  WebSocketServerEventHandlers({
    this.onClientConnect,
    this.onClientDisconnect,
    this.onMessage,
    this.onClientError,
    this.onServerStart,
    this.onServerStop,
  });
}

/// A generic, reusable WebSocket server for real-time communication.
/// 
/// This server manages multiple WebSocket clients, handles connection/disconnection
/// events, provides heartbeat monitoring, and offers flexible message broadcasting
/// capabilities. It's designed to be domain-agnostic and configurable for various
/// use cases.
/// 
/// Example usage:
/// ```dart
/// final server = WebSocketServer(
///   config: WebSocketServerConfig(
///     port: 8081,
///     enableLogging: true,
///     maxClients: 100,
///   ),
///   eventHandlers: WebSocketServerEventHandlers(
///     onClientConnect: (clientId, clientInfo) {
///       print('Client $clientId connected');
///     },
///   ),
/// );
/// 
/// await server.start();
/// 
/// // Broadcast a message to all clients
/// server.broadcastEntityUpdate(
///   entityType: 'user',
///   entityData: {'id': '123', 'name': 'John'},
/// );
/// ```
class WebSocketServer {
  final WebSocketServerConfig config;
  final WebSocketServerEventHandlers? eventHandlers;

  final Map<String, WebSocketChannel> _clients = {};
  final Map<String, ClientInfo> _clientInfo = {};
  final StreamController<WebSocketMessage> _messageController = 
      StreamController<WebSocketMessage>.broadcast();
  
  HttpServer? _server;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  bool _isRunning = false;

  WebSocketServer({
    required this.config,
    this.eventHandlers,
  });

  /// Stream of all WebSocket messages received from clients
  Stream<WebSocketMessage> get messageStream => _messageController.stream;
  
  /// Number of currently connected clients
  int get clientCount => _clients.length;
  
  /// List of connected client IDs
  List<String> get connectedClients => _clients.keys.toList();
  
  /// Whether the server is currently running
  bool get isRunning => _isRunning;

  /// Starts the WebSocket server.
  /// 
  /// Returns a Future that completes when the server is ready to accept connections.
  /// Throws an exception if the server fails to start.
  Future<void> start() async {
    if (_isRunning) {
      _log('WebSocket server is already running on port ${config.port}');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, config.port);
      _isRunning = true;
      
      _log('WebSocket server started on port ${config.port}');
      eventHandlers?.onServerStart?.call(config.port);

      // Handle incoming requests
      _server!.listen(
        _handleHttpRequest,
        onError: (error) => _log('Server error: $error', isError: true),
      );

      // Start periodic cleanup of stale connections
      _startCleanupTimer();

      // Small delay to ensure server is fully initialized
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      _isRunning = false;
      _log('Error starting WebSocket server: $e', isError: true);
      rethrow;
    }
  }

  /// Stops the WebSocket server and closes all connections.
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _log('Stopping WebSocket server...');
    _isRunning = false;

    // Stop timers
    _stopHeartbeat();
    _stopCleanupTimer();

    // Close all client connections
    final futures = <Future>[];
    for (final entry in _clients.entries) {
      futures.add(_closeClient(entry.key, 'Server shutting down'));
    }
    await Future.wait(futures);

    _clients.clear();
    _clientInfo.clear();

    // Close the server
    await _server?.close(force: true);
    _server = null;

    // Close the message stream
    await _messageController.close();

    eventHandlers?.onServerStop?.call();
    _log('WebSocket server stopped');
  }

  /// Handles incoming HTTP requests and upgrades WebSocket connections.
  void _handleHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      _handleWebSocketConnection(request);
    } else {
      // Reject non-WebSocket requests
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.text
        ..write('WebSocket connections only')
        ..close();
    }
  }

  /// Handles new WebSocket connection requests.
  Future<void> _handleWebSocketConnection(HttpRequest request) async {
    try {
      // Check client limit
      if (config.maxClients > 0 && _clients.length >= config.maxClients) {
        _log('Rejecting connection: Maximum clients (${config.maxClients}) reached');
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..write('Server at capacity')
          ..close();
        return;
      }

      final webSocket = await WebSocketTransformer.upgrade(request);
      final clientId = _generateClientId();
      final channel = IOWebSocketChannel(webSocket);

      // Extract client information
      final clientInfo = ClientInfo(
        id: clientId,
        type: config.defaultClientType,
        connectedAt: DateTime.now(),
        lastSeen: DateTime.now(),
        userAgent: request.headers.value('user-agent'),
        remoteAddress: request.connectionInfo?.remoteAddress.address,
      );

      _clients[clientId] = channel;
      _clientInfo[clientId] = clientInfo;

      _log('Client connected: $clientId (${clientInfo.remoteAddress})');
      eventHandlers?.onClientConnect?.call(clientId, clientInfo);

      // Send connection acknowledgment
      final connectMessage = WebSocketMessage.clientConnect(
        clientId: clientId,
        clientType: clientInfo.type,
        clientMetadata: {
          'serverTime': DateTime.now().toIso8601String(),
          'serverConfig': {
            'heartbeatInterval': config.heartbeatIntervalSeconds,
          },
        },
      );
      
      _sendToClient(clientId, connectMessage);

      // Broadcast connection to other clients
      _broadcastMessage(connectMessage, exclude: clientId);

      // Set up client message handling
      channel.stream.listen(
        (data) => _handleClientMessage(clientId, data),
        onDone: () => _handleClientDisconnect(clientId, 'Connection closed'),
        onError: (error) => _handleClientError(clientId, error),
        cancelOnError: true,
      );

      // Start heartbeat if this is the first client
      if (_clients.length == 1) {
        _startHeartbeat();
      }
    } catch (e) {
      _log('Error handling WebSocket connection: $e', isError: true);
    }
  }

  /// Handles messages received from clients.
  void _handleClientMessage(String clientId, dynamic data) {
    try {
      final Map<String, dynamic> messageData = jsonDecode(data);
      final message = WebSocketMessage.fromJson(messageData);

      // Update client last seen time
      final clientInfo = _clientInfo[clientId];
      if (clientInfo != null) {
        clientInfo.lastSeen = DateTime.now();
      }

      _log('Message from $clientId: ${message.type}');

      // Handle message based on type
      switch (message.type) {
        case WebSocketMessageType.heartbeat:
          // Client heartbeat response - update last seen
          break;

        case WebSocketMessageType.syncRequest:
          // Handle sync requests - could be overridden by subclasses
          eventHandlers?.onMessage?.call(clientId, message);
          break;

        case WebSocketMessageType.entityCreated:
        case WebSocketMessageType.entityUpdated:
        case WebSocketMessageType.entityDeleted:
        case WebSocketMessageType.entityStatusUpdate:
        case WebSocketMessageType.dataUpdate:
        case WebSocketMessageType.customMessage:
          // Broadcast updates to all other clients
          _broadcastMessage(message, exclude: clientId);
          eventHandlers?.onMessage?.call(clientId, message);
          break;

        default:
          eventHandlers?.onMessage?.call(clientId, message);
      }

      // Emit message to stream for external handling
      _messageController.add(message);
    } catch (e) {
      _log('Error handling client message from $clientId: $e', isError: true);
      _handleClientError(clientId, e);
    }
  }

  /// Handles client disconnection.
  void _handleClientDisconnect(String clientId, String? reason) {
    _log('Client disconnected: $clientId${reason != null ? ' ($reason)' : ''}');

    _clients.remove(clientId);
    _clientInfo.remove(clientId);

    eventHandlers?.onClientDisconnect?.call(clientId, reason);

    // Broadcast disconnect message to remaining clients
    final disconnectMessage = WebSocketMessage.clientDisconnect(
      clientId: clientId,
      reason: reason,
    );
    _broadcastMessage(disconnectMessage);

    // Stop heartbeat if no clients remain
    if (_clients.isEmpty) {
      _stopHeartbeat();
    }
  }

  /// Handles client errors.
  void _handleClientError(String clientId, dynamic error) {
    _log('Client error for $clientId: $error', isError: true);
    eventHandlers?.onClientError?.call(clientId, error);
    _handleClientDisconnect(clientId, 'Error: $error');
  }

  /// Closes a specific client connection.
  Future<void> _closeClient(String clientId, [String? reason]) async {
    final client = _clients[clientId];
    if (client != null) {
      try {
        await client.sink.close();
      } catch (e) {
        _log('Error closing client $clientId: $e', isError: true);
      }
    }
    _handleClientDisconnect(clientId, reason);
  }

  /// Broadcasts a message to all or specific clients.
  void _broadcastMessage(WebSocketMessage message, {String? exclude, List<String>? only}) {
    final messageJson = jsonEncode(message.toJson());
    
    Set<String> targetClients;
    if (only != null) {
      targetClients = only.toSet().intersection(_clients.keys.toSet());
    } else {
      targetClients = _clients.keys.toSet();
      if (exclude != null) {
        targetClients.remove(exclude);
      }
    }

    for (final clientId in targetClients) {
      _sendToClientUnsafe(clientId, messageJson);
    }
  }

  /// Sends a message to a specific client.
  void _sendToClient(String clientId, WebSocketMessage message) {
    _sendToClientUnsafe(clientId, jsonEncode(message.toJson()));
  }

  /// Sends raw JSON string to a client (internal use).
  void _sendToClientUnsafe(String clientId, String messageJson) {
    final client = _clients[clientId];
    if (client != null) {
      try {
        client.sink.add(messageJson);
      } catch (e) {
        _log('Error sending message to client $clientId: $e', isError: true);
        _handleClientDisconnect(clientId, 'Send error');
      }
    }
  }

  /// Starts the heartbeat timer.
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: config.heartbeatIntervalSeconds),
      (timer) {
        final heartbeatMessage = WebSocketMessage.heartbeat();
        _broadcastMessage(heartbeatMessage);
        _log('Heartbeat sent to ${_clients.length} clients');
      },
    );
  }

  /// Stops the heartbeat timer.
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Starts the cleanup timer for stale connections.
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) => _cleanupStaleClients(),
    );
  }

  /// Stops the cleanup timer.
  void _stopCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Removes stale clients that haven't been active.
  void _cleanupStaleClients() {
    final timeout = Duration(seconds: config.clientTimeoutSeconds);
    final staleClients = <String>[];

    for (final entry in _clientInfo.entries) {
      if (entry.value.isStale(timeout)) {
        staleClients.add(entry.key);
      }
    }

    for (final clientId in staleClients) {
      _log('Removing stale client: $clientId');
      _closeClient(clientId, 'Connection timeout');
    }
  }

  /// Generates a unique client ID.
  String _generateClientId() {
    return 'client_${DateTime.now().millisecondsSinceEpoch}_${_clients.length}';
  }

  /// Logs messages with optional error level.
  void _log(String message, {bool isError = false}) {
    if (config.enableLogging) {
      final timestamp = DateTime.now().toIso8601String();
      final level = isError ? 'ERROR' : 'INFO';
      print('[$timestamp] [WebSocketServer] [$level] $message');
    }
  }

  // Public API methods for broadcasting different types of updates

  /// Broadcasts a generic message to all clients.
  void broadcastMessage(WebSocketMessage message, {String? exclude, List<String>? only}) {
    _broadcastMessage(message, exclude: exclude, only: only);
  }

  /// Broadcasts an entity creation message.
  void broadcastEntityCreated({
    required String entityType,
    required Map<String, dynamic> entityData,
    String? exclude,
    List<String>? only,
  }) {
    final message = WebSocketMessage.entityCreated(
      entityType: entityType,
      entityData: entityData,
    );
    _broadcastMessage(message, exclude: exclude, only: only);
  }

  /// Broadcasts an entity update message.
  void broadcastEntityUpdated({
    required String entityType,
    required Map<String, dynamic> entityData,
    String? exclude,
    List<String>? only,
  }) {
    final message = WebSocketMessage.entityUpdated(
      entityType: entityType,
      entityData: entityData,
    );
    _broadcastMessage(message, exclude: exclude, only: only);
  }

  /// Broadcasts an entity deletion message.
  void broadcastEntityDeleted({
    required String entityType,
    required String entityId,
    String? exclude,
    List<String>? only,
  }) {
    final message = WebSocketMessage.entityDeleted(
      entityType: entityType,
      entityId: entityId,
    );
    _broadcastMessage(message, exclude: exclude, only: only);
  }

  /// Broadcasts an entity status update message.
  void broadcastEntityStatusUpdate({
    required String entityType,
    required String entityId,
    required String status,
    Map<String, dynamic>? additionalData,
    String? exclude,
    List<String>? only,
  }) {
    final message = WebSocketMessage.entityStatusUpdate(
      entityType: entityType,
      entityId: entityId,
      status: status,
      additionalData: additionalData,
    );
    _broadcastMessage(message, exclude: exclude, only: only);
  }

  /// Broadcasts a generic data update message.
  void broadcastDataUpdate({
    required String dataType,
    required Map<String, dynamic> updateData,
    String? exclude,
    List<String>? only,
  }) {
    final message = WebSocketMessage.dataUpdate(
      dataType: dataType,
      updateData: updateData,
    );
    _broadcastMessage(message, exclude: exclude, only: only);
  }

  /// Broadcasts a system message to all clients.
  void broadcastSystemMessage({
    required String message,
    String? level,
    Map<String, dynamic>? additionalData,
    String? exclude,
    List<String>? only,
  }) {
    final systemMessage = WebSocketMessage.systemMessage(
      message: message,
      level: level,
      additionalData: additionalData,
    );
    _broadcastMessage(systemMessage, exclude: exclude, only: only);
  }

  /// Broadcasts a custom message to all clients.
  void broadcastCustomMessage({
    required String customType,
    required Map<String, dynamic> customData,
    String? exclude,
    List<String>? only,
  }) {
    final message = WebSocketMessage.custom(
      customType: customType,
      customData: customData,
    );
    _broadcastMessage(message, exclude: exclude, only: only);
  }

  /// Sends a message to a specific client.
  void sendToClient(String clientId, WebSocketMessage message) {
    _sendToClient(clientId, message);
  }

  /// Gets information about a specific client.
  ClientInfo? getClientInfo(String clientId) {
    return _clientInfo[clientId];
  }

  /// Gets information about all connected clients.
  Map<String, ClientInfo> getAllClientsInfo() {
    return Map.from(_clientInfo);
  }

  /// Gets server statistics.
  Map<String, dynamic> getServerStats() {
    final now = DateTime.now();
    
    return {
      'isRunning': _isRunning,
      'port': config.port,
      'clientCount': clientCount,
      'maxClients': config.maxClients,
      'uptime': _server != null ? now.difference(DateTime.now()).inSeconds : 0,
      'clientTypes': _getClientTypeStats(),
      'averageConnectionDuration': _getAverageConnectionDuration(),
      'config': {
        'heartbeatIntervalSeconds': config.heartbeatIntervalSeconds,
        'clientTimeoutSeconds': config.clientTimeoutSeconds,
        'enableLogging': config.enableLogging,
      },
    };
  }

  /// Gets statistics about client types.
  Map<String, int> _getClientTypeStats() {
    final stats = <String, int>{};
    for (final client in _clientInfo.values) {
      stats[client.type] = (stats[client.type] ?? 0) + 1;
    }
    return stats;
  }

  /// Calculates average connection duration in seconds.
  double _getAverageConnectionDuration() {
    if (_clientInfo.isEmpty) return 0.0;
    
    final total = _clientInfo.values
        .map((client) => client.connectionDuration.inSeconds)
        .reduce((a, b) => a + b);
    
    return total / _clientInfo.length;
  }

  /// Disconnects a specific client.
  Future<void> disconnectClient(String clientId, [String? reason]) async {
    await _closeClient(clientId, reason ?? 'Disconnected by server');
  }

  /// Disconnects all clients.
  Future<void> disconnectAllClients([String? reason]) async {
    final clientIds = _clients.keys.toList();
    for (final clientId in clientIds) {
      await _closeClient(clientId, reason ?? 'Server disconnecting all clients');
    }
  }
}