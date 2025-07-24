# Restaurant Local Server

A comprehensive Flutter package for building local server applications with UDP discovery, HTTP REST APIs, WebSocket support, and real-time synchronization capabilities. Originally designed for restaurant POS systems but completely generic and reusable for any local networking needs.

## Features

- 🌐 **UDP Network Discovery**: Automatic server discovery across local networks
- 🔗 **WebSocket Server**: Multi-client real-time communication with heartbeat monitoring
- 📡 **HTTP REST API**: Shelf-based HTTP server with CRUD operation support
- 🎯 **Service Orchestration**: Unified management of all networking services
- 📊 **Health Monitoring**: Automatic health checks with failure recovery
- 🔧 **Highly Configurable**: Extensive configuration options for all services
- 🛡️ **Production Ready**: Comprehensive error handling and resource management

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  restaurant_local_server: ^1.0.0
```

Then run:
```bash
flutter pub get
```

## Quick Start

### Simple Server Setup

```dart
import 'package:restaurant_local_server/restaurant_local_server.dart';

void main() async {
  // Create server configuration
  final config = LocalServerConfig(
    serverName: 'My Application Server',
    version: '1.0.0',
    httpPort: 8080,
    webSocketPort: 8081,
    discoveryPort: 8082,
  );

  // Create and start server
  final serverManager = LocalServerManager(config: config);
  await serverManager.start();

  print('Server running on ${await serverManager.getServerInfo()}');
}
```

### Advanced Server with Custom Routes

```dart
import 'package:restaurant_local_server/restaurant_local_server.dart';

// Custom route handler
class UserRouteHandler extends CrudRouteHandler {
  @override
  String get basePath => '/users';

  @override
  Future<Response> handleGet(String id, Request request) async {
    final user = await getUserById(id);
    return Response.ok(jsonEncode(user));
  }

  @override
  Future<Response> handlePost(Request request) async {
    final userData = await request.readAsString();
    final newUser = await createUser(userData);
    
    // Notify WebSocket clients
    notifier?.broadcastEntityCreated(
      entityType: 'user',
      entityData: newUser,
    );
    
    return Response.ok(jsonEncode(newUser));
  }
}

void main() async {
  final config = LocalServerConfig(
    serverName: 'User Management Server',
    version: '1.0.0',
    capabilities: ['user_management', 'real_time_sync'],
  );

  final eventHandlers = LocalServerEventHandlers(
    onStatusChange: (status) => print('Server status: $status'),
    onClientConnect: (clientId, info) => print('Client connected: $clientId'),
    onError: (error) => print('Server error: $error'),
  );

  final serverManager = LocalServerManager(
    config: config,
    eventHandlers: eventHandlers,
  );

  // Add custom route handler
  await serverManager.addRouteHandler(UserRouteHandler());

  // Start server
  await serverManager.start();
}
```

## Core Components

### 1. LocalServerManager

The main orchestrator that manages all services:

```dart
final serverManager = LocalServerManager(
  config: LocalServerConfig(
    serverName: 'My Server',
    httpPort: 8080,
    webSocketPort: 8081,
    discoveryPort: 8082,
    enableHealthMonitoring: true,
    autoRecovery: true,
  ),
);

await serverManager.start();
final stats = serverManager.getServerStats();
await serverManager.stop();
```

### 2. Network Discovery Service

UDP-based server discovery for automatic connection:

```dart
// Server mode - broadcast availability
final discoveryService = NetworkDiscoveryService();
final serverInfo = ServerInfo.create(
  name: 'My Server',
  version: '1.0.0',
  httpPort: 8080,
);
await discoveryService.startServer(serverInfo);

// Client mode - discover available servers
final servers = await NetworkDiscoveryService.discoverServers();
for (final server in servers) {
  print('Found server: ${server.name} at ${server.address}');
}
```

### 3. WebSocket Server

Multi-client real-time communication:

```dart
final config = WebSocketServerConfig(
  port: 8081,
  heartbeatIntervalSeconds: 30,
  maxClients: 100,
);

final server = WebSocketServer(config: config);
await server.start();

// Broadcast messages
server.broadcastEntityUpdated(
  entityType: 'product',
  entityData: {'id': '123', 'name': 'Updated Product'},
);

server.broadcastSystemMessage('Server maintenance in 5 minutes');
```

### 4. HTTP Server

REST API server with CRUD support:

```dart
final httpServer = LocalHttpServer();
await httpServer.start(port: 8080);

// Add custom middleware
httpServer.addMiddleware(myCustomMiddleware);

// Add custom routes
httpServer.addRouteHandler(MyCustomRouteHandler());
```

## Configuration Options

### LocalServerConfig

```dart
final config = LocalServerConfig(
  // Server identification
  serverName: 'My Application Server',
  version: '1.0.0',
  description: 'Local server for my app',
  capabilities: ['feature1', 'feature2'],

  // Network ports
  httpPort: 8080,
  webSocketPort: 8081,
  discoveryPort: 8082,

  // Service control
  enableHttpServer: true,
  enableWebSocketServer: true,
  enableDiscoveryService: true,

  // Health monitoring
  enableHealthMonitoring: true,
  healthCheckIntervalSeconds: 30,
  serviceTimeoutSeconds: 10,

  // Auto recovery
  autoRecovery: true,
  maxRecoveryAttempts: 3,
  recoveryDelaySeconds: 5,

  // Custom metadata
  customMetadata: {'department': 'IT', 'environment': 'production'},
);
```

## Client Discovery

Discover and connect to local servers from client applications:

```dart
import 'package:restaurant_local_server/restaurant_local_server.dart';

class ClientApp {
  Future<void> discoverAndConnect() async {
    // Discover available servers
    final servers = await NetworkDiscoveryService.discoverServers(
      timeout: Duration(seconds: 5),
    );

    if (servers.isNotEmpty) {
      final server = servers.first;
      print('Connecting to ${server.name} at ${server.address}');
      
      // Connect to HTTP API
      final httpUrl = server.httpUrl;
      final response = await http.get(Uri.parse('$httpUrl/health'));
      
      // Connect to WebSocket
      final wsUrl = server.webSocketUrl;
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen for updates
      channel.stream.listen((message) {
        final wsMessage = WebSocketMessage.fromJson(jsonDecode(message));
        handleServerMessage(wsMessage);
      });
    }
  }
}
```

## Examples

The package includes comprehensive examples in the `example/` directory:

- **Simple Server**: Basic server setup with minimal configuration
- **Advanced Server**: Custom routes, middleware, and event handling  
- **Client Discovery**: How to discover and connect to servers
- **Real-time Sync**: WebSocket communication patterns
- **CRUD Operations**: REST API implementation examples

## API Reference

### Classes

- **LocalServerManager**: Main server orchestrator
- **NetworkDiscoveryService**: UDP discovery service
- **WebSocketServer**: Multi-client WebSocket server
- **LocalHttpServer**: HTTP REST API server
- **ServerInfo**: Server metadata and connection information
- **WebSocketMessage**: Standardized WebSocket message format

### Interfaces

- **RouteHandler**: Base interface for HTTP route handlers
- **CrudRouteHandler**: CRUD operations route handler
- **WebSocketNotifier**: Interface for WebSocket notifications

## Best Practices

1. **Server Lifecycle**: Always properly start and stop services
2. **Error Handling**: Implement event handlers for robust error management
3. **Health Monitoring**: Enable health checks for production deployments
4. **Resource Cleanup**: Use try-finally blocks or proper disposal
5. **Security**: Validate all incoming requests and data
6. **Testing**: Use the provided examples as testing templates

## Troubleshooting

### Common Issues

**Server won't start:**
- Check if ports are already in use
- Verify network permissions
- Check firewall settings

**Discovery not working:**
- Ensure devices are on same network
- Check UDP port (8082) is not blocked
- Verify multicast is supported

**WebSocket connections dropping:**
- Adjust heartbeat interval
- Check client timeout settings
- Monitor network stability

### Debug Mode

Enable verbose logging for troubleshooting:

```dart
final config = LocalServerConfig(
  // ... other config
  enableLogging: true,
  verboseLogging: true,
);
```

## Requirements

- Flutter SDK: >=3.10.0
- Dart SDK: >=3.7.2

## Dependencies

This package uses the following dependencies:
- `shelf`: HTTP server framework
- `shelf_router`: HTTP routing
- `shelf_web_socket`: WebSocket integration
- `web_socket_channel`: WebSocket communication
- `http`: HTTP client
- `json_annotation`: JSON serialization

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For issues, questions, or contributions, please visit our GitHub repository or contact the maintainers.