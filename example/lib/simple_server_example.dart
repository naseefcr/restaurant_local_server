import 'package:restaurant_local_server/restaurant_local_server.dart';

/// Simple example showing basic LocalServerManager usage
void main() async {
  print('Starting simple local server...');
  
  // Create server manager with default configuration
  final serverManager = LocalServerManager(
    config: const LocalServerConfig(
      serverName: 'Simple Server',
      enableLogging: true,
    ),
    eventHandlers: LocalServerEventHandlers(
      onStatusChange: (oldStatus, newStatus) {
        print('Status: ${oldStatus.name} -> ${newStatus.name}');
      },
      onServerStarted: (serverInfo) {
        print('Server ready at ${serverInfo.httpUrl}');
        print('WebSocket at ${serverInfo.webSocketUrl}');
      },
      onClientConnect: (clientId, clientInfo) {
        print('Client connected: $clientId');
      },
    ),
  );
  
  try {
    // Start the server
    await serverManager.start();
    
    // Send a welcome message
    serverManager.broadcastSystemMessage(
      message: 'Simple server is now running!',
    );
    
    // Keep running for 30 seconds
    print('Server will run for 30 seconds...');
    await Future.delayed(const Duration(seconds: 30));
    
  } catch (e) {
    print('Error: $e');
  } finally {
    // Graceful shutdown
    await serverManager.dispose();
    print('Server stopped.');
  }
}