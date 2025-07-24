import 'dart:async';
import 'package:restaurant_local_server/restaurant_local_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Example demonstrating comprehensive usage of LocalServerManager
void main() async {
  print('=== LocalServerManager Example ===\n');
  
  // Create configuration with custom settings
  final config = LocalServerConfig(
    serverName: 'Example Local Server',
    serverVersion: '1.2.0',
    httpConfig: const HttpServerConfig(
      httpPort: 8080,
      webSocketPort: 8081,
      discoveryPort: 8082,
      enableCors: true,
      enableLogging: true,
    ),
    webSocketConfig: const WebSocketServerConfig(
      port: 8081,
      heartbeatIntervalSeconds: 30,
      maxClients: 100,
      enableLogging: true,
    ),
    discoveryConfig: const DiscoveryConfig(
      discoveryPort: 8082,
      broadcastInterval: Duration(seconds: 10),
      enableLogging: true,
    ),
    enableAutoRecovery: true,
    healthCheckIntervalSeconds: 30,
    enableLogging: true,
    capabilities: {
      'api_version': '1.0',
      'supports_realtime': true,
      'supports_discovery': true,
      'custom_feature': true,
    },
  );
  
  // Create event handlers for monitoring server events
  final eventHandlers = LocalServerEventHandlers(
    onStatusChange: (oldStatus, newStatus) {
      print('📊 Server Status: ${oldStatus.name} → ${newStatus.name}');
    },
    onHealthChange: (oldHealth, newHealth) {
      print('🏥 Server Health: ${oldHealth.name} → ${newHealth.name}');
    },
    onError: (service, error) {
      print('❌ Error in $service: $error');
    },
    onServerStarted: (serverInfo) {
      print('🚀 Server started successfully!');
      print('   HTTP URL: ${serverInfo.httpUrl}');
      print('   WebSocket URL: ${serverInfo.webSocketUrl}');
      print('   Discovery Port: ${serverInfo.capabilities}');
    },
    onServerStopped: () {
      print('🛑 Server stopped');
    },
    onClientConnect: (clientId, clientInfo) {
      print('🔗 Client connected: $clientId (${clientInfo.type})');
    },
    onClientDisconnect: (clientId, reason) {
      print('🔌 Client disconnected: $clientId${reason != null ? ' ($reason)' : ''}');
    },
    onWebSocketMessage: (clientId, message) {
      print('💬 Message from $clientId: ${message.type.name}');
    },
    onRecoveryAttempt: (service, attemptNumber) {
      print('🔄 Recovery attempt $attemptNumber for $service service');
    },
  );
  
  // Create the server manager
  final serverManager = LocalServerManager(
    config: config,
    eventHandlers: eventHandlers,
  );
  
  // Add custom route handlers
  serverManager.addRouteHandler(ExampleCrudHandler());
  serverManager.addRouteHandler(CustomApiHandler());
  
  try {
    // Start the server
    print('Starting server...\n');
    await serverManager.start();
    
    // Set some custom metrics
    serverManager.setMetric('example_metric', 42);
    serverManager.setMetric('start_time_custom', DateTime.now().toIso8601String());
    
    // Demonstrate server operations
    await _demonstrateServerOperations(serverManager);
    
    // Keep server running and demonstrate monitoring
    await _demonstrateMonitoring(serverManager);
    
  } catch (e) {
    print('Failed to start server: $e');
  } finally {
    print('\nShutting down server...');
    await serverManager.dispose();
    print('Example completed.');
  }
}

/// Demonstrates various server operations
Future<void> _demonstrateServerOperations(LocalServerManager serverManager) async {
  print('\n=== Demonstrating Server Operations ===');
  
  // Wait a moment for everything to stabilize
  await Future.delayed(const Duration(seconds: 2));
  
  // Broadcast some WebSocket messages
  print('Broadcasting WebSocket messages...');
  
  serverManager.broadcastSystemMessage(
    message: 'Welcome to the example server!',
    level: 'info',
  );
  
  serverManager.broadcastEntityUpdate(
    entityType: 'user',
    entityData: {
      'id': 'user123',
      'name': 'John Doe',
      'status': 'online',
    },
  );
  
  // Send custom WebSocket message
  final customMessage = WebSocketMessage.custom(
    customType: 'example_event',
    customData: {
      'event': 'demonstration',
      'timestamp': DateTime.now().toIso8601String(),
      'data': 'This is a custom event from the server manager example',
    },
  );
  
  serverManager.broadcastMessage(customMessage);
  
  print('WebSocket messages broadcasted.');
}

/// Demonstrates server monitoring capabilities
Future<void> _demonstrateMonitoring(LocalServerManager serverManager) async {
  print('\n=== Demonstrating Server Monitoring ===');
  
  // Display server statistics every 5 seconds
  for (int i = 0; i < 3; i++) {
    await Future.delayed(const Duration(seconds: 5));
    
    final stats = serverManager.getStatistics();
    print('\n--- Server Statistics (${i + 1}/3) ---');
    print('Status: ${stats.status.name}');
    print('Health: ${stats.healthStatus.name}');
    print('Uptime: ${stats.uptime.inSeconds} seconds');
    print('Connected Clients: ${stats.connectedClients}');
    print('Custom Metrics: ${stats.metrics}');
    
    final serviceHealth = serverManager.getServiceHealth();
    print('Service Health:');
    for (final entry in serviceHealth.entries) {
      final health = entry.value;
      print('  ${health.serviceName}: ${health.status.name} (${health.isRunning ? 'running' : 'stopped'})');
      if (health.responseTime != null) {
        print('    Response Time: ${health.responseTime!.inMilliseconds}ms');
      }
      if (health.metrics.isNotEmpty) {
        print('    Metrics: ${health.metrics}');
      }
    }
    
    // Update a custom metric
    serverManager.setMetric('demo_counter', i + 1);
  }
  
  print('\nMonitoring demonstration completed.');
}

/// Example CRUD route handler
class ExampleCrudHandler extends CrudRouteHandler {
  // In-memory storage for demonstration
  final Map<String, Map<String, dynamic>> _storage = {};
  int _nextId = 1;
  
  ExampleCrudHandler() : super(resourceName: 'examples');
  
  @override
  Future<List<Map<String, dynamic>>> getAll(Request request) async {
    return _storage.values.toList();
  }
  
  @override
  Future<Map<String, dynamic>?> getById(String id, Request request) async {
    return _storage[id];
  }
  
  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data, Request request) async {
    final id = '${_nextId++}';
    final item = {
      'id': id,
      ...data,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _storage[id] = item;
    return item;
  }
  
  @override
  Future<Map<String, dynamic>?> update(String id, Map<String, dynamic> data, Request request) async {
    final existing = _storage[id];
    if (existing == null) return null;
    
    final updated = {
      ...existing,
      ...data,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _storage[id] = updated;
    return updated;
  }
  
  @override
  Future<bool> delete(String id, Request request) async {
    return _storage.remove(id) != null;
  }
}

/// Example custom API handler
class CustomApiHandler implements RouteHandler {
  @override
  void registerRoutes(Router router) {
    // Custom status endpoint
    router.get('/api/example/status', (Request request) async {
      return HttpUtils.successResponse({
        'server': 'LocalServerManager Example',
        'timestamp': DateTime.now().toIso8601String(),
        'uptime': '${DateTime.now().difference(DateTime.now()).inSeconds}s',
        'message': 'Server is running smoothly!',
      });
    });
    
    // Custom echo endpoint
    router.post('/api/example/echo', (Request request) async {
      final body = await HttpUtils.parseJsonBody(request);
      if (body == null) {
        return HttpUtils.errorResponse('Invalid JSON body');
      }
      
      return HttpUtils.successResponse({
        'echo': body,
        'receivedAt': DateTime.now().toIso8601String(),
      });
    });
    
    // Query parameters demonstration
    router.get('/api/example/query', (Request request) async {
      final params = HttpUtils.getQueryParams(request);
      return HttpUtils.successResponse({
        'queryParameters': params,
        'parameterCount': params.length,
      });
    });
  }
}