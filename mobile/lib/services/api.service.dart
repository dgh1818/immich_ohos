import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/network.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/utils/debug_print.dart';
import 'package:immich_mobile/utils/url_helper.dart';
import 'package:logging/logging.dart';
import 'package:openapi/api.dart';

import 'package:flutter/foundation.dart';

class ApiService {
  final ApiClient _apiClient = ApiClient(basePath: '');

  late UsersApi usersApi;
  late AuthenticationApi authenticationApi;
  late AuthenticationApi oAuthApi;
  late AlbumsApi albumsApi;
  late AssetsApi assetsApi;
  late SearchApi searchApi;
  late ServerApi serverInfoApi;
  late MapApi mapApi;
  late PartnersApi partnersApi;
  late PeopleApi peopleApi;
  late SharedLinksApi sharedLinksApi;
  late SyncApi syncApi;
  late SystemConfigApi systemConfigApi;
  late ActivitiesApi activitiesApi;
  late DownloadApi downloadApi;
  late TrashApi trashApi;
  late StacksApi stacksApi;
  late ViewsApi viewApi;
  late MemoriesApi memoriesApi;
  late SessionsApi sessionsApi;
  late TagsApi tagsApi;

  ApiService() {
    // The below line ensures that the api clients are initialized when the service is instantiated
    // This is required to avoid late initialization errors when the clients are access before the endpoint is resolved
    setEndpoint('');
    final endpoint = Store.tryGet(StoreKey.serverEndpoint);
    if (endpoint != null && endpoint.isNotEmpty) {
      setEndpoint(endpoint);
    }
  }
  final _log = Logger("ApiService");

  Future<void> updateHeaders() async {
    await NetworkRepository.setHeaders(
      getRequestHeaders(),
      getServerUrls(),
      token: Store.tryGet(StoreKey.accessToken),
    );
    _apiClient.client = NetworkRepository.client;
  }

  setEndpoint(String endpoint) {
    _apiClient.basePath = endpoint;
    _apiClient.client = NetworkRepository.client;
    usersApi = UsersApi(_apiClient);
    authenticationApi = AuthenticationApi(_apiClient);
    oAuthApi = AuthenticationApi(_apiClient);
    albumsApi = AlbumsApi(_apiClient);
    assetsApi = AssetsApi(_apiClient);
    serverInfoApi = ServerApi(_apiClient);
    searchApi = SearchApi(_apiClient);
    mapApi = MapApi(_apiClient);
    partnersApi = PartnersApi(_apiClient);
    peopleApi = PeopleApi(_apiClient);
    sharedLinksApi = SharedLinksApi(_apiClient);
    syncApi = SyncApi(_apiClient);
    systemConfigApi = SystemConfigApi(_apiClient);
    activitiesApi = ActivitiesApi(_apiClient);
    downloadApi = DownloadApi(_apiClient);
    trashApi = TrashApi(_apiClient);
    stacksApi = StacksApi(_apiClient);
    viewApi = ViewsApi(_apiClient);
    memoriesApi = MemoriesApi(_apiClient);
    sessionsApi = SessionsApi(_apiClient);
    tagsApi = TagsApi(_apiClient);
  }

  Future<String> resolveAndSetEndpoint(String serverUrl) async {
    final endpoint = await resolveEndpoint(serverUrl);
    setEndpoint(endpoint);

    // Save in local database for next startup
    await Store.put(StoreKey.serverEndpoint, endpoint);
    return endpoint;
  }

  /// Takes a server URL and attempts to resolve the API endpoint.
  ///
  /// Input: [schema://]host[:port][/path]
  ///  schema - optional (default: https)
  ///  host   - required
  ///  port   - optional (default: based on schema)
  ///  path   - optional
  Future<String> resolveEndpoint(String serverUrl) async {
    String url = normalizeServerUrl(serverUrl);

    // Check for /.well-known/immich
    final wellKnownEndpoint = await _getWellKnownEndpoint(url);
    if (wellKnownEndpoint.isNotEmpty) {
      url = normalizeServerUrl(wellKnownEndpoint);
    }

    if (!await _isEndpointAvailable(url)) {
      throw ApiException(503, "Server is not reachable");
    }

    // Otherwise, assume the URL provided is the api endpoint
    return url;
  }

  Future<bool> _isEndpointAvailable(String serverUrl) async {
    if (!serverUrl.endsWith('/api')) {
      serverUrl += '/api';
    }

    try {
      await setEndpoint(serverUrl);
      await serverInfoApi.pingServer().timeout(const Duration(seconds: 5));
    } on TimeoutException catch (_) {
      return false;
    } on SocketException catch (_) {
      return false;
    } catch (error, stackTrace) {
      _log.severe("Error while checking server availability", error, stackTrace);
      return false;
    }
    return true;
  }

  Future<String> _getWellKnownEndpoint(String baseUrl) async {
    try {
      final res = await NetworkRepository.client
          .get(Uri.parse("$baseUrl/.well-known/immich"))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final endpoint = data['api']['endpoint'].toString();

        if (endpoint.startsWith('/')) {
          // Full URL is relative to base
          return "$baseUrl$endpoint";
        }
        return endpoint;
      }
    } catch (e) {
      dPrint(() => "Could not locate /.well-known/immich at $baseUrl");
    }

    return "";
  }

  Future<void> setDeviceInfoHeader() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      authenticationApi.apiClient.addDefaultHeader('deviceModel', iosInfo.utsname.machine);
      authenticationApi.apiClient.addDefaultHeader('deviceType', 'iOS');
    } else if (defaultTargetPlatform == TargetPlatform.ohos) {
      //final ohosInfo = await deviceInfoPlugin.ohosInfo;
      authenticationApi.apiClient.addDefaultHeader('deviceModel', "HMOS device");
      authenticationApi.apiClient.addDefaultHeader('deviceType', 'OHOS');
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      authenticationApi.apiClient.addDefaultHeader('deviceModel', androidInfo.model);
      authenticationApi.apiClient.addDefaultHeader('deviceType', 'Android');
    } else {
      authenticationApi.apiClient.addDefaultHeader('deviceModel', 'Unknown');
      authenticationApi.apiClient.addDefaultHeader('deviceType', 'Unknown');
    }
  }

  static List<String> getServerUrls() {
    final urls = <String>[];
    final serverEndpoint = Store.tryGet(StoreKey.serverEndpoint);
    if (serverEndpoint != null && serverEndpoint.isNotEmpty) {
      urls.add(serverEndpoint);
    }
    final network = SettingsRepository.instance.appConfig.network;
    final localEndpoint = network.localEndpoint;
    if (localEndpoint != null && localEndpoint.isNotEmpty) {
      urls.add(localEndpoint);
    }
    for (final url in network.externalEndpointList) {
      if (url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  static Map<String, String> getRequestHeaders() {
    return SettingsRepository.instance.appConfig.network.customHeaders;
  }

  static Map<String, String> getAuthenticatedRequestHeaders(String requestUrl) {
    final headers = <String, String>{...getRequestHeaders()};
    final cookie = _buildAuthCookieForRequest(requestUrl);
    if (cookie != null && cookie.isNotEmpty) {
      final existingCookie = headers['Cookie'] ?? headers['cookie'];
      headers.remove('cookie');
      headers['Cookie'] = existingCookie != null && existingCookie.isNotEmpty ? '$existingCookie; $cookie' : cookie;
    }

    if (!headers.containsKey('Authorization') && !headers.containsKey('authorization')) {
      final basicAuth = _buildBasicAuthorization(requestUrl);
      if (basicAuth != null && basicAuth.isNotEmpty) {
        headers['Authorization'] = basicAuth;
      } else {
        final accessToken = Store.tryGet(StoreKey.accessToken);
        if (accessToken != null && accessToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $accessToken';
        }
      }
    }

    return headers;
  }

  static String? _buildAuthCookieForRequest(String requestUrl) {
    final accessToken = Store.tryGet(StoreKey.accessToken);
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final requestHost = _getHost(requestUrl);
    if (requestHost == null || requestHost.isEmpty) {
      return null;
    }

    final shouldAttachCookie = getServerUrls().any((url) => _getHost(url) == requestHost);
    if (!shouldAttachCookie) {
      return null;
    }

    return 'immich_access_token=$accessToken; immich_is_authenticated=true; immich_auth_type=password';
  }

  static String? _buildBasicAuthorization(String requestUrl) {
    try {
      final uri = Uri.parse(requestUrl);
      if (uri.userInfo.isEmpty) {
        return null;
      }
      return 'Basic ${base64Encode(utf8.encode(uri.userInfo))}';
    } catch (_) {
      return null;
    }
  }

  static String? _getHost(String rawUrl) {
    try {
      return Uri.parse(rawUrl).host;
    } catch (_) {
      return null;
    }
  }

  ApiClient get apiClient => _apiClient;
}
