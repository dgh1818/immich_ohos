import 'dart:io' as io;
import 'dart:ffi';
import 'dart:io';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:ok_http/ok_http.dart';
import 'package:ohos_http/ohos_http.dart';
import 'package:web_socket/io_web_socket.dart' as io_ws;
import 'package:web_socket/web_socket.dart';

class NetworkRepository {
  static http.Client? _client;
  static Pointer<Void>? _clientPointer;

  static Future<void> init() async {
    final clientPointer = Pointer<Void>.fromAddress(await networkApi.getClientPointer());
    if (clientPointer == _clientPointer && _client != null) {
      return;
    }
    _clientPointer = clientPointer;
    _client?.close();
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      _client = OhosHttpClient();
    } else if (Platform.isIOS) {
      final session = URLSession.fromRawPointer(clientPointer.cast());
      _client = CupertinoClient.fromSharedSession(session);
    } else {
      _client = OkHttpClient.fromJniGlobalRef(clientPointer);
    }
  }

  static Future<void> setHeaders(Map<String, String> headers, List<String> serverUrls, {String? token}) async {
    await networkApi.setRequestHeaders(headers, serverUrls, token);
    if (Platform.isIOS) {
      await init();
    }
  }

  // ignore: avoid-unused-parameters
  static Future<WebSocket> createWebSocket(Uri uri, {Map<String, String>? headers, Iterable<String>? protocols}) async {
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      final socket = await io.WebSocket.connect(uri.toString(), protocols: protocols, headers: headers);
      return io_ws.IOWebSocket.fromWebSocket(socket);
    }

    if (Platform.isIOS) {
      final session = URLSession.fromRawPointer(_clientPointer!.cast());
      return CupertinoWebSocket.connectWithSession(session, uri, protocols: protocols);
    } else {
      return OkHttpWebSocket.connectFromJniGlobalRef(_clientPointer!, uri, protocols: protocols);
    }
  }

  const NetworkRepository();

  /// Returns a shared HTTP client that uses native SSL configuration.
  ///
  /// On iOS: Uses SharedURLSessionManager's URLSession.
  /// On Android: Uses SharedHttpClientManager's OkHttpClient.
  ///
  /// Must call [init] before using this method.
  static http.Client get client => _client!;
}
