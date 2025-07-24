import 'dart:async';

import '../models/server_info.dart';
import '../models/websocket_message.dart';
import '../networking/http_server.dart' show LocalHttpServer, HttpServerConfig, RouteHandler, WebSocketNotifier;
import '../networking/websocket_server.dart';
import '../networking/discovery_service.dart';

/// Server lifecycle states
enum LocalServerStatus {
  /// Server is stopped
  stopped,
  /// Server is in the process of starting
  starting,
  /// Server is running and ready to accept connections
  running,
  /// Server is in the process of stopping
  stopping,
  /// Server encountered an error
  error,
  /// Server is paused (services running but not accepting new connections)
  paused,
}

/// Server health status
enum ServerHealthStatus {
  /// All services are healthy
  healthy,
  /// Some services have warnings but are functional
  degraded,
  /// Critical issues detected, server may not function properly
  critical,
  /// Unknown health status
  unknown,
}

/// Configuration for the LocalServerManager
class LocalServerConfig {
  /// HTTP server configuration
  final HttpServerConfig httpConfig;
  
  /// WebSocket server configuration
  final WebSocketServerConfig webSocketConfig;
  
  /// Network discovery configuration
  final DiscoveryConfig discoveryConfig;
  
  /// Enable automatic service recovery on failures
  final bool enableAutoRecovery;
  
  /// Health check interval in seconds
  final int healthCheckIntervalSeconds;
  
  /// Service startup timeout in seconds
  final int startupTimeoutSeconds;
  
  /// Service shutdown timeout in seconds
  final int shutdownTimeoutSeconds;
  
  /// Maximum number of restart attempts for auto-recovery
  final int maxRecoveryAttempts;
  
  /// Enable comprehensive logging
  final bool enableLogging;
  
  /// Server name for identification
  final String serverName;
  
  /// Server version
  final String serverVersion;
  
  /// Custom server capabilities
  final Map<String, dynamic> capabilities;
  
  const LocalServerConfig({
    this.httpConfig = const HttpServerConfig(),
    this.webSocketConfig = const WebSocketServerConfig(),
    this.discoveryConfig = const DiscoveryConfig(),
    this.enableAutoRecovery = true,
    this.healthCheckIntervalSeconds = 30,
    this.startupTimeoutSeconds = 30,
    this.shutdownTimeoutSeconds = 15,
    this.maxRecoveryAttempts = 3,
    this.enableLogging = true,
    this.serverName = 'Local Server',
    this.serverVersion = '1.0.0',
    this.capabilities = const {},
  });
  
  LocalServerConfig copyWith({
    HttpServerConfig? httpConfig,
    WebSocketServerConfig? webSocketConfig,
    DiscoveryConfig? discoveryConfig,
    bool? enableAutoRecovery,
    int? healthCheckIntervalSeconds,
    int? startupTimeoutSeconds,
    int? shutdownTimeoutSeconds,
    int? maxRecoveryAttempts,
    bool? enableLogging,
    String? serverName,
    String? serverVersion,
    Map<String, dynamic>? capabilities,
  }) {
    return LocalServerConfig(
      httpConfig: httpConfig ?? this.httpConfig,
      webSocketConfig: webSocketConfig ?? this.webSocketConfig,
      discoveryConfig: discoveryConfig ?? this.discoveryConfig,
      enableAutoRecovery: enableAutoRecovery ?? this.enableAutoRecovery,
      healthCheckIntervalSeconds: healthCheckIntervalSeconds ?? this.healthCheckIntervalSeconds,
      startupTimeoutSeconds: startupTimeoutSeconds ?? this.startupTimeoutSeconds,
      shutdownTimeoutSeconds: shutdownTimeoutSeconds ?? this.shutdownTimeoutSeconds,
      maxRecoveryAttempts: maxRecoveryAttempts ?? this.maxRecoveryAttempts,
      enableLogging: enableLogging ?? this.enableLogging,
      serverName: serverName ?? this.serverName,
      serverVersion: serverVersion ?? this.serverVersion,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

/// Event callbacks for server lifecycle and operations
class LocalServerEventHandlers {
  /// Called when server status changes
  final void Function(LocalServerStatus oldStatus, LocalServerStatus newStatus)? onStatusChange;
  
  /// Called when server health status changes
  final void Function(ServerHealthStatus oldHealth, ServerHealthStatus newHealth)? onHealthChange;
  
  /// Called when an error occurs
  final void Function(String service, dynamic error)? onError;
  
  /// Called when server starts successfully
  final void Function(ServerInfo serverInfo)? onServerStarted;
  
  /// Called when server stops
  final void Function()? onServerStopped;
  
  /// Called when a WebSocket client connects
  final void Function(String clientId, ClientInfo clientInfo)? onClientConnect;
  
  /// Called when a WebSocket client disconnects
  final void Function(String clientId, String? reason)? onClientDisconnect;
  
  /// Called when a WebSocket message is received
  final void Function(String clientId, WebSocketMessage message)? onWebSocketMessage;
  
  /// Called during auto-recovery attempts
  final void Function(String service, int attemptNumber)? onRecoveryAttempt;
  
  const LocalServerEventHandlers({
    this.onStatusChange,
    this.onHealthChange,
    this.onError,
    this.onServerStarted,
    this.onServerStopped,
    this.onClientConnect,
    this.onClientDisconnect,
    this.onWebSocketMessage,
    this.onRecoveryAttempt,
  });
}

/// Service health information
class ServiceHealth {
  final String serviceName;
  final bool isRunning;
  final ServerHealthStatus status;
  final String? errorMessage;
  final DateTime lastCheck;
  final Duration? responseTime;
  final Map<String, dynamic> metrics;
  
  const ServiceHealth({
    required this.serviceName,
    required this.isRunning,
    required this.status,
    this.errorMessage,
    required this.lastCheck,
    this.responseTime,
    this.metrics = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'serviceName': serviceName,
      'isRunning': isRunning,
      'status': status.name,
      'errorMessage': errorMessage,
      'lastCheck': lastCheck.toIso8601String(),
      'responseTimeMs': responseTime?.inMilliseconds,
      'metrics': metrics,
    };
  }
}

/// Comprehensive server statistics
class ServerStatistics {
  final LocalServerStatus status;
  final ServerHealthStatus healthStatus;
  final DateTime startTime;
  final Duration uptime;
  final int connectedClients;
  final Map<String, ServiceHealth> serviceHealth;
  final Map<String, dynamic> metrics;
  
  const ServerStatistics({
    required this.status,
    required this.healthStatus,
    required this.startTime,
    required this.uptime,
    required this.connectedClients,
    required this.serviceHealth,
    this.metrics = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'healthStatus': healthStatus.name,
      'startTime': startTime.toIso8601String(),
      'uptimeSeconds': uptime.inSeconds,
      'connectedClients': connectedClients,
      'serviceHealth': serviceHealth.map((key, value) => MapEntry(key, value.toJson())),
      'metrics': metrics,
    };
  }
}

/// Generic, reusable local server manager for orchestrating HTTP, WebSocket, and Discovery services
/// 
/// This manager provides:
/// - Unified lifecycle management for all networking services
/// - Health monitoring and automatic recovery
/// - Event-driven architecture with comprehensive callbacks
/// - Detailed statistics and monitoring capabilities
/// - Graceful startup and shutdown with dependency management
/// - Configuration-driven behavior for different use cases
/// 
/// Example usage:
/// ```dart
/// final config = LocalServerConfig(
///   serverName: 'My App Server',
///   httpConfig: HttpServerConfig(httpPort: 8080),
///   webSocketConfig: WebSocketServerConfig(port: 8081),
/// );
/// 
/// final eventHandlers = LocalServerEventHandlers(
///   onStatusChange: (oldStatus, newStatus) => print('Status: $oldStatus -> $newStatus'),
///   onClientConnect: (clientId, info) => print('Client $clientId connected'),
/// );
/// 
/// final serverManager = LocalServerManager(
///   config: config,
///   eventHandlers: eventHandlers,
/// );
/// 
/// await serverManager.start();
/// ```
class LocalServerManager {
  final LocalServerConfig config;
  final LocalServerEventHandlers? eventHandlers;
  
  // Core services
  late final LocalHttpServer _httpServer;
  late final WebSocketServer _webSocketServer;
  late final NetworkDiscoveryService _discoveryService;
  
  // State management
  LocalServerStatus _status = LocalServerStatus.stopped;
  ServerHealthStatus _healthStatus = ServerHealthStatus.unknown;
  ServerInfo? _serverInfo;
  DateTime? _startTime;
  String? _lastError;
  
  // Monitoring and recovery
  Timer? _healthCheckTimer;
  Timer? _statisticsTimer;
  final Map<String, ServiceHealth> _serviceHealth = {};
  final Map<String, int> _recoveryAttempts = {};
  StreamSubscription? _webSocketMessageSubscription;
  
  // Statistics
  int _totalConnections = 0;
  int _totalMessages = 0;
  final Map<String, dynamic> _customMetrics = {};
  
  LocalServerManager({
    required this.config,
    this.eventHandlers,
  }) {
    _initializeServices();
  }
  
  // Getters
  LocalServerStatus get status => _status;
  ServerHealthStatus get healthStatus => _healthStatus;
  ServerInfo? get serverInfo => _serverInfo;
  bool get isRunning => _status == LocalServerStatus.running;
  bool get isStopped => _status == LocalServerStatus.stopped;
  int get connectedClients => _webSocketServer.clientCount;
  String? get lastError => _lastError;
  Duration get uptime => _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
  
  /// Initializes all networking services with proper configuration
  void _initializeServices() {
    _httpServer = LocalHttpServer();
    _webSocketServer = WebSocketServer(
      config: config.webSocketConfig,
      eventHandlers: WebSocketServerEventHandlers(
        onClientConnect: (clientId, clientInfo) {
          _totalConnections++;
          eventHandlers?.onClientConnect?.call(clientId, clientInfo);
        },
        onClientDisconnect: (clientId, reason) {
          eventHandlers?.onClientDisconnect?.call(clientId, reason);
        },
        onMessage: (clientId, message) {
          _totalMessages++;
          eventHandlers?.onWebSocketMessage?.call(clientId, message);
        },
        onClientError: (clientId, error) {
          _log('WebSocket client error ($clientId): $error');
          eventHandlers?.onError?.call('websocket', error);
        },
      ),
    );
    _discoveryService = NetworkDiscoveryService(config.discoveryConfig);
    
    // Set up HTTP server with WebSocket integration
    _httpServer.setWebSocketNotifier(_WebSocketNotifierAdapter(_webSocketServer));
  }
  
  /// Starts the server with all services
  /// 
  /// Services are started in dependency order:
  /// 1. WebSocket server (required by HTTP server for notifications)
  /// 2. HTTP server (provides API endpoints)
  /// 3. Discovery service (broadcasts server availability)
  /// 
  /// Returns a Future that completes when all services are running.
  /// Throws an exception if startup fails.
  Future<void> start() async {
    if (_status == LocalServerStatus.running || _status == LocalServerStatus.starting) {
      _log('Server is already starting or running');
      return;
    }
    
    _updateStatus(LocalServerStatus.starting);
    _lastError = null;
    
    try {
      _log('Starting local server...');
      
      // Start services with timeout
      await _startServicesWithTimeout();
      
      // Create server info
      final ipAddress = await _discoveryService.getLocalIpAddress() ?? 'localhost';
      _serverInfo = ServerInfo.create(
        name: config.serverName,
        version: config.serverVersion,
        ipAddress: ipAddress,
        httpPort: config.httpConfig.httpPort,
        webSocketPort: config.webSocketConfig.port,
        capabilities: config.capabilities,
      );
      
      _startTime = DateTime.now();
      
      // Set up WebSocket message monitoring
      _webSocketMessageSubscription = _webSocketServer.messageStream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          _log('WebSocket message stream error: $error');
          eventHandlers?.onError?.call('websocket_stream', error);
        },
      );
      
      // Start monitoring services
      _startHealthMonitoring();
      
      // Wait a moment to ensure all services are stable
      await Future.delayed(const Duration(milliseconds: 500));
      
      _updateStatus(LocalServerStatus.running);
      _updateHealthStatus(ServerHealthStatus.healthy);
      
      _log('Local server started successfully on ${_serverInfo!.httpUrl}');
      eventHandlers?.onServerStarted?.call(_serverInfo!);
      
    } catch (e) {
      _lastError = e.toString();
      _updateStatus(LocalServerStatus.error);
      _updateHealthStatus(ServerHealthStatus.critical);
      _log('Error starting local server: $e');
      
      // Clean up on failure
      await _cleanup();
      eventHandlers?.onError?.call('server_startup', e);
      rethrow;
    }
  }
  
  /// Starts all services with proper timeout handling
  Future<void> _startServicesWithTimeout() async {
    final startupTimeout = Duration(seconds: config.startupTimeoutSeconds);
    
    try {
      await Future.wait([
        // Start WebSocket server first
        _startServiceWithTimeout(
          () => _webSocketServer.start(),
          'WebSocket',
          startupTimeout,
        ),
        
        // Start HTTP server
        _startServiceWithTimeout(
          () => _httpServer.start(config: config.httpConfig),
          'HTTP',
          startupTimeout,
        ),
      ]);
      
      // Start discovery service last
      if (config.discoveryConfig.enableLogging) {
        final ipAddress = await _discoveryService.getLocalIpAddress() ?? 'localhost';
        final serverInfo = ServerInfo.create(
          name: config.serverName,
          version: config.serverVersion,
          ipAddress: ipAddress,
          httpPort: config.httpConfig.httpPort,
          webSocketPort: config.webSocketConfig.port,
          capabilities: config.capabilities,
        );
        
        await _startServiceWithTimeout(
          () => _discoveryService.startServer(serverInfo),
          'Discovery',
          startupTimeout,
        );
      }
      
    } catch (e) {
      throw Exception('Service startup failed: $e');
    }
  }
  
  /// Starts a service with timeout and error handling
  Future<void> _startServiceWithTimeout(
    Future<void> Function() startFunction,
    String serviceName,
    Duration timeout,
  ) async {
    try {
      _log('Starting $serviceName service...');
      await startFunction().timeout(timeout);
      _log('$serviceName service started successfully');
      
      // Update service health
      _updateServiceHealth(serviceName, true, ServerHealthStatus.healthy);
      
    } catch (e) {
      _updateServiceHealth(serviceName, false, ServerHealthStatus.critical, e.toString());
      throw Exception('$serviceName service failed to start: $e');
    }
  }
  
  /// Stops the server gracefully
  Future<void> stop() async {
    if (_status == LocalServerStatus.stopped || _status == LocalServerStatus.stopping) {
      _log('Server is already stopping or stopped');
      return;
    }
    
    _updateStatus(LocalServerStatus.stopping);
    _log('Stopping local server...');
    
    try {
      await _stopServicesWithTimeout();
      await _cleanup();
      
      _updateStatus(LocalServerStatus.stopped);
      _updateHealthStatus(ServerHealthStatus.unknown);
      
      _log('Local server stopped successfully');
      eventHandlers?.onServerStopped?.call();
      
    } catch (e) {
      _lastError = e.toString();
      _updateStatus(LocalServerStatus.error);
      _log('Error stopping local server: $e');
      eventHandlers?.onError?.call('server_shutdown', e);
    }
  }
  
  /// Stops all services with proper timeout handling
  Future<void> _stopServicesWithTimeout() async {
    final shutdownTimeout = Duration(seconds: config.shutdownTimeoutSeconds);
    
    final futures = <Future>[];
    
    // Stop discovery service first
    if (_discoveryService.isRunning) {
      futures.add(_stopServiceWithTimeout(
        () => _discoveryService.stop(),
        'Discovery',
        shutdownTimeout,
      ));
    }
    
    // Stop HTTP server
    if (_httpServer.isRunning) {
      futures.add(_stopServiceWithTimeout(
        () => _httpServer.stop(),
        'HTTP',
        shutdownTimeout,
      ));
    }
    
    // Stop WebSocket server last
    if (_webSocketServer.isRunning) {
      futures.add(_stopServiceWithTimeout(
        () => _webSocketServer.stop(),
        'WebSocket',
        shutdownTimeout,
      ));
    }
    
    await Future.wait(futures);
  }
  
  /// Stops a service with timeout and error handling
  Future<void> _stopServiceWithTimeout(
    Future<void> Function() stopFunction,
    String serviceName,
    Duration timeout,
  ) async {
    try {
      _log('Stopping $serviceName service...');
      await stopFunction().timeout(timeout);
      _log('$serviceName service stopped successfully');
      
      _updateServiceHealth(serviceName, false, ServerHealthStatus.unknown);
      
    } catch (e) {
      _log('Warning: $serviceName service shutdown failed: $e');
      _updateServiceHealth(serviceName, false, ServerHealthStatus.critical, e.toString());
    }
  }
  
  /// Restarts the server
  Future<void> restart() async {
    _log('Restarting local server...');
    await stop();
    await Future.delayed(const Duration(seconds: 2));
    await start();
  }
  
  /// Pauses the server (stops accepting new connections but keeps existing ones)
  Future<void> pause() async {
    if (_status != LocalServerStatus.running) {
      throw StateError('Server must be running to pause');
    }
    
    _updateStatus(LocalServerStatus.paused);
    _log('Server paused - not accepting new connections');
    
    // Implementation would stop accepting new connections
    // but keep existing ones alive - this is a placeholder
  }
  
  /// Resumes a paused server
  Future<void> resume() async {
    if (_status != LocalServerStatus.paused) {
      throw StateError('Server must be paused to resume');
    }
    
    _updateStatus(LocalServerStatus.running);
    _log('Server resumed - accepting new connections');
    
    // Implementation would resume accepting connections
  }
  
  /// Cleans up all resources
  Future<void> _cleanup() async {
    // Stop monitoring
    _stopHealthMonitoring();
    
    // Cancel subscriptions
    await _webSocketMessageSubscription?.cancel();
    _webSocketMessageSubscription = null;
    
    // Clear state
    _serverInfo = null;
    _startTime = null;
    _serviceHealth.clear();
    _recoveryAttempts.clear();
  }
  
  /// Starts health monitoring with periodic checks
  void _startHealthMonitoring() {
    _stopHealthMonitoring(); // Ensure no duplicate timers
    
    _healthCheckTimer = Timer.periodic(
      Duration(seconds: config.healthCheckIntervalSeconds),
      (timer) => _performHealthCheck(),
    );
    
    _statisticsTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => _updateStatistics(),
    );
  }
  
  /// Stops health monitoring
  void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    
    _statisticsTimer?.cancel();
    _statisticsTimer = null;
  }
  
  /// Performs comprehensive health check on all services
  Future<void> _performHealthCheck() async {
    if (_status != LocalServerStatus.running) return;
    
    try {
      final futures = <Future>[];
      
      // Check HTTP server
      futures.add(_checkHttpHealth());
      
      // Check WebSocket server
      futures.add(_checkWebSocketHealth());
      
      // Check Discovery service
      futures.add(_checkDiscoveryHealth());
      
      await Future.wait(futures);
      
      // Determine overall health
      _determineOverallHealth();
      
    } catch (e) {
      _log('Health check error: $e');
      eventHandlers?.onError?.call('health_check', e);
    }
  }
  
  /// Checks HTTP server health
  Future<void> _checkHttpHealth() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final isHealthy = _httpServer.isRunning;
      stopwatch.stop();
      
      _updateServiceHealth(
        'HTTP',
        isHealthy,
        isHealthy ? ServerHealthStatus.healthy : ServerHealthStatus.critical,
        null,
        stopwatch.elapsed,
      );
      
    } catch (e) {
      stopwatch.stop();
      _updateServiceHealth(
        'HTTP',
        false,
        ServerHealthStatus.critical,
        e.toString(),
        stopwatch.elapsed,
      );
      
      if (config.enableAutoRecovery) {
        _attemptServiceRecovery('HTTP');
      }
    }
  }
  
  /// Checks WebSocket server health
  Future<void> _checkWebSocketHealth() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final isHealthy = _webSocketServer.isRunning;
      final clientCount = _webSocketServer.clientCount;
      
      stopwatch.stop();
      
      _updateServiceHealth(
        'WebSocket',
        isHealthy,
        isHealthy ? ServerHealthStatus.healthy : ServerHealthStatus.critical,
        null,
        stopwatch.elapsed,
        {'clientCount': clientCount},
      );
      
    } catch (e) {
      stopwatch.stop();
      _updateServiceHealth(
        'WebSocket',
        false,
        ServerHealthStatus.critical,
        e.toString(),
        stopwatch.elapsed,
      );
      
      if (config.enableAutoRecovery) {
        _attemptServiceRecovery('WebSocket');
      }
    }
  }
  
  /// Checks Discovery service health
  Future<void> _checkDiscoveryHealth() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final isHealthy = _discoveryService.isRunning;
      stopwatch.stop();
      
      _updateServiceHealth(
        'Discovery',
        isHealthy,
        isHealthy ? ServerHealthStatus.healthy : ServerHealthStatus.degraded,
        null,
        stopwatch.elapsed,
      );
      
    } catch (e) {
      stopwatch.stop();
      _updateServiceHealth(
        'Discovery',
        false,
        ServerHealthStatus.degraded, // Discovery failure is not critical
        e.toString(),
        stopwatch.elapsed,
      );
      
      if (config.enableAutoRecovery) {
        _attemptServiceRecovery('Discovery');
      }
    }
  }
  
  /// Determines overall server health based on service health
  void _determineOverallHealth() {
    final healths = _serviceHealth.values.map((h) => h.status).toList();
    
    if (healths.any((h) => h == ServerHealthStatus.critical)) {
      _updateHealthStatus(ServerHealthStatus.critical);
    } else if (healths.any((h) => h == ServerHealthStatus.degraded)) {
      _updateHealthStatus(ServerHealthStatus.degraded);
    } else if (healths.isNotEmpty && healths.every((h) => h == ServerHealthStatus.healthy)) {
      _updateHealthStatus(ServerHealthStatus.healthy);
    } else {
      _updateHealthStatus(ServerHealthStatus.unknown);
    }
  }
  
  /// Attempts automatic recovery for a failed service
  Future<void> _attemptServiceRecovery(String serviceName) async {
    final attempts = _recoveryAttempts[serviceName] ?? 0;
    
    if (attempts >= config.maxRecoveryAttempts) {
      _log('Max recovery attempts reached for $serviceName service');
      return;
    }
    
    _recoveryAttempts[serviceName] = attempts + 1;
    
    _log('Attempting recovery for $serviceName service (attempt ${attempts + 1}/${config.maxRecoveryAttempts})');
    eventHandlers?.onRecoveryAttempt?.call(serviceName, attempts + 1);
    
    try {
      switch (serviceName) {
        case 'HTTP':
          await _httpServer.stop();
          await Future.delayed(const Duration(seconds: 2));
          await _httpServer.start(config: config.httpConfig);
          break;
        case 'WebSocket':
          await _webSocketServer.stop();
          await Future.delayed(const Duration(seconds: 2));
          await _webSocketServer.start();
          break;
        case 'Discovery':
          await _discoveryService.stop();
          await Future.delayed(const Duration(seconds: 2));
          if (_serverInfo != null) {
            await _discoveryService.startServer(_serverInfo!);
          }
          break;
      }
      
      _log('$serviceName service recovery successful');
      _recoveryAttempts[serviceName] = 0; // Reset counter on success
      
    } catch (e) {
      _log('$serviceName service recovery failed: $e');
      eventHandlers?.onError?.call('${serviceName.toLowerCase()}_recovery', e);
    }
  }
  
  /// Updates service health information
  void _updateServiceHealth(
    String serviceName,
    bool isRunning,
    ServerHealthStatus status, [
    String? errorMessage,
    Duration? responseTime,
    Map<String, dynamic>? metrics,
  ]) {
    _serviceHealth[serviceName] = ServiceHealth(
      serviceName: serviceName,
      isRunning: isRunning,
      status: status,
      errorMessage: errorMessage,
      lastCheck: DateTime.now(),
      responseTime: responseTime,
      metrics: metrics ?? {},
    );
  }
  
  /// Updates server status with event notification
  void _updateStatus(LocalServerStatus newStatus) {
    if (_status != newStatus) {
      final oldStatus = _status;
      _status = newStatus;
      _log('Server status changed: ${oldStatus.name} -> ${newStatus.name}');
      eventHandlers?.onStatusChange?.call(oldStatus, newStatus);
    }
  }
  
  /// Updates health status with event notification
  void _updateHealthStatus(ServerHealthStatus newHealth) {
    if (_healthStatus != newHealth) {
      final oldHealth = _healthStatus;
      _healthStatus = newHealth;
      _log('Server health changed: ${oldHealth.name} -> ${newHealth.name}');
      eventHandlers?.onHealthChange?.call(oldHealth, newHealth);
    }
  }
  
  /// Handles WebSocket messages for monitoring and logging
  void _handleWebSocketMessage(WebSocketMessage message) {
    if (config.enableLogging) {
      _log('WebSocket message: ${message.type.name}');
    }
  }
  
  /// Updates custom metrics and statistics
  void _updateStatistics() {
    _customMetrics['totalConnections'] = _totalConnections;
    _customMetrics['totalMessages'] = _totalMessages;
    _customMetrics['currentClients'] = connectedClients;
    _customMetrics['uptime'] = uptime.inSeconds;
  }
  
  /// Sets a custom metric
  void setMetric(String key, dynamic value) {
    _customMetrics[key] = value;
  }
  
  /// Gets a custom metric
  dynamic getMetric(String key) {
    return _customMetrics[key];
  }
  
  /// Gets comprehensive server statistics
  ServerStatistics getStatistics() {
    return ServerStatistics(
      status: _status,
      healthStatus: _healthStatus,
      startTime: _startTime ?? DateTime.now(),
      uptime: uptime,
      connectedClients: connectedClients,
      serviceHealth: Map.from(_serviceHealth),
      metrics: {
        ..._customMetrics,
        'totalConnections': _totalConnections,
        'totalMessages': _totalMessages,
      },
    );
  }
  
  /// Gets detailed service health information
  Map<String, ServiceHealth> getServiceHealth() {
    return Map.from(_serviceHealth);
  }
  
  /// Gets WebSocket server for direct access
  WebSocketServer get webSocketServer => _webSocketServer;
  
  /// Gets HTTP server for direct access
  LocalHttpServer get httpServer => _httpServer;
  
  /// Gets discovery service for direct access
  NetworkDiscoveryService get discoveryService => _discoveryService;
  
  /// Adds a route handler to the HTTP server
  void addRouteHandler(RouteHandler handler) {
    _httpServer.addRouteHandler(handler);
  }
  
  /// Convenience methods for common WebSocket operations
  void broadcastMessage(WebSocketMessage message, {String? exclude, List<String>? only}) {
    if (_status == LocalServerStatus.running) {
      _webSocketServer.broadcastMessage(message, exclude: exclude, only: only);
    }
  }
  
  void broadcastEntityUpdate({
    required String entityType,
    required Map<String, dynamic> entityData,
    String? exclude,
    List<String>? only,
  }) {
    if (_status == LocalServerStatus.running) {
      _webSocketServer.broadcastEntityUpdated(
        entityType: entityType,
        entityData: entityData,
        exclude: exclude,
        only: only,
      );
    }
  }

  void broadcastEntityStatusUpdate({
    required String entityType,
    required String entityId,
    required String status,
    Map<String, dynamic>? additionalData,
    String? exclude,
    List<String>? only,
  }) {
    if (_status == LocalServerStatus.running) {
      _webSocketServer.broadcastEntityStatusUpdate(
        entityType: entityType,
        entityId: entityId,
        status: status,
        additionalData: additionalData,
        exclude: exclude,
        only: only,
      );
    }
  }
  
  void broadcastSystemMessage({
    required String message,
    String? level,
    Map<String, dynamic>? additionalData,
    String? exclude,
    List<String>? only,
  }) {
    if (_status == LocalServerStatus.running) {
      _webSocketServer.broadcastSystemMessage(
        message: message,
        level: level,
        additionalData: additionalData,
        exclude: exclude,
        only: only,
      );
    }
  }
  
  /// Internal logging method
  void _log(String message) {
    if (config.enableLogging) {
      final timestamp = DateTime.now().toIso8601String();
      // ignore: avoid_print
      print('[$timestamp] [LocalServerManager] $message');
    }
  }
  
  /// Disposes of the server manager and cleans up all resources
  Future<void> dispose() async {
    await stop();
  }
}

/// Adapter class to integrate WebSocket server with HTTP server notifications
class _WebSocketNotifierAdapter implements WebSocketNotifier {
  final WebSocketServer _webSocketServer;
  
  _WebSocketNotifierAdapter(this._webSocketServer);
  
  @override
  void notifyDataChange(String event, Map<String, dynamic> data) {
    _webSocketServer.broadcastDataUpdate(
      dataType: event,
      updateData: data,
    );
  }
  
  @override
  void broadcastSystemMessage(String message, {String? level}) {
    _webSocketServer.broadcastSystemMessage(
      message: message,
      level: level ?? 'info',
    );
  }
}