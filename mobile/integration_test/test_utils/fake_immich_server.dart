import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A dummy localhost server that implements only the endpoints that remote-sync touches.
class FakeImmichServer {
  FakeImmichServer._(this._server, this.version);

  final HttpServer _server;
  final (int, int, int) version;

  final Completer<SyncStream> _streamOpened = Completer<SyncStream>();
  final Completer<void> _assetUploadReceived = Completer<void>();

  int ackRequests = 0;
  int assetUploadRequests = 0;
  String? lastAssetUploadBody;
  String? lastAssetUploadContentType;

  String get endpoint => 'http://${_server.address.host}:${_server.port}/api';

  /// Resolves when the sync isolate opens `POST /sync/stream`.
  Future<SyncStream> get streamOpened => _streamOpened.future;

  /// Resolves when the fake server receives `POST /assets`.
  Future<void> get assetUploadReceived => _assetUploadReceived.future;

  static Future<FakeImmichServer> start({(int, int, int) version = (3, 0, 0)}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeImmichServer._(server, version);
    fake._listen();
    return fake;
  }

  void _listen() {
    // A connection torn down mid-write during teardown is expected
    _server.listen((request) => unawaited(_route(request).catchError((_) {})));
  }

  Future<void> _route(HttpRequest request) async {
    final method = request.method;
    final path = request.uri.path;

    if (method == 'GET' && path == '/api/server/ping') {
      return _respondJson(request, {'res': 'pong'});
    }
    if (method == 'GET' && path == '/api/server/version') {
      final (major, minor, patch) = version;
      return _respondJson(request, {'major': major, 'minor': minor, 'patch': patch});
    }
    if (path == '/api/sync/ack') {
      if (method != 'DELETE') {
        ackRequests++;
      }
      return _respondEmpty(request);
    }
    if (method == 'POST' && path == '/api/sync/stream') {
      return _openSyncStream(request);
    }
    if (method == 'POST' && path == '/api/assets') {
      return _handleAssetUpload(request);
    }
    return _respondEmpty(request, status: HttpStatus.notFound);
  }

  Future<void> _openSyncStream(HttpRequest request) async {
    await request.drain<void>();
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('application', 'jsonlines+json')
      ..contentLength =
          -1 // chunked: stays open to stream incrementally
      ..bufferOutput = false;
    // Flush headers so the client's send() resolves and enters its read loop.
    await request.response.flush();
    if (!_streamOpened.isCompleted) {
      _streamOpened.complete(SyncStream._(request.response));
    }
  }

  Future<void> _respondJson(HttpRequest request, Object body) async {
    await request.drain<void>();
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> _handleAssetUpload(HttpRequest request) async {
    assetUploadRequests++;
    lastAssetUploadContentType = request.headers.contentType?.toString();

    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
    }
    lastAssetUploadBody = utf8.decode(bytes, allowMalformed: true);

    if (!_assetUploadReceived.isCompleted) {
      _assetUploadReceived.complete();
    }

    request.response
      ..statusCode = HttpStatus.created
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'id': 'fake-upload-$assetUploadRequests'}));
    await request.response.close();
  }

  Future<void> _respondEmpty(HttpRequest request, {int status = HttpStatus.ok}) async {
    await request.drain<void>();
    request.response.statusCode = status;
    await request.response.close();
  }

  Future<void> close() async {
    if (_streamOpened.isCompleted) {
      await (await _streamOpened.future).close();
    }
    await _server.close(force: true);
  }
}

/// Handle to the open `/sync/stream` response: push jsonlines events, then end.
class SyncStream {
  SyncStream._(this._response);

  final HttpResponse _response;
  bool _closed = false;

  /// [data] should be a Sync*V1 DTO's `toJson()` so the parser's `fromJson` round-trips it.
  void send({required String type, required Object data, required String ack}) {
    if (_closed) {
      return;
    }
    _response.write('${jsonEncode({'type': type, 'data': data, 'ack': ack})}\n');
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _response.close();
  }
}
