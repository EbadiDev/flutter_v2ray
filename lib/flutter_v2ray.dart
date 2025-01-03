import 'dart:convert';
import 'dart:io';

import 'package:flutter_v2ray/url/shadowsocks.dart';
import 'package:flutter_v2ray/url/socks.dart';
import 'package:flutter_v2ray/url/trojan.dart';
import 'package:flutter_v2ray/url/url.dart';
import 'package:flutter_v2ray/url/vless.dart';
import 'package:flutter_v2ray/url/vmess.dart';

import 'flutter_v2ray_platform_interface.dart';
import 'model/v2ray_status.dart';

export 'model/v2ray_status.dart';
export 'url/url.dart';

class FlutterV2ray {
  FlutterV2ray({required this.onStatusChanged});

  /// This method is called when V2Ray status has changed.
  final void Function(V2RayStatus status) onStatusChanged;

  /// Request VPN service permission specifically for Android.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await FlutterV2rayPlatform.instance.requestPermission();
    }
    return true;
  }

  /// You must initialize V2Ray before using it.
  Future<void> initializeV2Ray({
    String notificationIconResourceType = "mipmap",
    String notificationIconResourceName = "ic_launcher",
  }) async {
    await FlutterV2rayPlatform.instance.initializeV2Ray(
      onStatusChanged: onStatusChanged,
      notificationIconResourceType: notificationIconResourceType,
      notificationIconResourceName: notificationIconResourceName,
    );
  }

  /// Start V2Ray service.
  ///
  /// config:
  ///
  ///   V2Ray Config (json)
  ///
  /// blockedApps:
  ///
  ///   Apps that won't go through the VPN tunnel.
  ///
  ///   Contains a list of package names.
  ///
  ///   specifically for Android.
  ///
  /// bypassSubnets:
  ///
  ///     [Default = 0.0.0.0/0]
  ///
  ///     Add at least one route if you want the system to send traffic through the VPN interface.
  ///
  ///     Routes filter by destination addresses.
  ///
  ///     To accept all traffic, set an open route such as 0.0.0.0/0 or ::/0.
  ///
  /// proxyOnly:
  ///
  ///   If it is true, only the v2ray proxy will be executed,
  ///
  ///   and the VPN tunnel will not be executed.
  Future<void> startV2Ray({
    required String remark,
    required String config,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool proxyOnly = false,
    String notificationDisconnectButtonName = "DISCONNECT",
    String? notificationTitle,
  }) async {
    try {
      if (jsonDecode(config) == null) {
        throw ArgumentError('The provided string is not valid JSON');
      }
    } catch (_) {
      throw ArgumentError('The provided string is not valid JSON');
    }

    await FlutterV2rayPlatform.instance.startV2Ray(
      remark: remark,
      config: config,
      blockedApps: blockedApps,
      proxyOnly: proxyOnly,
      bypassSubnets: bypassSubnets,
      notificationDisconnectButtonName: notificationDisconnectButtonName,
      notificationTitle: notificationTitle ?? remark,
    );
  }

  Future<dynamic> getAllServerDelay({required List<String> configs}) async {
    try {
      List<String> modifiedConfigs = [];

      for (String config in configs) {
        Map<String, dynamic> configMap = jsonDecode(config);

        // Simplify DNS configuration
        if (configMap.containsKey('dns')) {
          configMap['dns'] = {
            "servers": ["8.8.8.8", "8.8.4.4"],
            "queryStrategy": "UseIPv4"
          };
        }

        // Simplify routing configuration
        if (configMap.containsKey('routing')) {
          configMap['routing'] = {
            "domainStrategy": "AsIs",
            "rules": [
              {
                "type": "field",
                "outboundTag": configMap['remarks'] ?? "proxy",
                "port": "0-65535",
                "enabled": true
              }
            ]
          };
        }

        modifiedConfigs.add(jsonEncode(configMap));
      }

      return await FlutterV2rayPlatform.instance
          .getAllServerDelay(configs: modifiedConfigs);
    } catch (e) {
      print('Error in getAllServerDelay: $e');
      throw ArgumentError('Error processing configurations: $e');
    }
  }

  /// Get ping times for multiple servers in parallel
  /// Returns a map of config string to ping time in milliseconds
  /// Returns -1 for failed pings
  Future<Map<String, int>> getAllServerPing({
    required List<String> configs,
    String url = 'http://cp.cloudflare.com',
  }) async {
    try {
      List<String> modifiedConfigs = [];

      for (String config in configs) {
        Map<String, dynamic> configMap = jsonDecode(config);

        // Simplify DNS configuration
        if (configMap.containsKey('dns')) {
          configMap['dns'] = {
            "servers": ["8.8.8.8", "8.8.4.4"],
            "queryStrategy": "UseIPv4"
          };
        }

        // Simplify routing configuration
        if (configMap.containsKey('routing')) {
          configMap['routing'] = {
            "domainStrategy": "AsIs",
            "rules": [
              {
                "type": "field",
                "outboundTag": configMap['remarks'] ?? "proxy",
                "port": "0-65535",
                "enabled": true
              }
            ]
          };
        }

        modifiedConfigs.add(jsonEncode(configMap));
      }

      return await FlutterV2rayPlatform.instance.getAllServerPing(
        configs: modifiedConfigs,
        url: url,
      );
    } catch (e) {
      print('Error in getAllServerPing: $e');
      throw ArgumentError('Error processing configurations: $e');
    }
  }

  /// Stop V2Ray service.
  Future<void> stopV2Ray() async {
    await FlutterV2rayPlatform.instance.stopV2Ray();
  }

  /// This method returns the real server delay of the configuration.
  Future<int> getServerDelay(
      {required String config,
      String url = 'https://google.com/generate_204'}) async {
    try {
      Map<String, dynamic> configMap = jsonDecode(config);

      // Simplify DNS configuration
      if (configMap.containsKey('dns')) {
        configMap['dns'] = {
          "servers": ["8.8.8.8", "8.8.4.4"],
          "queryStrategy": "UseIPv4"
        };
      }

      // Simplify routing configuration
      if (configMap.containsKey('routing')) {
        configMap['routing'] = {
          "domainStrategy": "AsIs",
          "rules": [
            {
              "type": "field",
              "outboundTag": configMap['remarks'] ?? "proxy",
              "port": "0-65535",
              "enabled": true
            }
          ]
        };
      }

      String modifiedConfig = jsonEncode(configMap);

      return await FlutterV2rayPlatform.instance
          .getServerDelay(config: modifiedConfig, url: url);
    } catch (e) {
      print('Error in getServerDelay: $e');
      throw ArgumentError('Error processing configuration: $e');
    }
  }

  /// This method returns the current connection state
  /// in the form of the String, which can be either
  ///  - ["CONNECTING"]
  ///  - ["CONNECTED"]
  ///  - ["DISCONNECTED"]
  ///  - ["ERROR"]
  Future<String> getV2rayStatus() async {
    return await FlutterV2rayPlatform.instance.getV2rayStatus();
  }

  /// This method returns the connected server delay.
  Future<int> getConnectedServerDelay(
      {String url = 'https://google.com/generate_204'}) async {
    return await FlutterV2rayPlatform.instance.getConnectedServerDelay(url);
  }

  // This method returns the V2Ray Core version.
  Future<String> getCoreVersion() async {
    return await FlutterV2rayPlatform.instance.getCoreVersion();
  }

  /// parse V2RayURL object from V2Ray share link
  ///
  /// like vmess://, vless://, trojan://, ss://, socks://
  static V2RayURL parseFromURL(String url) {
    switch (url.split("://")[0].toLowerCase()) {
      case 'vmess':
        return VmessURL(url: url);
      case 'vless':
        return VlessURL(url: url);
      case 'trojan':
        return TrojanURL(url: url);
      case 'ss':
        return ShadowSocksURL(url: url);
      case 'socks':
        return SocksURL(url: url);
      default:
        throw ArgumentError('url is invalid');
    }
  }
}
