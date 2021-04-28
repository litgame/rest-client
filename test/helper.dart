import 'dart:async';
import 'dart:io';

import 'package:litgame_client/client.dart';
import 'package:litgame_server/service/service.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<HttpServer> createServer() async {
  final service = LitGameRestService();
  await service.init;
  return shelf_io.serve(service.handler, 'localhost', 8080);
}

GameClient createClient() => GameClient('http://localhost:8080');
