import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_local_server/restaurant_local_server.dart';

void main() {
  group('Restaurant Local Server', () {
    test('ServerInfo creation', () {
      final serverInfo = ServerInfo.create(
        name: 'Test Server',
        version: '1.0.0',
        ipAddress: '192.168.1.100',
        httpPort: 8080,
        webSocketPort: 8081,
      );
      
      expect(serverInfo.name, 'Test Server');
      expect(serverInfo.version, '1.0.0');
      expect(serverInfo.ipAddress, '192.168.1.100');
      expect(serverInfo.httpPort, 8080);
      expect(serverInfo.webSocketPort, 8081);
      expect(serverInfo.httpUrl, 'http://192.168.1.100:8080');
      expect(serverInfo.webSocketUrl, 'ws://192.168.1.100:8081');
    });

    test('WebSocketMessage creation', () {
      final message = WebSocketMessage.heartbeat();
      
      expect(message.type, WebSocketMessageType.heartbeat);
      expect(message.data['ping'], 'pong');
      expect(message.timestamp, isNotNull);
    });

    test('WebSocketMessage entity creation', () {
      final entityData = {'id': '123', 'name': 'Test Entity'};
      final message = WebSocketMessage.entityCreated(
        entityType: 'testEntity',
        entityData: entityData,
        clientId: 'client_1',
      );
      
      expect(message.type, WebSocketMessageType.entityCreated);
      expect(message.clientId, 'client_1');
      expect(message.data['entityType'], 'testEntity');
      expect(message.data['entity'], entityData);
      expect(message.data['action'], 'created');
    });
  });
}
