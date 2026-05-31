import 'dart:io' as io;
import 'dart:ffi';
import 'dart:io';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/utils/user_agent.dart';
import 'package:ok_http/ok_http.dart';
import 'package:ohos_http/ohos_http.dart';
import 'package:web_socket/io_web_socket.dart' as io_ws;
import 'package:web_socket/web_socket.dart';

class NetworkRepository {
  static const String _ohosRemoteValidationHeader = 'x-ohos-http-remote-validation';
  static const String _ohosRemoteValidationSkip = 'skip';

  static http.Client? _client;
  static Pointer<Void>? _clientPointer;
  static bool? _allowSelfSignedSsl;
  static HttpOverrides? _previousHttpOverrides;

  static Future<void> init() async {
    final clientPointer = Pointer<Void>.fromAddress(await networkApi.getClientPointer());
    final allowSelfSignedSsl = Store.get(StoreKey.selfSignedCert, false);
    _configureOhosDartIoSsl(allowSelfSignedSsl);

    if (clientPointer == _clientPointer && _client != null && allowSelfSignedSsl == _allowSelfSignedSsl) {
      return;
    }
    _clientPointer = clientPointer;
    _allowSelfSignedSsl = allowSelfSignedSsl;
    _client?.close();
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      _client = OhosHttpClient(
        connectTimeout: const Duration(seconds: 30),
        readTimeout: const Duration(seconds: 60),
        allowBadCertificates: allowSelfSignedSsl,
      );
    } else if (Platform.isIOS) {
      final session = URLSession.fromRawPointer(clientPointer.cast());
      _client = CupertinoClient.fromSharedSession(session);
    } else {
      _client = OkHttpClient.fromJniGlobalRef(
        clientPointer,
        configuration: const OkHttpClientConfiguration(
          connectTimeout: Duration(seconds: 30),
          readTimeout: Duration(seconds: 60),
          writeTimeout: Duration(seconds: 60),
        ),
      );
    }
  }

  static Future<void> setHeaders(Map<String, String> headers, List<String> serverUrls, {String? token}) async {
    final transportHeaders = _withOhosTransportHeaders(headers);
    await networkApi.setRequestHeaders(transportHeaders, serverUrls, token);
    if (Platform.isIOS) {
      await init();
    }
  }

  // ignore: avoid-unused-parameters
  static Future<WebSocket> createWebSocket(Uri uri, {Map<String, String>? headers, Iterable<String>? protocols}) async {
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      final requestHeaders = Map<String, String>.from(headers ?? const <String, String>{});
      if (!requestHeaders.containsKey('User-Agent') && !requestHeaders.containsKey('user-agent')) {
        requestHeaders['User-Agent'] = await getUserAgentString();
      }
      final socket = await io.WebSocket.connect(uri.toString(), protocols: protocols, headers: requestHeaders);
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

  static Map<String, String> _withOhosTransportHeaders(Map<String, String> headers) {
    final result = Map<String, String>.from(headers);
    if (defaultTargetPlatform == TargetPlatform.ohos && Store.get(StoreKey.selfSignedCert, false)) {
      result[_ohosRemoteValidationHeader] = _ohosRemoteValidationSkip;
    }
    return result;
  }

  static void _configureOhosDartIoSsl(bool allowSelfSignedSsl) {
    if (defaultTargetPlatform != TargetPlatform.ohos) {
      return;
    }

    final current = HttpOverrides.current;
    if (allowSelfSignedSsl) {
      if (current is _OhosSelfSignedHttpOverrides) {
        return;
      }
      _previousHttpOverrides = current;
      HttpOverrides.global = _OhosSelfSignedHttpOverrides(current);
      return;
    }

    if (current is _OhosSelfSignedHttpOverrides) {
      HttpOverrides.global = _previousHttpOverrides;
      _previousHttpOverrides = null;
    }
  }
}

class _OhosSelfSignedHttpOverrides extends HttpOverrides {
  _OhosSelfSignedHttpOverrides(this.previous);

  final HttpOverrides? previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = previous?.createHttpClient(context) ?? super.createHttpClient(context);
    client.badCertificateCallback = (_, _, _) => true;
    return client;
  }
}
