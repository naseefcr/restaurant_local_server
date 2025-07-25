# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2025-07-25

### Fixed
- Fixed all example code API mismatches and analysis errors
- Updated LocalServerConfig constructor calls to use correct nested config objects
- Fixed ServerInfo property access (ipAddress instead of address)
- Corrected event handler signatures for LocalServerEventHandlers
- Updated broadcastSystemMessage to use named parameters
- Fixed HttpServer reference to LocalHttpServer in examples
- Removed unused variables and fixed parameter counts
- All example code now compiles without analysis errors

## [1.0.1] - 2025-07-24

### Fixed
- Updated repository URL to point to standalone package repository for proper pub.dev verification
- Fixed repository URL validation issues for improved pub.dev scoring

## [1.0.0] - 2025-07-22

### Added

#### Core Features
- **LocalServerManager**: Comprehensive server orchestration with lifecycle management
- **NetworkDiscoveryService**: UDP-based automatic server discovery across local networks
- **WebSocketServer**: Multi-client WebSocket server with heartbeat monitoring
- **LocalHttpServer**: Shelf-based HTTP server with CRUD operation support

#### Models
- **ServerInfo**: Server metadata and connection information with JSON serialization
- **WebSocketMessage**: Standardized message format for real-time communication

#### Advanced Features
- **Health Monitoring**: Automatic health checks with configurable intervals
- **Auto Recovery**: Automatic service restart on failures with configurable retry limits
- **Event System**: Comprehensive callback system for server and client events
- **Configuration Management**: Extensive configuration options for all services
- **Statistics**: Real-time server and client statistics with custom metrics support

### Dependencies

#### Production Dependencies
- `shelf`: ^1.4.0 - HTTP server framework
- `shelf_router`: ^1.1.4 - HTTP routing
- `shelf_web_socket`: ^2.0.0 - WebSocket integration
- `shelf_cors_headers`: ^0.1.5 - CORS support
- `web_socket_channel`: ^2.4.0 - WebSocket communication
- `http`: ^1.1.0 - HTTP client functionality
- `json_annotation`: ^4.8.1 - JSON serialization support

### Platform Support
- **Flutter**: >=3.10.0
- **Dart**: >=3.7.2
- **Platforms**: iOS, Android, macOS, Windows, Linux, Web
