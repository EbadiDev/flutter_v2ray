import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'model/v2ray_status.dart' show V2RayStatus;
import 'package:flutter_v2ray/flutter_v2ray.dart';

import 'flutter_v2ray_platform_interface.dart';

/// An implementation of [FlutterV2rayPlatform] that uses method channels.
class MethodChannelFlutterV2ray extends FlutterV2rayPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_v2ray');
  final eventChannel = const EventChannel('flutter_v2ray/status');

  @override
  Future<void> initializeV2Ray({
    required void Function(V2RayStatus status) onStatusChanged,
    required String notificationIconResourceType,
    required String notificationIconResourceName,
  }) async {
    eventChannel.receiveBroadcastStream().distinct().cast().listen((event) {
      if (event != null) {
        onStatusChanged.call(V2RayStatus(
          duration: event[0],
          uploadSpeed: int.parse(event[1]),
          downloadSpeed: int.parse(event[2]),
          upload: int.parse(event[3]),
          download: int.parse(event[4]),
          state: event[5],
        ));
      }
    });
    await methodChannel.invokeMethod(
      'initializeV2Ray',
      {
        "notificationIconResourceType": notificationIconResourceType,
        "notificationIconResourceName": notificationIconResourceName,
      },
    );
  }

  @override
  Future<void> startV2Ray({
    required String remark,
    required String config,
    required String notificationDisconnectButtonName,
    required String notificationTitle,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool proxyOnly = false,
  }) async {
    await methodChannel.invokeMethod('startV2Ray', {
      "remark": remark,
      "config": config,
      "blocked_apps": blockedApps,
      "bypass_subnets": bypassSubnets,
      "proxy_only": proxyOnly,
      "notificationDisconnectButtonName": notificationDisconnectButtonName,
      "notificationTitle": notificationTitle,
    });
  }

  @override
  Future<void> stopV2Ray() async {
    await methodChannel.invokeMethod('stopV2Ray');
  }

  @override
  Future<int> getServerDelay({
    required String config,
    required String url,
    bool isCancelled = false,
  }) async {
    if (isCancelled) {
      throw CancellationException();
    }

    final result = await methodChannel.invokeMethod('getServerDelay', {
      "config": config,
      "url": url,
    });

    if (isCancelled) {
      throw CancellationException();
    }

    return result;
  }

  @override
  Future<dynamic> getAllServerDelay({required List<String> configs}) {
    final res = jsonEncode(configs);
    return methodChannel.invokeMethod('getAllServerDelay', {
      "configs": res,
    });
  }

  @override
  Future<Map<String, int>> getAllServerPing({
    required List<String> configs,
    String url = 'http://cp.cloudflare.com',
  }) async {
    print('Starting ping test for ${configs.length} servers');
    final res = jsonEncode(configs);

    print('Sending request to native code...');
    final result = await methodChannel.invokeMethod('getAllServerPing', {
      "configs": res,
      "url": url,
    });

    print('Received response from native code: $result');
    final Map<String, dynamic> decoded = jsonDecode(result.toString());
    print('Decoded JSON results: $decoded');

    final Map<String, int> converted =
        decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
    print('Final converted results: $converted');

    return converted;
  }

  @override
  Future<int> getConnectedServerDelay(String url) async {
    return await methodChannel
        .invokeMethod('getConnectedServerDelay', {"url": url});
  }

  @override
  Future<String> getV2rayStatus() async {
    final String? val = await methodChannel.invokeMethod("getV2rayStatus");

    return (val?.split("_"))?.elementAtOrNull(1) ?? "ERROR";
  }

  @override
  Future<bool> requestPermission() async {
    return (await methodChannel.invokeMethod('requestPermission')) ?? false;
  }

  @override
  Future<String> getCoreVersion() async {
    return await methodChannel.invokeMethod('getCoreVersion');
  }
}
