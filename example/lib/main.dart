import 'package:restaurant_local_server/restaurant_local_server.dart';

/// Basic example showing how to create and start a local server
/// with HTTP API, WebSocket, and UDP discovery capabilities.
void main() async {
  print('🚀 Starting Restaurant Local Server Example');

  try {
    // Create server configuration
    final config = LocalServerConfig(
      serverName: 'Example Restaurant Server',
      serverVersion: '1.0.0',
      capabilities: {
        'orders': true,
        'tables': true,
        'real_time_sync': true,
      },
      
      // Network configuration
      httpConfig: const HttpServerConfig(
        httpPort: 8080,
        enableCors: true,
      ),
      webSocketConfig: const WebSocketServerConfig(
        port: 8081,
        heartbeatIntervalSeconds: 30,
      ),
      discoveryConfig: const DiscoveryConfig(
        discoveryPort: 8082,
        broadcastInterval: Duration(seconds: 5),
      ),
      
      // Health monitoring and recovery
      enableAutoRecovery: true,
      healthCheckIntervalSeconds: 30,
      maxRecoveryAttempts: 3,
      enableLogging: true,
    );

    // Create event handlers
    final eventHandlers = LocalServerEventHandlers(
      onStatusChange: (oldStatus, newStatus) {
        print('📊 Server Status Changed: $oldStatus -> $newStatus');
      },
      
      onHealthChange: (oldHealth, newHealth) {
        print('❤️ Server Health: $oldHealth -> $newHealth');
      },
      
      onClientConnect: (clientId, clientInfo) {
        print('🔗 Client Connected: $clientId');
        print('   Remote Address: ${clientInfo.remoteAddress}');
        print('   User Agent: ${clientInfo.userAgent}');
      },
      
      onClientDisconnect: (clientId, reason) {
        print('🔌 Client Disconnected: $clientId - $reason');
      },
      
      onError: (error, details) {
        print('❌ Server Error: $error');
        if (details != null) print('   Details: $details');
      },
      
      onRecoveryAttempt: (service, attemptNumber) {
        print('🔄 Recovery Attempt $attemptNumber for $service');
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
    final serverInfo = serverManager.serverInfo;
    print('\n✅ Server Started Successfully!');
    print('📋 Server Details:');
    if (serverInfo != null) {
      print('   Name: ${serverInfo.name}');
      print('   Version: ${serverInfo.version}');
      print('   IP Address: ${serverInfo.ipAddress}');
      print('   HTTP Port: ${serverInfo.httpPort}');
      print('   WebSocket Port: ${serverInfo.webSocketPort}');
      print('   Capabilities: ${serverInfo.capabilities.keys.join(', ')}');
    }

    // Display access URLs
    if (serverInfo != null) {
      print('\n🌐 Access URLs:');
      print('   HTTP API: ${serverInfo.httpUrl}');
      print('   WebSocket: ${serverInfo.webSocketUrl}');
      print('   Health Check: ${serverInfo.httpUrl}/health');
    }

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
    final stats = serverManager.getStatistics();
    
    print('\n📈 Server Stats Update:');
    print('   Status: ${stats.status}');
    print('   Health: ${stats.healthStatus}');
    print('   Uptime: ${stats.uptime}');
    print('   Connected Clients: ${stats.connectedClients}');
    print('   Service Health: ${stats.serviceHealth.keys.join(', ')}');
    
    if (stats.connectedClients > 0) {
      print('   Connected Client Count: ${stats.connectedClients}');
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
    serverManager.broadcastSystemMessage(message: message);
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