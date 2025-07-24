# Restaurant Local Server Examples

This directory contains examples showing how to use the `restaurant_local_server` package, including the comprehensive `LocalServerManager` for unified server management.

## LocalServerManager (Recommended)

The `LocalServerManager` provides unified orchestration of HTTP, WebSocket, and Discovery services with advanced features like health monitoring, automatic recovery, and comprehensive event handling.

### Quick Start with LocalServerManager

```dart
import 'package:restaurant_local_server/restaurant_local_server.dart';

void main() async {
  // Create server manager with default configuration
  final serverManager = LocalServerManager(
    config: const LocalServerConfig(
      serverName: 'My App Server',
      enableLogging: true,
    ),
    eventHandlers: LocalServerEventHandlers(
      onServerStarted: (serverInfo) {
        print('Server ready at ${serverInfo.httpUrl}');
      },
      onClientConnect: (clientId, clientInfo) {
        print('Client connected: $clientId');
      },
    ),
  );
  
  try {
    await serverManager.start();
    
    // Server is now running with HTTP, WebSocket, and Discovery services
    // Keep running...
    
  } finally {
    await serverManager.dispose();
  }
}
```

See `simple_server_example.dart` for a complete simple example and `local_server_example.dart` for comprehensive usage.

## Individual HTTP Server Usage

For advanced use cases, you can also use the individual HTTP server components:

## Basic Usage

### 1. Simple Server Setup

```dart
import 'package:restaurant_local_server/restaurant_local_server.dart';

void main() async {
  final server = HttpServer();
  
  // Start server with default configuration
  await server.start();
  
  print('Server running on http://localhost:8080');
}
```

### 2. Custom Configuration

```dart
const config = HttpServerConfig(
  httpPort: 8080,
  webSocketPort: 8081,
  discoveryPort: 8082,
  enableCors: true,
  enableLogging: true,
  enableDiscovery: true,
  enableWebSocket: true,
  customHeaders: {
    'X-Server': 'My Custom Server',
    'X-Version': '1.0.0',
  },
);

await server.start(config: config);
```

## Custom Route Handlers

### 1. Manual Route Registration

```dart
class UserRouteHandler implements RouteHandler {
  @override
  void registerRoutes(Router router) {
    router.get('/api/users', _getAllUsers);
    router.post('/api/users', _createUser);
    // ... other routes
  }
  
  Future<Response> _getAllUsers(Request request) async {
    // Your implementation
    return HttpUtils.successResponse(users);
  }
}

// Register the handler
server.addRouteHandler(UserRouteHandler());
```

### 2. CRUD Route Handler (Recommended)

```dart
class ProductCrudHandler extends CrudRouteHandler {
  ProductCrudHandler() : super(resourceName: 'Product');
  
  @override
  Future<List<Map<String, dynamic>>> getAll(Request request) async {
    // Return all products
    return products;
  }
  
  @override
  Future<Map<String, dynamic>?> getById(String id, Request request) async {
    // Return product by ID
    return products[id];
  }
  
  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data, Request request) async {
    // Create new product
    final product = createProduct(data);
    return product;
  }
  
  // Implement update() and delete() methods...
}

// Register the CRUD handler
server.addRouteHandler(ProductCrudHandler());
```

This automatically creates routes:
- `GET /api/products` - Get all products
- `GET /api/products/:id` - Get product by ID
- `POST /api/products` - Create product
- `PUT /api/products/:id` - Update product
- `DELETE /api/products/:id` - Delete product

## Custom Middleware

```dart
Middleware authMiddleware() => (Handler innerHandler) {
  return (Request request) async {
    final authHeader = request.headers['authorization'];
    
    if (authHeader == null || !isValidToken(authHeader)) {
      return Response.unauthorized(
        jsonEncode({'error': 'Unauthorized'}),
      );
    }
    
    return await innerHandler(request);
  };
};

// Add the middleware
server.addMiddleware(authMiddleware());
```

## WebSocket Integration

The HTTP server automatically integrates with WebSocket for real-time notifications:

```dart
// WebSocket notifications are automatically sent for CRUD operations
// You can also manually send notifications:

server.webSocketNotifier?.notifyDataChange('custom_event', {
  'message': 'Something happened',
  'timestamp': DateTime.now().toIso8601String(),
});

server.webSocketNotifier?.broadcastSystemMessage(
  'System maintenance in 5 minutes',
  level: 'warning',
);
```

## Built-in Endpoints

Every HTTP server includes these system endpoints:

- `GET /health` - Health check
- `GET /api/system/info` - Server information
- `GET /api/system/websocket/clients` - WebSocket client info
- `POST /api/system/broadcast` - Broadcast system message

## Utility Functions

Use the `HttpUtils` class for common operations:

```dart
// Standard success response
return HttpUtils.successResponse(data);

// Standard error response
return HttpUtils.errorResponse('Not found', statusCode: 404);

// Parse JSON body safely
final json = await HttpUtils.parseJsonBody(request);

// Get query parameters
final params = HttpUtils.getQueryParams(request);
```

## Complete Example

See `http_server_example.dart` for a complete working example that demonstrates:

- Custom route handlers
- CRUD operations with WebSocket notifications
- Custom middleware
- Configuration options
- Real-time communication

## Testing

You can test the server using curl or any HTTP client:

```bash
# Health check
curl http://localhost:8080/health

# Create user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# Get all users
curl http://localhost:8080/api/users

# Connect to WebSocket
wscat -c ws://localhost:8081
```