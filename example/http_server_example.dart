import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../lib/restaurant_local_server.dart';

// Example of a custom route handler
class UserRouteHandler implements RouteHandler {
  final Map<String, Map<String, dynamic>> _users = {};
  int _nextId = 1;
  
  @override
  void registerRoutes(Router router) {
    router.get('/api/users', _getAllUsers);
    router.get('/api/users/<id>', _getUserById);
    router.post('/api/users', _createUser);
    router.put('/api/users/<id>', _updateUser);
    router.delete('/api/users/<id>', _deleteUser);
  }
  
  Future<Response> _getAllUsers(Request request) async {
    return Response.ok(
      jsonEncode({
        'success': true,
        'data': _users.values.toList(),
      }),
    );
  }
  
  Future<Response> _getUserById(Request request) async {
    final id = request.params['id']!;
    final user = _users[id];
    
    if (user == null) {
      return Response.notFound(
        jsonEncode({'success': false, 'error': 'User not found'}),
      );
    }
    
    return Response.ok(
      jsonEncode({'success': true, 'data': user}),
    );
  }
  
  Future<Response> _createUser(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final id = (_nextId++).toString();
      final user = {
        'id': id,
        'name': data['name'],
        'email': data['email'],
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      _users[id] = user;
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': user,
        }),
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
  
  Future<Response> _updateUser(Request request) async {
    try {
      final id = request.params['id']!;
      final existingUser = _users[id];
      
      if (existingUser == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'error': 'User not found'}),
        );
      }
      
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final updatedUser = {
        ...existingUser,
        'name': data['name'] ?? existingUser['name'],
        'email': data['email'] ?? existingUser['email'],
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      _users[id] = updatedUser;
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': updatedUser,
        }),
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
  
  Future<Response> _deleteUser(Request request) async {
    final id = request.params['id']!;
    final user = _users.remove(id);
    
    if (user == null) {
      return Response.notFound(
        jsonEncode({'success': false, 'error': 'User not found'}),
      );
    }
    
    return Response.ok(
      jsonEncode({
        'success': true,
        'data': {'deleted': true, 'id': id},
      }),
    );
  }
}

// Example of a CRUD route handler using the base class
class ProductCrudHandler extends CrudRouteHandler {
  final Map<String, Map<String, dynamic>> _products = {};
  int _nextId = 1;
  
  ProductCrudHandler() : super(resourceName: 'Product');
  
  @override
  Future<List<Map<String, dynamic>>> getAll(Request request) async {
    return _products.values.toList();
  }
  
  @override
  Future<Map<String, dynamic>?> getById(String id, Request request) async {
    return _products[id];
  }
  
  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data, Request request) async {
    final id = (_nextId++).toString();
    final product = {
      'id': id,
      'name': data['name'],
      'price': data['price'],
      'category': data['category'],
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    _products[id] = product;
    return product;
  }
  
  @override
  Future<Map<String, dynamic>?> update(String id, Map<String, dynamic> data, Request request) async {
    final existingProduct = _products[id];
    if (existingProduct == null) return null;
    
    final updatedProduct = {
      ...existingProduct,
      'name': data['name'] ?? existingProduct['name'],
      'price': data['price'] ?? existingProduct['price'],
      'category': data['category'] ?? existingProduct['category'],
      'updatedAt': DateTime.now().toIso8601String(),
    };
    
    _products[id] = updatedProduct;
    return updatedProduct;
  }
  
  @override
  Future<bool> delete(String id, Request request) async {
    final removed = _products.remove(id);
    return removed != null;
  }
}

// Example of custom middleware
Middleware requestIdMiddleware() => (Handler innerHandler) {
  return (Request request) async {
    final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
    print('Processing request $requestId: ${request.method} ${request.url}');
    
    final response = await innerHandler(request);
    
    return response.change(
      headers: {'X-Request-Id': requestId, ...response.headers},
    );
  };
};

void main() async {
  try {
    // Get HTTP server instance
    final server = LocalHttpServer();
    
    // Add custom route handlers
    server.addRouteHandler(UserRouteHandler());
    server.addRouteHandler(ProductCrudHandler());
    
    // Add custom middleware
    server.addMiddleware(requestIdMiddleware());
    
    // Configure server
    const config = HttpServerConfig(
      httpPort: 8080,
      webSocketPort: 8081,
      discoveryPort: 8082,
      enableCors: true,
      enableLogging: true,
      enableDiscovery: true,
      enableWebSocket: true,
      customHeaders: {
        'X-Server': 'Generic HTTP Server Example',
        'X-Version': '1.0.0',
      },
    );
    
    // Start server
    print('Starting HTTP server...');
    await server.start(config: config);
    print('Server started successfully!');
    print('Available endpoints:');
    print('- Health: GET http://localhost:8080/health');
    print('- System Info: GET http://localhost:8080/api/system/info');
    print('- WebSocket Clients: GET http://localhost:8080/api/system/websocket/clients');
    print('- Users: GET/POST http://localhost:8080/api/users');
    print('- Products: GET/POST http://localhost:8080/api/products');
    print('- WebSocket: ws://localhost:8081');
    
    // Example of broadcasting a system message
    await Future.delayed(Duration(seconds: 2));
    server.webSocketNotifier?.broadcastSystemMessage(
      'Server is ready to handle requests!',
      level: 'info',
    );
    
    // Keep the server running - you can also send system messages via HTTP POST to /api/system/broadcast
    print('You can broadcast system messages by sending POST to /api/system/broadcast');
    print('Example: {"message": "Hello clients!", "level": "info"}');
    
    // Keep the server running
    print('Press Ctrl+C to stop the server');
    
  } catch (e) {
    print('Error starting server: $e');
  }
}