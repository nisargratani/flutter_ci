import 'dart:convert';
import 'dart:io';

import 'package:flutter_ci/flutter_ci.dart';
import 'package:test/test.dart';

/// A local server that records JSON webhook bodies. It also accepts
/// proxied requests, so any host can be routed to it.
class _WebhookServer {
  late HttpServer _server;
  final requests = <({Uri uri, Map<String, dynamic> body})>[];
  int status = 200;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final body = await utf8.decodeStream(request);
      requests.add((
        uri: request.requestedUri,
        body: jsonDecode(body) as Map<String, dynamic>,
      ));
      request.response.statusCode = status;
      await request.response.close();
    });
  }

  int get port => _server.port;
  String url(String path) => 'http://127.0.0.1:$port$path';
  Future<void> close() => _server.close(force: true);
}

class _ProxyOverrides extends HttpOverrides {
  _ProxyOverrides(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = (_) => 'PROXY 127.0.0.1:$port';
}

void main() {
  final service = DistributionService();
  late _WebhookServer server;

  setUp(() async {
    server = _WebhookServer();
    await server.start();
  });
  tearDown(() => server.close());

  group('sendWebhook', () {
    test('posts valid Slack JSON even with quotes, newlines and emoji',
        () async {
      const message = 'Release "1.0" is ready!\n\n- fix: user\'s bug 🐛';
      final ok =
          await service.sendWebhook(url: server.url('/hook'), message: message);

      expect(ok, isTrue);
      expect(server.requests.single.body, {'text': message});
    });

    test('uses the content field for Discord and truncates long messages',
        () async {
      final ok = await HttpOverrides.runZoned(
          () => service.sendWebhook(
              url: 'http://discord.com/api/webhooks/1/token',
              message: 'x' * 2500),
          createHttpClient: _ProxyOverrides(server.port).createHttpClient);

      expect(ok, isTrue);
      final request = server.requests.single;
      expect(request.uri.host, 'discord.com');
      expect(request.body.keys, ['content']);
      expect((request.body['content'] as String).length, 2000);
    });

    test('uses the text field for Discord Slack-compatible URLs', () async {
      await HttpOverrides.runZoned(
          () => service.sendWebhook(
              url: 'http://discord.com/api/webhooks/1/token/slack',
              message: 'hi'),
          createHttpClient: _ProxyOverrides(server.port).createHttpClient);
      expect(server.requests.single.body, {'text': 'hi'});
    });

    test('returns false for an HTTP error status', () async {
      server.status = 404;
      expect(await service.sendWebhook(url: server.url('/x'), message: 'm'),
          isFalse);
    });

    test('returns false when the endpoint is unreachable', () async {
      final port = server.port;
      await server.close();
      expect(
          await service.sendWebhook(
              url: 'http://127.0.0.1:$port/x', message: 'm'),
          isFalse);
    });

    test('returns false for an invalid URL', () async {
      expect(
          await service.sendWebhook(url: 'not a url', message: 'm'), isFalse);
      expect(await service.sendWebhook(url: 'ftp://host/x', message: 'm'),
          isFalse);
    });
  });

  group('uploads', () {
    test('fail without running anything when the artifact is missing',
        () async {
      expect(
          await service.uploadToFirebase(
              artifactPath: 'missing.apk', appId: 'id'),
          isFalse);
      expect(
          await service.uploadToGoogleDrive(
              artifactPath: 'missing.apk', folderId: 'f'),
          isFalse);
      expect(
          await service.uploadToPlayStore(
              artifactPath: 'missing.aab',
              jsonKeyPath: 'k.json',
              packageName: 'com.example'),
          isFalse);
    });

    test('App Store upload requires credentials', () async {
      expect(
          await service.uploadToAppStore(
              artifactPath: 'app.ipa', username: '', password: ''),
          isFalse);
    });
  });
}
