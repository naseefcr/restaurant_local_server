import 'package:restaurant_local_server/restaurant_local_server.dart';

/// Basic example showing how to create and start a local server
/// with HTTP API, WebSocket, and UDP discovery capabilities.
void main() async {
  print('🚀 Starting Restaurant Local Server Example');

  try {
    // Create server configuration
    final config = LocalServerConfig(
      serverName: 'Example Restaurant Server',
      version: '1.0.0',
      description: 'A simple example server for restaurant management',
      capabilities: ['orders', 'tables', 'real_time_sync'],
      
      // Network configuration
      httpPort: 8080,
      webSocketPort: 8081,
      discoveryPort: 8082,
      
      // Enable all services
      enableHttpServer: true,
      enableWebSocketServer: true,
      enableDiscoveryService: true,
      
      // Health monitoring
      enableHealthMonitoring: true,
      healthCheckIntervalSeconds: 30,
      
      // Auto recovery
      autoRecovery: true,
      maxRecoveryAttempts: 3,
      
      // Custom metadata
      customMetadata: {
        'location': 'Main Branch',
        'environment': 'example',
        'features': ['pos', 'inventory', 'reporting'],
      },
    );

    // Create event handlers
    final eventHandlers = LocalServerEventHandlers(
      onStatusChange: (status) {
        print('📊 Server Status Changed: $status');
      },
      
      onHealthChange: (health) {
        print('❤️ Server Health: $health');
      },
      
      onClientConnect: (clientId, clientInfo) {
        print('🔗 Client Connected: $clientId (${clientInfo.clientType})');
        print('   Remote Address: ${clientInfo.remoteAddress}');
        print('   User Agent: ${clientInfo.userAgent}');
      },
      
      onClientDisconnect: (clientId, reason) {
        print('🔌 Client Disconnected: $clientId - $reason');
      },
      
      onError: (error) {
        print('❌ Server Error: $error');
      },
      
      onRecoveryAttempt: (attempt, maxAttempts, service) {
        print('🔄 Recovery Attempt $attempt/$maxAttempts for $service');
      },
    );

    // Create and configure server manager
    final serverManager = LocalServerManager(
      config: config,
      eventHandlers: eventHandlers,
    );

    // Start the server
    print('🔧 Starting all services...');
    await serverManager.start();

    // Display server information
    final serverInfo = await serverManager.getServerInfo();
    print('\n✅ Server Started Successfully!');
    print('📋 Server Details:');
    print('   Name: ${serverInfo.name}');
    print('   Version: ${serverInfo.version}');
    print('   Address: ${serverInfo.address}');
    print('   HTTP Port: ${serverInfo.httpPort}');
    print('   WebSocket Port: ${serverInfo.webSocketPort}');
    print('   Discovery Port: ${serverInfo.discoveryPort}');
    print('   Capabilities: ${serverInfo.capabilities.join(', ')}');

    // Display access URLs
    print('\n🌐 Access URLs:');
    print('   HTTP API: ${serverInfo.httpUrl}');
    print('   WebSocket: ${serverInfo.webSocketUrl}');
    print('   Health Check: ${serverInfo.httpUrl}/health');

    // Display server statistics periodically
    print('\n📊 Server Statistics:');
    _startStatsDisplay(serverManager);

    // Simulate some server activity
    _simulateServerActivity(serverManager);

    print('\n🎯 Server is running! Press Ctrl+C to stop.');
    print('💡 Try connecting clients or accessing the HTTP endpoints.');
    
  } catch (e, stackTrace) {
    print('💥 Failed to start server: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Periodically display server statistics
void _startStatsDisplay(LocalServerManager serverManager) {
  // Update stats every 10 seconds
  Stream.periodic(Duration(seconds: 10)).listen((_) async {
    final stats = serverManager.getServerStats();
    final serverInfo = await serverManager.getServerInfo();
    
    print('\n📈 Server Stats Update:');
    print('   Status: ${stats['status']}');
    print('   Health: ${stats['health']}');
    print('   Uptime: ${stats['uptime']}');
    print('   Connected Clients: ${stats['connectedClients']}');
    print('   Total Connections: ${stats['totalConnections']}');
    print('   Active Services: ${stats['activeServices']}');
    
    if (stats['connectedClients'] > 0) {
      print('   Client Types: ${stats['clientTypes']}');
    }
  });
}

/// Simulate some server activity for demonstration
void _simulateServerActivity(LocalServerManager serverManager) {
  // Simulate periodic system messages
  Stream.periodic(Duration(seconds: 30)).listen((_) {
    final messages = [
      'System health check completed',
      'Database backup in progress',
      'New feature deployed successfully',
      'Scheduled maintenance reminder',
      'Performance optimization applied',
    ];
    
    final message = messages[DateTime.now().millisecond % messages.length];
    serverManager.broadcastSystemMessage(message);
    print('📢 Broadcasted: $message');
  });

  // Simulate periodic entity updates
  Stream.periodic(Duration(seconds: 20)).listen((_) {
    final entityTypes = ['order', 'table', 'product', 'user'];
    final statuses = ['active', 'pending', 'completed', 'cancelled'];
    
    final entityType = entityTypes[DateTime.now().millisecond % entityTypes.length];
    final status = statuses[DateTime.now().second % statuses.length];
    final entityId = DateTime.now().millisecondsSinceEpoch.toString();
    
    serverManager.broadcastEntityStatusUpdate(
      entityType: entityType,
      entityId: entityId,
      status: status,
      additionalData: {
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'simulation',
      },
    );
    
    print('🔄 Simulated $entityType update: $status');
  });
}