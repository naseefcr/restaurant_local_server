/// A generic Flutter package for building local server applications with UDP discovery,
/// HTTP REST APIs, WebSocket support, and real-time synchronization capabilities.
library;

// Models
export 'src/models/server_info.dart';
export 'src/models/websocket_message.dart';

// Networking
export 'src/networking/discovery_service.dart';
export 'src/networking/http_server.dart' show LocalHttpServer, HttpServerConfig, RouteHandler, WebSocketNotifier, CrudRouteHandler, HttpUtils;
export 'src/networking/websocket_server.dart';

// Services
export 'src/services/local_server_manager.dart';
