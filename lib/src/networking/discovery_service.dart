import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../models/server_info.dart';

/// Configuration options for the discovery service.
class DiscoveryConfig {
  /// Port used for UDP discovery communication
  final int discoveryPort;
  
  /// Broadcast address for network discovery
  final String broadcastAddress;
  
  /// Interval between periodic server broadcasts
  final Duration broadcastInterval;
  
  /// Timeout duration for client discovery requests
  final Duration discoveryTimeout;
  
  /// Maximum number of discovery attempts
  final int maxDiscoveryAttempts;
  
  /// Enable verbose logging
  final bool enableLogging;
  
  /// Enable network interface logging
  final bool logNetworkInterfaces;
  
  /// Custom subnet mask for broadcast calculations (e.g., '255.255.255.0' for /24)
  final String? customSubnetMask;

  const DiscoveryConfig({
    this.discoveryPort = 8082,
    this.broadcastAddress = '255.255.255.255',
    this.broadcastInterval = const Duration(seconds: 10),
    this.discoveryTimeout = const Duration(seconds: 10),
    this.maxDiscoveryAttempts = 3,
    this.enableLogging = true,
    this.logNetworkInterfaces = false,
    this.customSubnetMask,
  });

  DiscoveryConfig copyWith({
    int? discoveryPort,
    String? broadcastAddress,
    Duration? broadcastInterval,
    Duration? discoveryTimeout,
    int? maxDiscoveryAttempts,
    bool? enableLogging,
    bool? logNetworkInterfaces,
    String? customSubnetMask,
  }) {
    return DiscoveryConfig(
      discoveryPort: discoveryPort ?? this.discoveryPort,
      broadcastAddress: broadcastAddress ?? this.broadcastAddress,
      broadcastInterval: broadcastInterval ?? this.broadcastInterval,
      discoveryTimeout: discoveryTimeout ?? this.discoveryTimeout,
      maxDiscoveryAttempts: maxDiscoveryAttempts ?? this.maxDiscoveryAttempts,
      enableLogging: enableLogging ?? this.enableLogging,
      logNetworkInterfaces: logNetworkInterfaces ?? this.logNetworkInterfaces,
      customSubnetMask: customSubnetMask ?? this.customSubnetMask,
    );
  }
}

/// Network discovery service for UDP-based server discovery and broadcasting.
/// 
/// This service provides both server and client functionality:
/// - Server mode: Broadcasts server information periodically and responds to discovery requests
/// - Client mode: Discovers available servers on the local network
/// 
/// Features:
/// - Automatic subnet detection and broadcasting
/// - Configurable discovery parameters
/// - Robust error handling and recovery
/// - Support for multiple network interfaces
/// - Network interface monitoring and logging
class NetworkDiscoveryService {
  static final NetworkDiscoveryService _instance = NetworkDiscoveryService._internal();
  factory NetworkDiscoveryService([DiscoveryConfig? config]) {
    if (config != null) {
      _instance._config = config;
    }
    return _instance;
  }
  NetworkDiscoveryService._internal();

  DiscoveryConfig _config = const DiscoveryConfig();
  
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  ServerInfo? _serverInfo;
  bool _isRunning = false;
  
  /// Current configuration for the discovery service
  DiscoveryConfig get config => _config;
  
  /// Whether the discovery service is currently running
  bool get isRunning => _isRunning;
  
  /// Currently broadcasted server info (null if not in server mode)
  ServerInfo? get serverInfo => _serverInfo;

  /// Updates the discovery service configuration.
  /// 
  /// Note: Configuration changes will take effect on the next service restart.
  void updateConfig(DiscoveryConfig newConfig) {
    _config = newConfig;
    _log('Discovery service configuration updated');
  }

  /// Starts the discovery service in server mode.
  /// 
  /// [serverInfo] - Information about the server to broadcast
  /// 
  /// Throws [SocketException] if unable to bind to the discovery port.
  /// Throws [StateError] if the service is already running.
  Future<void> startServer(ServerInfo serverInfo) async {
    if (_isRunning) {
      throw StateError('Discovery service is already running. Stop it first before starting again.');
    }

    _serverInfo = serverInfo;
    
    try {
      if (_config.logNetworkInterfaces) {
        await _logNetworkInterfaces();
      }
      
      // Bind to the discovery port
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _config.discoveryPort);
      _socket!.broadcastEnabled = true;
      
      _log('UDP discovery service started on port ${_config.discoveryPort}');
      _log('Server info: ${_serverInfo!.toJson()}');
      
      // Listen for discovery requests and other events
      _socket!.listen(
        _handleSocketEvent,
        onError: _handleSocketError,
        onDone: () => _log('UDP socket closed'),
        cancelOnError: false,
      );
      
      // Start periodic broadcasting
      _broadcastTimer = Timer.periodic(_config.broadcastInterval, (timer) {
        _broadcastServerInfo();
      });
      
      _isRunning = true;
      
      // Send initial broadcast
      _broadcastServerInfo();
      
    } catch (e) {
      _log('Error starting UDP discovery service: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Handles socket events (read, write, closed, error)
  void _handleSocketEvent(RawSocketEvent event) {
    switch (event) {
      case RawSocketEvent.read:
        _handleDiscoveryRequest();
        break;
      case RawSocketEvent.closed:
        _log('UDP socket closed');
        _isRunning = false;
        break;
      case RawSocketEvent.readClosed:
        _log('UDP socket read closed');
        break;
      case RawSocketEvent.write:
        // Write events don't need special handling for UDP
        break;
    }
  }

  /// Handles socket errors
  void _handleSocketError(dynamic error) {
    _log('UDP socket error: $error');
    // Don't stop the service for transient errors
  }

  /// Handles incoming discovery requests from clients
  void _handleDiscoveryRequest() {
    if (_socket == null || _serverInfo == null) return;
    
    final datagram = _socket!.receive();
    if (datagram == null) return;
    
    try {
      final messageString = utf8.decode(datagram.data);
      final message = jsonDecode(messageString) as Map<String, dynamic>;
      
      if (message['type'] == 'discovery_request') {
        _log('Received discovery request from ${datagram.address.address}:${datagram.port}');
        _sendDiscoveryResponse(datagram.address, datagram.port);
      }
    } catch (e) {
      // Ignore malformed UDP packets - this is expected on networks with other UDP traffic
      _log('Received malformed UDP packet from ${datagram.address.address}:${datagram.port}', isVerbose: true);
    }
  }

  /// Sends a discovery response to a specific client
  void _sendDiscoveryResponse(InternetAddress address, int port) {
    if (_socket == null || _serverInfo == null) return;
    
    try {
      final response = {
        'type': 'server_discovery_response',
        'serverInfo': _serverInfo!.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'responseToRequest': true,
      };
      
      final responseJson = jsonEncode(response);
      final data = utf8.encode(responseJson);
      
      final sent = _socket!.send(data, address, port);
      if (sent > 0) {
        _log('Sent discovery response to ${address.address}:$port', isVerbose: true);
      } else {
        _log('Failed to send discovery response to ${address.address}:$port');
      }
    } catch (e) {
      _log('Error sending discovery response to ${address.address}:$port: $e');
    }
  }

  /// Broadcasts server information to the network
  void _broadcastServerInfo() {
    if (_socket == null || _serverInfo == null) return;
    
    try {
      final message = {
        'type': 'server_discovery_broadcast',
        'serverInfo': _serverInfo!.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'broadcastMessage': true,
      };
      
      final data = utf8.encode(jsonEncode(message));
      
      // Broadcast to general broadcast address
      _sendBroadcastMessage(data, _config.broadcastAddress);
      
      // Also broadcast to specific network ranges
      _broadcastToNetworkRanges(data);
      
      _log('Server info broadcast sent', isVerbose: true);
      
    } catch (e) {
      _log('Error broadcasting server info: $e');
    }
  }

  /// Sends a broadcast message to a specific address
  void _sendBroadcastMessage(List<int> data, String address) {
    try {
      final broadcastAddr = InternetAddress(address);
      final sent = _socket!.send(data, broadcastAddr, _config.discoveryPort);
      if (sent == 0) {
        _log('Failed to send broadcast to $address');
      }
    } catch (e) {
      _log('Error sending broadcast to $address: $e');
    }
  }

  /// Broadcasts to detected network subnet ranges
  Future<void> _broadcastToNetworkRanges(List<int> data) async {
    try {
      final interfaces = await NetworkInterface.list();
      final sentAddresses = <String>{};
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback && 
              !address.isLinkLocal) {
            
            final subnet = _getSubnetBroadcast(address.address);
            if (subnet != null && !sentAddresses.contains(subnet)) {
              _sendBroadcastMessage(data, subnet);
              sentAddresses.add(subnet);
              _log('Broadcast sent to subnet: $subnet', isVerbose: true);
            }
          }
        }
      }
    } catch (e) {
      _log('Error broadcasting to network ranges: $e');
    }
  }

  /// Calculates the broadcast address for a given IP address
  String? _getSubnetBroadcast(String ipAddress) {
    final parts = ipAddress.split('.');
    if (parts.length != 4) return null;
    
    try {
      if (_config.customSubnetMask != null) {
        return _calculateBroadcastWithMask(ipAddress, _config.customSubnetMask!);
      }
      
      // Default to /24 subnet (255.255.255.0)
      return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    } catch (e) {
      _log('Error calculating subnet broadcast for $ipAddress: $e');
      return null;
    }
  }

  /// Calculates broadcast address using a custom subnet mask
  String? _calculateBroadcastWithMask(String ipAddress, String subnetMask) {
    try {
      final ipParts = ipAddress.split('.').map(int.parse).toList();
      final maskParts = subnetMask.split('.').map(int.parse).toList();
      
      if (ipParts.length != 4 || maskParts.length != 4) return null;
      
      final broadcastParts = <int>[];
      for (int i = 0; i < 4; i++) {
        broadcastParts.add(ipParts[i] | (~maskParts[i] & 0xFF));
      }
      
      return broadcastParts.join('.');
    } catch (e) {
      _log('Error calculating broadcast with custom mask: $e');
      return null;
    }
  }

  /// Gets the primary local IP address
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      // Prefer non-loopback, non-link-local addresses
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback && 
              !address.isLinkLocal) {
            return address.address;
          }
        }
      }
      
      // Fallback to any IPv4 address except loopback
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            return address.address;
          }
        }
      }
      
      return null;
    } catch (e) {
      _log('Error getting local IP address: $e');
      return null;
    }
  }

  /// Gets all local IP addresses
  Future<List<String>> getAllLocalIpAddresses() async {
    try {
      final addresses = <String>[];
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            addresses.add(address.address);
          }
        }
      }
      
      return addresses;
    } catch (e) {
      _log('Error getting all local IP addresses: $e');
      return [];
    }
  }

  /// Stops the discovery service
  Future<void> stop() async {
    _log('Stopping network discovery service...');
    await _cleanup();
    _log('Network discovery service stopped');
  }

  /// Cleans up resources
  Future<void> _cleanup() async {
    _isRunning = false;
    
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    
    try {
      _socket?.close();
    } catch (e) {
      _log('Error closing socket: $e');
    }
    _socket = null;
    
    _serverInfo = null;
  }

  /// Discovers servers on the local network (client mode)
  /// 
  /// [config] - Optional configuration to override default settings
  /// 
  /// Returns a list of discovered servers.
  static Future<List<ServerInfo>> discoverServers([DiscoveryConfig? config]) async {
    final discoveryConfig = config ?? const DiscoveryConfig();
    final servers = <String, ServerInfo>{}; // Use map to avoid duplicates by IP
    
    for (int attempt = 1; attempt <= discoveryConfig.maxDiscoveryAttempts; attempt++) {
      if (discoveryConfig.enableLogging) {
        print('Discovery attempt $attempt/${discoveryConfig.maxDiscoveryAttempts}');
      }
      
      try {
        final attemptServers = await _performDiscovery(discoveryConfig);
        
        // Add new servers to our collection
        for (final server in attemptServers) {
          servers[server.ipAddress] = server;
        }
        
        if (servers.isNotEmpty && attempt < discoveryConfig.maxDiscoveryAttempts) {
          // Give a brief pause between attempts if we found servers
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
      } catch (e) {
        if (discoveryConfig.enableLogging) {
          print('Discovery attempt $attempt failed: $e');
        }
        
        if (attempt == discoveryConfig.maxDiscoveryAttempts) {
          if (discoveryConfig.enableLogging) {
            print('All discovery attempts failed, returning ${servers.length} servers found in previous attempts');
          }
        }
      }
    }
    
    final result = servers.values.toList();
    if (discoveryConfig.enableLogging) {
      print('Discovery completed. Found ${result.length} servers: ${result.map((s) => s.ipAddress).join(', ')}');
    }
    
    return result;
  }

  /// Performs a single discovery attempt
  static Future<List<ServerInfo>> _performDiscovery(DiscoveryConfig config) async {
    final servers = <ServerInfo>[];
    final completer = Completer<List<ServerInfo>>();
    RawDatagramSocket? socket;
    StreamSubscription? subscription;
    
    try {
      // Bind to any available port
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      
      // Prepare discovery request
      final request = {
        'type': 'discovery_request',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final data = utf8.encode(jsonEncode(request));
      
      // Listen for responses
      subscription = socket.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket!.receive();
            if (datagram != null) {
              try {
                final message = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
                
                if ((message['type'] == 'server_discovery_response' || 
                     message['type'] == 'server_discovery_broadcast') && 
                    message['serverInfo'] != null) {
                  
                  final serverInfo = ServerInfo.fromJson(message['serverInfo'] as Map<String, dynamic>);
                  
                  // Avoid duplicates
                  if (!servers.any((s) => s.ipAddress == serverInfo.ipAddress)) {
                    servers.add(serverInfo);
                    if (config.enableLogging) {
                      print('Discovered server: ${serverInfo.name} at ${serverInfo.ipAddress}');
                    }
                  }
                }
              } catch (e) {
                // Ignore malformed messages
                if (config.enableLogging) {
                  print('Received malformed discovery response: $e');
                }
              }
            }
          }
        },
        onError: (error) {
          if (config.enableLogging) {
            print('Discovery socket error: $error');
          }
        },
        cancelOnError: false,
      );
      
      // Send discovery requests to multiple addresses
      final broadcastAddresses = [
        config.broadcastAddress,
        ...(await _getNetworkBroadcastAddresses(config)),
      ];
      
      for (final address in broadcastAddresses) {
        try {
          final sent = socket.send(data, InternetAddress(address), config.discoveryPort);
          if (config.enableLogging && sent > 0) {
            print('Sent discovery request to $address:${config.discoveryPort}');
          }
        } catch (e) {
          if (config.enableLogging) {
            print('Failed to send discovery request to $address: $e');
          }
        }
      }
      
      // Complete after timeout
      Timer(config.discoveryTimeout, () {
        if (!completer.isCompleted) {
          completer.complete(servers);
        }
      });
      
      return await completer.future;
      
    } catch (e) {
      if (config.enableLogging) {
        print('Error during server discovery: $e');
      }
      return servers; // Return any servers found before the error
    } finally {
      try {
        await subscription?.cancel();
        socket?.close();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  /// Gets broadcast addresses for all local network interfaces
  static Future<List<String>> _getNetworkBroadcastAddresses(DiscoveryConfig config) async {
    try {
      final addresses = <String>[];
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback && 
              !address.isLinkLocal) {
            
            final subnet = _calculateSubnetBroadcast(address.address, config.customSubnetMask);
            if (subnet != null && !addresses.contains(subnet)) {
              addresses.add(subnet);
            }
          }
        }
      }
      
      return addresses;
    } catch (e) {
      if (config.enableLogging) {
        print('Error getting network broadcast addresses: $e');
      }
      return [];
    }
  }

  /// Static helper method to calculate subnet broadcast address
  static String? _calculateSubnetBroadcast(String ipAddress, String? customSubnetMask) {
    final parts = ipAddress.split('.');
    if (parts.length != 4) return null;
    
    try {
      if (customSubnetMask != null) {
        final ipParts = ipAddress.split('.').map(int.parse).toList();
        final maskParts = customSubnetMask.split('.').map(int.parse).toList();
        
        if (ipParts.length != 4 || maskParts.length != 4) return null;
        
        final broadcastParts = <int>[];
        for (int i = 0; i < 4; i++) {
          broadcastParts.add(ipParts[i] | (~maskParts[i] & 0xFF));
        }
        
        return broadcastParts.join('.');
      }
      
      // Default to /24 subnet
      return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    } catch (e) {
      return null;
    }
  }

  /// Logs network interface information for debugging
  Future<void> _logNetworkInterfaces() async {
    try {
      _log('=== Network Interface Information ===');
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        _log('Interface: ${interface.name}');
        for (final address in interface.addresses) {
          _log('  Address: ${address.address} (${address.type.name})');
          _log('  Loopback: ${address.isLoopback}');
          _log('  Link Local: ${address.isLinkLocal}');
          _log('  Multicast: ${address.isMulticast}');
        }
      }
      _log('=====================================');
    } catch (e) {
      _log('Error logging network interfaces: $e');
    }
  }

  /// Internal logging method
  void _log(String message, {bool isVerbose = false}) {
    if (_config.enableLogging && (!isVerbose || _config.logNetworkInterfaces)) {
      print('[NetworkDiscoveryService] $message');
    }
  }

  /// Disposes of the singleton instance (for testing purposes)
  static void dispose() {
    _instance.stop();
  }
}