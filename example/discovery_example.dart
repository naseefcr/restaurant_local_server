import 'package:restaurant_local_server/restaurant_local_server.dart';

/// Example demonstrating how to use the NetworkDiscoveryService
/// for both server and client scenarios.
void main() async {
  print('Network Discovery Service Example');
  print('==================================\n');
  
  // Example 1: Starting a server with discovery
  await startServerExample();
  
  await Future.delayed(const Duration(seconds: 2));
  
  // Example 2: Discovering servers from a client
  await discoverServersExample();
  
  // Example 3: Custom configuration
  await customConfigurationExample();
}

/// Example of starting a server with UDP discovery broadcasting
Future<void> startServerExample() async {
  print('1. Starting Server with Discovery');
  print('----------------------------------');
  
  try {
    // Create server information
    final serverInfo = ServerInfo.create(
      name: 'My Local Server',
      version: '1.0.0',
      ipAddress: '192.168.1.100', // Replace with actual IP
      httpPort: 8080,
      webSocketPort: 8081,
      capabilities: {
        'api': true,
        'websocket': true,
        'realtime': true,
        'custom_feature': true,
      },
    );
    
    // Get discovery service instance
    final discoveryService = NetworkDiscoveryService();
    
    // Start server mode (broadcasting)
    await discoveryService.startServer(serverInfo);
    
    print('✅ Server discovery started successfully');
    print('📡 Broadcasting server info: ${serverInfo.name}');
    print('🌐 Server URL: ${serverInfo.httpUrl}');
    print('🔌 WebSocket URL: ${serverInfo.webSocketUrl}');
    
    // In a real application, keep the server running
    // For this example, we'll stop it after a few seconds
    await Future.delayed(const Duration(seconds: 3));
    await discoveryService.stop();
    print('🛑 Server discovery stopped\n');
    
  } catch (e) {
    print('❌ Error starting server discovery: $e\n');
  }
}

/// Example of discovering servers on the network (client mode)
Future<void> discoverServersExample() async {
  print('2. Discovering Servers (Client Mode)');
  print('-----------------------------------');
  
  try {
    print('🔍 Searching for servers on the network...');
    
    // Discover servers with default configuration
    final servers = await NetworkDiscoveryService.discoverServers();
    
    if (servers.isEmpty) {
      print('❌ No servers found on the network');
    } else {
      print('✅ Found ${servers.length} server(s):');
      
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        print('  Server ${i + 1}:');
        print('    Name: ${server.name}');
        print('    Version: ${server.version}');
        print('    IP: ${server.ipAddress}');
        print('    HTTP Port: ${server.httpPort}');
        print('    WebSocket Port: ${server.webSocketPort}');
        print('    Capabilities: ${server.capabilities}');
        print('    Started: ${server.startTime}');
        print('    HTTP URL: ${server.httpUrl}');
        print('    WebSocket URL: ${server.webSocketUrl}');
        print('');
      }
    }
    
  } catch (e) {
    print('❌ Error discovering servers: $e');
  }
  
  print('');
}

/// Example of using custom discovery configuration
Future<void> customConfigurationExample() async {
  print('3. Custom Discovery Configuration');
  print('--------------------------------');
  
  try {
    // Create custom configuration
    const customConfig = DiscoveryConfig(
      discoveryPort: 9082,           // Custom discovery port
      broadcastInterval: Duration(seconds: 5),  // Faster broadcasting
      discoveryTimeout: Duration(seconds: 15),  // Longer discovery timeout
      maxDiscoveryAttempts: 2,       // Fewer attempts
      enableLogging: true,           // Enable detailed logging
      logNetworkInterfaces: true,    // Log network interfaces
      customSubnetMask: '255.255.0.0', // Custom subnet mask (/16)
    );
    
    print('🔧 Using custom configuration:');
    print('   Discovery Port: ${customConfig.discoveryPort}');
    print('   Broadcast Interval: ${customConfig.broadcastInterval.inSeconds}s');
    print('   Discovery Timeout: ${customConfig.discoveryTimeout.inSeconds}s');
    print('   Max Attempts: ${customConfig.maxDiscoveryAttempts}');
    print('   Custom Subnet: ${customConfig.customSubnetMask}');
    
    // Discover servers with custom configuration
    print('\n🔍 Discovering servers with custom config...');
    final servers = await NetworkDiscoveryService.discoverServers(customConfig);
    
    print('✅ Discovery completed with custom config');
    print('📊 Found ${servers.length} servers');
    
  } catch (e) {
    print('❌ Error with custom configuration: $e');
  }
}

/// Example of getting network information
Future<void> networkInfoExample() async {
  print('4. Network Information');
  print('---------------------');
  
  try {
    final discoveryService = NetworkDiscoveryService();
    
    // Get primary local IP
    final primaryIp = await discoveryService.getLocalIpAddress();
    print('🌐 Primary IP Address: ${primaryIp ?? "Not found"}');
    
    // Get all local IP addresses
    final allIps = await discoveryService.getAllLocalIpAddresses();
    print('📋 All IP Addresses: ${allIps.join(", ")}');
    
    // Check service status
    print('📊 Service Running: ${discoveryService.isRunning}');
    print('📊 Current Server Info: ${discoveryService.serverInfo?.name ?? "None"}');
    
  } catch (e) {
    print('❌ Error getting network info: $e');
  }
}

/// Example of error handling and recovery
Future<void> errorHandlingExample() async {
  print('5. Error Handling Example');
  print('-------------------------');
  
  try {
    final discoveryService = NetworkDiscoveryService();
    
    // Try to start server without proper IP (will fail)
    final badServerInfo = ServerInfo.create(
      name: 'Bad Server',
      version: '1.0.0',
      ipAddress: 'invalid-ip', // This will cause issues
    );
    
    await discoveryService.startServer(badServerInfo);
    
  } catch (e) {
    print('❌ Expected error caught: $e');
    print('✅ Error handling working correctly');
  }
  
  try {
    // Try to start service again (should fail due to already running)
    final discoveryService = NetworkDiscoveryService();
    
    if (discoveryService.isRunning) {
      await discoveryService.startServer(ServerInfo.create(
        name: 'Another Server',
        version: '1.0.0',
        ipAddress: '192.168.1.101',
      ));
    }
    
  } catch (e) {
    print('❌ Expected StateError caught: $e');
    print('✅ State management working correctly');
  }
}