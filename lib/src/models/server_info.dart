import 'package:json_annotation/json_annotation.dart';

part 'server_info.g.dart';

/// Generic server information model for network discovery and connection.
/// 
/// This model represents server details that can be broadcast over UDP
/// for automatic discovery by client applications.
@JsonSerializable()
class ServerInfo {
  /// Display name of the server
  final String name;
  
  /// Version of the server application
  final String version;
  
  /// IP address where the server is running
  final String ipAddress;
  
  /// Port number for HTTP REST API
  final int httpPort;
  
  /// Port number for WebSocket connections
  final int webSocketPort;
  
  /// Server start time for connection freshness validation
  final DateTime startTime;
  
  /// Key-value map of server capabilities and features
  final Map<String, dynamic> capabilities;

  ServerInfo({
    required this.name,
    required this.version,
    required this.ipAddress,
    required this.httpPort,
    required this.webSocketPort,
    required this.startTime,
    required this.capabilities,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ServerInfoToJson(this);

  /// Creates a ServerInfo instance with configurable parameters.
  /// 
  /// [name] - Display name for the server
  /// [version] - Version string for the server
  /// [ipAddress] - IP address where the server is running
  /// [httpPort] - Port for HTTP REST API (default: 8080)
  /// [webSocketPort] - Port for WebSocket connections (default: 8081)
  /// [capabilities] - Map of server capabilities (optional)
  factory ServerInfo.create({
    required String name,
    required String version,
    required String ipAddress,
    int httpPort = 8080,
    int webSocketPort = 8081,
    Map<String, dynamic>? capabilities,
  }) {
    return ServerInfo(
      name: name,
      version: version,
      ipAddress: ipAddress,
      httpPort: httpPort,
      webSocketPort: webSocketPort,
      startTime: DateTime.now(),
      capabilities: capabilities ?? <String, dynamic>{},
    );
  }

  /// Creates a copy of this ServerInfo with optionally updated fields.
  ServerInfo copyWith({
    String? name,
    String? version,
    String? ipAddress,
    int? httpPort,
    int? webSocketPort,
    DateTime? startTime,
    Map<String, dynamic>? capabilities,
  }) {
    return ServerInfo(
      name: name ?? this.name,
      version: version ?? this.version,
      ipAddress: ipAddress ?? this.ipAddress,
      httpPort: httpPort ?? this.httpPort,
      webSocketPort: webSocketPort ?? this.webSocketPort,
      startTime: startTime ?? this.startTime,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  /// Checks if the server has a specific capability.
  bool hasCapability(String capability) {
    return capabilities.containsKey(capability) && 
           capabilities[capability] == true;
  }

  /// Gets the base HTTP URL for this server.
  String get httpUrl => 'http://$ipAddress:$httpPort';

  /// Gets the WebSocket URL for this server.
  String get webSocketUrl => 'ws://$ipAddress:$webSocketPort';

  @override
  String toString() {
    return 'ServerInfo(name: $name, version: $version, ipAddress: $ipAddress, '
           'httpPort: $httpPort, webSocketPort: $webSocketPort, '
           'startTime: $startTime, capabilities: $capabilities)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerInfo &&
        other.name == name &&
        other.version == version &&
        other.ipAddress == ipAddress &&
        other.httpPort == httpPort &&
        other.webSocketPort == webSocketPort &&
        other.startTime == startTime;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        version.hashCode ^
        ipAddress.hashCode ^
        httpPort.hashCode ^
        webSocketPort.hashCode ^
        startTime.hashCode;
  }
}