import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import '../models/server_info.dart';
import 'websocket_server.dart';

/// Configuration options for the HTTP server
class HttpServerConfig {
  final int httpPort;
  final int webSocketPort;
  final int discoveryPort;
  final String? bindAddress;
  final bool enableCors;
  final bool enableLogging;
  final bool enableDiscovery;
  final bool enableWebSocket;
  final Map<String, String>? customHeaders;
  
  const HttpServerConfig({
    this.httpPort = 8080,
    this.webSocketPort = 8081,
    this.discoveryPort = 8082,
    this.bindAddress,
    this.enableCors = true,
    this.enableLogging = true,
    this.enableDiscovery = true,
    this.enableWebSocket = true,
    this.customHeaders,
  });
}

/// Handler for HTTP route operations
abstract class RouteHandler {
  /// Register routes with the provided router
  void registerRoutes(Router router);
}

/// WebSocket notification interface for HTTP operations
abstract class WebSocketNotifier {
  /// Send a notification about a data change
  void notifyDataChange(String event, Map<String, dynamic> data);
  
  /// Broadcast a system message
  void broadcastSystemMessage(String message, {String? level});
}

/// Generic HTTP server with extensible architecture
class LocalHttpServer {
  LocalHttpServer._internal();
  
  static final LocalHttpServer _instance = LocalHttpServer._internal();
  factory LocalHttpServer() => _instance;
  
  HttpServer? _server;
  HttpServerConfig? _config;
  ServerInfo? _serverInfo;
  WebSocketServer? _webSocketServer;
  
  final List<RouteHandler> _routeHandlers = [];
  final List<Middleware> _customMiddlewares = [];
  WebSocketNotifier? _webSocketNotifier;
  
  bool get isRunning => _server != null;
  ServerInfo? get serverInfo => _serverInfo;
  WebSocketNotifier? get webSocketNotifier => _webSocketNotifier;
  
  /// Add a custom route handler
  void addRouteHandler(RouteHandler handler) {
    _routeHandlers.add(handler);
  }
  
  /// Add custom middleware
  void addMiddleware(Middleware middleware) {
    _customMiddlewares.add(middleware);
  }
  
  /// Set WebSocket notifier for real-time updates
  void setWebSocketNotifier(WebSocketNotifier notifier) {
    _webSocketNotifier = notifier;
  }
  
  /// Start the HTTP server with optional configuration
  Future<void> start({HttpServerConfig? config}) async {
    if (isRunning) {
      throw StateError('Server is already running');
    }
    
    _config = config ?? const HttpServerConfig();
    
    try {
      // Get local IP address
      final ipAddress = await _getLocalIpAddress() ?? 'localhost';
      
      // Create server info
      _serverInfo = ServerInfo.create(
        name: 'Generic HTTP Server',
        version: '1.0.0',
        ipAddress: ipAddress,
        httpPort: _config!.httpPort,
        webSocketPort: _config!.webSocketPort,
        capabilities: {
          'http': true,
          'websocket': _config!.enableWebSocket,
          'discovery': _config!.enableDiscovery,
        },
      );
      
      // Create router
      final router = Router();
      
      // Add system routes (health check, server info)
      _addSystemRoutes(router);
      
      // Register all custom route handlers
      for (final handler in _routeHandlers) {
        handler.registerRoutes(router);
      }
      
      // Create middleware pipeline
      final pipeline = Pipeline();
      
      // Add CORS if enabled
      if (_config!.enableCors) {
        pipeline.addMiddleware(corsHeaders());
      }
      
      // Add logging if enabled
      if (_config!.enableLogging) {
        pipeline.addMiddleware(logRequests());
      }
      
      // Add JSON middleware
      pipeline.addMiddleware(_jsonMiddleware);
      
      // Add custom middlewares
      for (final middleware in _customMiddlewares) {
        pipeline.addMiddleware(middleware);
      }
      
      final handler = pipeline.addHandler(router);
      
      // Start HTTP server
      final bindAddress = _config!.bindAddress != null 
          ? InternetAddress(_config!.bindAddress!)
          : InternetAddress.anyIPv4;
          
      _server = await shelf_io.serve(handler, bindAddress, _config!.httpPort);
      print('HTTP server started on http://$ipAddress:${_config!.httpPort}');
      
      // Start WebSocket server if enabled
      if (_config!.enableWebSocket) {
        _webSocketServer = WebSocketServer(
          config: WebSocketServerConfig(port: _config!.webSocketPort),
        );
        await _webSocketServer!.start();
        print('WebSocket server started on port ${_config!.webSocketPort}');
        
        // Set up WebSocket notifier
        if (_webSocketNotifier == null) {
          _webSocketNotifier = _DefaultWebSocketNotifier(_webSocketServer!);
        }
      }
      
      print('All services started successfully');
    } catch (e) {
      print('Error starting HTTP server: $e');
      await stop();
      rethrow;
    }
  }
  
  /// JSON middleware for automatic content-type headers
  Middleware get _jsonMiddleware => (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);
      final headers = Map<String, String>.from(response.headers);
      
      // Set JSON content type if not already set
      if (!headers.containsKey('content-type') && 
          !headers.containsKey('Content-Type')) {
        headers['Content-Type'] = 'application/json';
      }
      
      // Add custom headers if configured
      if (_config?.customHeaders != null) {
        headers.addAll(_config!.customHeaders!);
      }
      
      return response.change(headers: headers);
    };
  };
  
  /// Add system routes for health checks and server information
  void _addSystemRoutes(Router router) {
    // Health check endpoint
    router.get('/health', (Request request) async {
      return Response.ok(
        jsonEncode({
          'status': 'healthy',
          'timestamp': DateTime.now().toIso8601String(),
          'server': _serverInfo?.toJson(),
        }),
      );
    });
    
    // Server info endpoint
    router.get('/api/system/info', (Request request) async {
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': _serverInfo?.toJson(),
        }),
      );
    });
    
    // WebSocket clients info (if WebSocket is enabled)
    router.get('/api/system/websocket/clients', (Request request) async {
      if (_webSocketServer == null) {
        return Response.ok(
          jsonEncode({
            'success': true,
            'data': {
              'websocket_enabled': false,
              'client_count': 0,
            },
          }),
        );
      }
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'websocket_enabled': true,
            'client_count': _webSocketServer!.clientCount,
            'clients': _webSocketServer!.getAllClientsInfo(),
          },
        }),
      );
    });
    
    // System broadcast endpoint
    router.post('/api/system/broadcast', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final message = data['message'] as String;
        final level = data['level'] as String?;
        
        _webSocketNotifier?.broadcastSystemMessage(message, level: level);
        
        return Response.ok(
          jsonEncode({
            'success': true,
            'data': {'broadcasted': true},
          }),
        );
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'error': e.toString()}),
        );
      }
    });
  }
  
  /// Get local IP address
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP address: $e');
    }
    return null;
  }
  
  /// Stop the HTTP server and all associated services
  Future<void> stop() async {
    print('Stopping HTTP server...');
    
    try {
      // Stop WebSocket server
      if (_webSocketServer != null) {
        await _webSocketServer!.stop();
        _webSocketServer = null;
      }
      
      // Stop HTTP server
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }
      
      _serverInfo = null;
      _config = null;
      _webSocketNotifier = null;
      
      print('HTTP server stopped successfully');
    } catch (e) {
      print('Error stopping HTTP server: $e');
      rethrow;
    }
  }
}

/// Default WebSocket notifier implementation
class _DefaultWebSocketNotifier implements WebSocketNotifier {
  final WebSocketServer _webSocketServer;
  
  _DefaultWebSocketNotifier(this._webSocketServer);
  
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

/// Generic CRUD route handler base class
abstract class CrudRouteHandler implements RouteHandler {
  final String resourceName;
  final String basePath;
  
  CrudRouteHandler({
    required this.resourceName,
    String? basePath,
  }) : basePath = basePath ?? '/api/${resourceName.toLowerCase()}';
  
  @override
  void registerRoutes(Router router) {
    // GET /api/resource - Get all items
    router.get(basePath, _handleGetAll);
    
    // GET /api/resource/:id - Get item by ID
    router.get('$basePath/<id>', _handleGetById);
    
    // POST /api/resource - Create new item
    router.post(basePath, _handleCreate);
    
    // PUT /api/resource/:id - Update item
    router.put('$basePath/<id>', _handleUpdate);
    
    // DELETE /api/resource/:id - Delete item
    router.delete('$basePath/<id>', _handleDelete);
  }
  
  Future<Response> _handleGetAll(Request request) async {
    try {
      final items = await getAll(request);
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': items,
        }),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
  
  Future<Response> _handleGetById(Request request) async {
    try {
      final id = request.params['id']!;
      final item = await getById(id, request);
      
      if (item == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'error': '$resourceName not found'}),
        );
      }
      
      return Response.ok(
        jsonEncode({'success': true, 'data': item}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
  
  Future<Response> _handleCreate(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final result = await create(data, request);
      
      // Notify WebSocket clients if notifier is available
      LocalHttpServer()._webSocketNotifier?.notifyDataChange(
        '${resourceName.toLowerCase()}_created',
        result,
      );
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': result,
        }),
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
  
  Future<Response> _handleUpdate(Request request) async {
    try {
      final id = request.params['id']!;
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final result = await update(id, data, request);
      
      if (result == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'error': '$resourceName not found'}),
        );
      }
      
      // Notify WebSocket clients if notifier is available
      LocalHttpServer()._webSocketNotifier?.notifyDataChange(
        '${resourceName.toLowerCase()}_updated',
        result,
      );
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': result,
        }),
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
  
  Future<Response> _handleDelete(Request request) async {
    try {
      final id = request.params['id']!;
      final success = await delete(id, request);
      
      if (!success) {
        return Response.notFound(
          jsonEncode({'success': false, 'error': '$resourceName not found'}),
        );
      }
      
      // Notify WebSocket clients if notifier is available
      LocalHttpServer()._webSocketNotifier?.notifyDataChange(
        '${resourceName.toLowerCase()}_deleted',
        {'id': id},
      );
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'deleted': true, 'id': id},
        }),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }
  
  /// Override these methods to implement CRUD operations
  Future<List<Map<String, dynamic>>> getAll(Request request);
  Future<Map<String, dynamic>?> getById(String id, Request request);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data, Request request);
  Future<Map<String, dynamic>?> update(String id, Map<String, dynamic> data, Request request);
  Future<bool> delete(String id, Request request);
}

/// Utility functions for common HTTP operations
class HttpUtils {
  /// Create a standard success response
  static Response successResponse(dynamic data, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': true,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  /// Create a standard error response
  static Response errorResponse(String error, {int statusCode = 400}) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': false,
        'error': error,
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  /// Parse JSON request body safely
  static Future<Map<String, dynamic>?> parseJsonBody(Request request) async {
    try {
      final body = await request.readAsString();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  
  /// Extract query parameters as a map
  static Map<String, String> getQueryParams(Request request) {
    return Map<String, String>.from(request.requestedUri.queryParameters);
  }
}